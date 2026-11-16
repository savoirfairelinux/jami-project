package org.tucnet.core

import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class Mem : Persistence {
    val contacts = HashMap<String, ByteArray>()
    val sessions = HashMap<String, Pair<String, ByteArray>>()
    val packets = HashMap<String, ByteArray>()
    override fun saveContact(idHex: String, blob: ByteArray) { contacts[idHex] = blob }
    override fun loadContacts() = contacts.values.toList()
    override fun saveSession(sidHex: String, contactIdHex: String, blob: ByteArray) { sessions[sidHex] = contactIdHex to blob }
    override fun loadSessions() = sessions.values.toList()
    override fun putPacket(key: String, blob: ByteArray) { packets[key] = blob }
    override fun removePacket(key: String) { packets.remove(key) }
    override fun loadPackets() = packets.values.toList()
}

class Node(val name: String, val clock: () -> Long) : Listener {
    val id = Identity.create(name)
    val db = Mem()
    var engine = Engine(id, db, this, clock)
    val inbox = ArrayList<Pair<String, String>>()
    val delivered = HashSet<String>()
    val relayed = HashSet<String>()
    val wire = ArrayList<ByteArray>()
    override fun onText(contactIdHex: String, text: String, sentAt: Long, msgIdHex: String) { inbox += contactIdHex to text }
    override fun onDelivered(msgIdHex: String) { delivered += msgIdHex }
    override fun onRelayed(msgIdHex: String) { relayed += msgIdHex }
    fun restart() { engine = Engine(id, db, this, clock) }
}

fun connect(a: Node, b: Node) {
    val ab = object : Link { override val id = "to-${b.name}"; override fun send(frame: ByteArray) { a.wire += frame; b.engine.receive("to-${a.name}", frame) } }
    val ba = object : Link { override val id = "to-${a.name}"; override fun send(frame: ByteArray) { b.wire += frame; a.engine.receive("to-${b.name}", frame) } }
    a.engine.linkUp(ab); b.engine.linkUp(ba)
}

fun disconnect(a: Node, b: Node) { a.engine.linkDown("to-${b.name}"); b.engine.linkDown("to-${a.name}") }

class MeshTest {
    private var t = 1_800_000_000L
    private val clock = { t }

    @Test fun cardRoundTripAndTamper() {
        val id = Identity.create("Ana")
        val text = id.card.toText()
        assertEquals(id.card.idHex, Card.fromText(text)!!.idHex)
        val bad = id.card.encode().also { it[40] = (it[40] + 1).toByte() }
        assertNull(Card.decode(bad))
        assertNull(Card.fromText("hello"))
    }

    @Test fun ratchetBothDirectionsAndOutOfOrder() {
        val a = Identity.create("a"); val b = Identity.create("b")
        val sa = Session.initiator(a, b.card)
        val pre = sa.pre!!
        val sb = Session.responder(b, pre.copyOf(32), pre.copyOfRange(32, 64))
        assertContentEquals(sa.sid, sb.sid)
        val m1 = sa.encrypt("one".toByteArray()); val m2 = sa.encrypt("two".toByteArray()); val m3 = sa.encrypt("three".toByteArray())
        assertEquals("three", String(sb.decrypt(m3)))
        assertEquals("one", String(sb.decrypt(m1)))
        val r1 = sb.encrypt("reply".toByteArray())
        assertEquals("reply", String(sa.decrypt(r1)))
        val m4 = sa.encrypt("four".toByteArray())
        assertEquals("four", String(sb.decrypt(m4)))
        assertEquals("two", String(sb.decrypt(m2)))
        assertFailsWith<Exception> { sb.copy().decrypt(m2) }           // replay: key already used
        val restored = Session.decode(sb.encode())
        assertEquals("again", String(sa.decrypt(restored.encrypt("again".toByteArray()))))
        val tampered = sa.encrypt("x".toByteArray()).also { it[it.size - 1] = (it[it.size - 1] + 1).toByte() }
        assertFailsWith<Exception> { sb.copy().decrypt(tampered) }
    }

    @Test fun directChatWithOneScan() {
        val a = Node("Ana", clock); val b = Node("Ben", clock)
        val ben = a.engine.addContact(Card.fromText(b.id.card.toText())!!)!!
        connect(a, b)
        val id1 = a.engine.sendText(ben.idHex, "kumusta")!!
        val id2 = a.engine.sendText(ben.idHex, "nandito na ako")!!
        assertEquals(listOf("kumusta", "nandito na ako"), b.inbox.map { it.second })
        assertEquals(a.id.card.idHex, b.inbox[0].first)                 // Ben learned Ana from the first message
        assertTrue(a.delivered.containsAll(listOf(id1, id2)))
        val id3 = b.engine.sendText(a.id.card.idHex, "ayos")!!
        assertEquals("ayos", a.inbox.single().second)
        assertTrue(id3 in b.delivered)
        a.engine.sendText(ben.idHex, "sige")
        assertEquals(3, b.inbox.size)
    }

    @Test fun relayStoresAndDeliversLaterAndCannotRead() {
        val a = Node("Ana", clock); val b = Node("Ben", clock); val c = Node("Carlo", clock)
        val carlo = a.engine.addContact(c.id.card)!!
        connect(a, b)                                                   // Carlo is out of range
        val id = a.engine.sendText(carlo.idHex, "lihim na mensahe")!!
        assertTrue(id in a.relayed)
        assertTrue(b.inbox.isEmpty())
        assertEquals(1, b.engine.storedCount())
        assertFalse(a.wire.any { String(it, Charsets.ISO_8859_1).contains("lihim") })
        disconnect(a, b)
        t += 6 * 3600
        b.restart()                                                     // cache survives a restart
        connect(b, c)
        assertEquals("lihim na mensahe", c.inbox.single().second)
        assertFalse(id in a.delivered)
        assertNull(b.db.packets["${Packet.DATA}:$id"])                  // carrier dropped its copy on the receipt
        disconnect(b, c)
        connect(a, b)
        assertTrue(id in a.delivered)                                   // receipt travelled back through Ben
    }

    @Test fun multiHopChain() {
        val n = List(5) { Node("n$it", clock) }
        val last = n[0].engine.addContact(n[4].id.card)!!
        for (i in 0 until 4) connect(n[i], n[i + 1])
        val id = n[0].engine.sendText(last.idHex, "apat na hop")!!
        assertEquals("apat na hop", n[4].inbox.single().second)
        assertTrue(id in n[0].delivered)
        (1..3).forEach { assertTrue(n[it].inbox.isEmpty()) }
    }

    @Test fun expiresAfter24Hours() {
        val a = Node("Ana", clock); val b = Node("Ben", clock); val c = Node("Carlo", clock)
        val carlo = a.engine.addContact(c.id.card)!!
        connect(a, b)
        a.engine.sendText(carlo.idHex, "late")
        t += 25 * 3600
        connect(b, c)
        assertTrue(c.inbox.isEmpty())
        assertEquals(0, b.engine.storedCount())
    }

    @Test fun relayOffCarriesNothing() {
        val a = Node("Ana", clock); val b = Node("Ben", clock); val c = Node("Carlo", clock)
        b.engine.relayEnabled = false
        val carlo = a.engine.addContact(c.id.card)!!
        connect(a, b)
        a.engine.sendText(carlo.idHex, "x")
        assertEquals(0, b.engine.storedCount())
        assertNotNull(a.engine.contactForHint(Hint.of(c.id.dh.pub, Hint.day(t))))
    }

    @Test fun packetCodec() {
        val p = Packet(Packet.DATA, 7, Crypto.random(16), Crypto.random(8), 1_900_000_000L, Crypto.random(300))
        val q = Packet.decode(p.encode())!!
        assertEquals(p.key, q.key); assertEquals(p.expires, q.expires); assertContentEquals(p.payload, q.payload)
        assertNull(Packet.decode(p.encode().copyOf(20)))
    }
}

package org.tucnet.core

/** One mesh packet. Relays read only this header; [payload] is ciphertext (DATA) or an ack secret (ACK). */
class Packet(val type: Int, var ttl: Int, val msgId: ByteArray, val hint: ByteArray, val expires: Long, val payload: ByteArray) {
    val idHex get() = msgId.hex()
    val key get() = "$type:$idHex"

    fun encode(): ByteArray = Wr().u8(VERSION).u8(type).u8(ttl).u8(0).raw(msgId).raw(hint)
        .i32(expires.toInt()).u16(payload.size).raw(payload).done()

    companion object {
        const val VERSION = 1
        const val DATA = 1
        const val ACK = 2
        const val MAX_PAYLOAD = 60_000

        fun decode(b: ByteArray): Packet? = runCatching {
            val r = Rd(b)
            require(r.u8() == VERSION)
            val type = r.u8(); val ttl = r.u8(); r.u8()
            val p = Packet(type, ttl, r.raw(16), r.raw(8), r.i32().toLong() and 0xFFFFFFFFL, r.raw(r.u16()))
            require(type == DATA || type == ACK)
            p
        }.getOrNull()
    }
}

class Contact(val card: Card, var name: String, var sendSid: ByteArray?) {
    val idHex get() = card.idHex
    fun encode(): ByteArray = Wr().bytes(card.encode()).bytes(name.toByteArray()).bytes(sendSid).done()

    companion object {
        fun decode(b: ByteArray): Contact {
            val r = Rd(b)
            return Contact(Card.decode(r.bytes()!!)!!, String(r.bytes()!!), r.bytes())
        }
    }
}

/** A live connection to one neighbouring device, over any radio. */
interface Link {
    val id: String
    fun send(frame: ByteArray)
}

interface Persistence {
    fun saveContact(idHex: String, blob: ByteArray)
    fun loadContacts(): List<ByteArray>
    fun saveSession(sidHex: String, contactIdHex: String, blob: ByteArray)
    fun loadSessions(): List<Pair<String, ByteArray>>
    fun putPacket(key: String, blob: ByteArray)
    fun removePacket(key: String)
    fun loadPackets(): List<ByteArray>
}

interface Listener {
    fun onContact(contact: Contact) {}
    fun onText(contactIdHex: String, text: String, sentAt: Long, msgIdHex: String) {}
    /** One of our own messages was handed to at least one other device. */
    fun onRelayed(msgIdHex: String) {}
    /** The recipient confirmed one of our messages. */
    fun onDelivered(msgIdHex: String) {}
}

/**
 * Mesh core: end-to-end sessions, flooding router with hop limit and duplicate suppression,
 * and the 24-hour store-and-forward cache. Radio-independent; all methods are thread-safe.
 */
class Engine(
    val me: Identity,
    private val db: Persistence,
    private val listener: Listener,
    private val now: () -> Long = { System.currentTimeMillis() / 1000 },
) {
    @Volatile var relayEnabled = true

    private val contacts = LinkedHashMap<String, Contact>()
    private val sessions = HashMap<String, Session>()
    private val sessionOwner = HashMap<String, String>()
    private val store = LinkedHashMap<String, Packet>()
    private val seen = LinkedHashSet<String>()
    private val links = LinkedHashMap<String, Link>()
    private val sentOn = HashMap<String, MutableSet<String>>()

    init {
        db.loadContacts().forEach { runCatching { Contact.decode(it) }.getOrNull()?.let { c -> contacts[c.idHex] = c } }
        db.loadSessions().forEach { (owner, blob) ->
            runCatching { Session.decode(blob) }.getOrNull()?.let { s -> sessions[s.sid.hex()] = s; sessionOwner[s.sid.hex()] = owner }
        }
        db.loadPackets().forEach { Packet.decode(it)?.let { p -> store[p.key] = p; seen.add(p.key) } }
    }

    @Synchronized fun contacts(): List<Contact> = contacts.values.toList()
    @Synchronized fun storedCount(): Int = store.size
    @Synchronized fun linkCount(): Int = links.size
    fun myHint(): ByteArray = Hint.of(me.dh.pub, Hint.day(now()))

    /** Which known contact, if any, is advertising this hint right now. */
    @Synchronized fun contactForHint(hint: ByteArray): Contact? {
        val d = Hint.day(now())
        return contacts.values.firstOrNull { c -> (-1L..1L).any { Hint.of(c.card.dhPub, d + it).contentEquals(hint) } }
    }

    @Synchronized fun addContact(card: Card): Contact? {
        if (!card.valid() || card.idHex == me.card.idHex) return null
        contacts[card.idHex]?.let { return it }
        return Contact(card, card.name.ifBlank { "Peer " + card.idHex.take(4) }, null).also { save(it); listener.onContact(it) }
    }

    @Synchronized fun rename(contactIdHex: String, name: String) {
        contacts[contactIdHex]?.let { it.name = name; save(it) }
    }

    /** Encrypts and queues a text. Returns the message id, or null if the contact is unknown. */
    @Synchronized fun sendText(contactIdHex: String, text: String): String? {
        val c = contacts[contactIdHex] ?: return null
        val s = c.sendSid?.let { sessions[it.hex()] } ?: Session.initiator(me, c.card).also {
            sessions[it.sid.hex()] = it; sessionOwner[it.sid.hex()] = c.idHex; c.sendSid = it.sid; save(c)
        }
        val ackSecret = Crypto.random(16)
        val msgId = Crypto.sha256(ackSecret).copyOf(16)
        val pre = s.pre
        val plain = Wr().bytes(if (pre != null) me.card.encode() else null).u8(KIND_TEXT).i64(now()).raw(ackSecret)
            .raw(text.toByteArray()).done()
        val env = Wr().u8(if (pre != null) 1 else 2).raw(s.sid)
        if (pre != null) env.raw(pre)
        val payload = env.raw(s.encrypt(plain)).done()
        require(payload.size <= Packet.MAX_PAYLOAD) { "message too long" }
        db.saveSession(s.sid.hex(), c.idHex, s.encode())
        val p = Packet(Packet.DATA, TTL, msgId, Hint.of(c.card.dhPub, Hint.day(now())), now() + LIFETIME, payload)
        seen.add(p.key)
        keep(p)
        forward(p, null)
        return p.idHex
    }

    @Synchronized fun linkUp(link: Link) {
        links[link.id] = link
        sentOn[link.id] = HashSet()
        purgeExpired()
        store.values.toList().forEach { sendOn(link, it) }
    }

    @Synchronized fun linkDown(linkId: String) {
        links.remove(linkId); sentOn.remove(linkId)
    }

    @Synchronized fun receive(linkId: String, frame: ByteArray) {
        val p = Packet.decode(frame) ?: return
        val t = now()
        if (p.expires <= t || p.expires > t + LIFETIME + 600) return
        sentOn[linkId]?.add(p.key)
        if (!remember(p.key)) return
        when (p.type) {
            Packet.ACK -> {
                if (p.payload.size != 16 || !Crypto.sha256(p.payload).copyOf(16).contentEquals(p.msgId)) return
                val dataKey = "${Packet.DATA}:${p.idHex}"
                if (store.remove(dataKey) != null) db.removePacket(dataKey)
                listener.onDelivered(p.idHex)
                relay(p, linkId)
            }
            Packet.DATA -> {
                store["${Packet.ACK}:${p.idHex}"]?.let { ack -> links[linkId]?.let { l -> sendOn(l, ack) }; return }
                if (isMine(p.hint) && deliver(p)) return
                relay(p, linkId)
            }
        }
    }

    private fun relay(p: Packet, from: String) {
        if (!relayEnabled || p.ttl <= 0) return
        p.ttl -= 1
        keep(p)
        forward(p, from)
    }

    private fun isMine(hint: ByteArray): Boolean {
        val d = Hint.day(now())
        return (-1L..1L).any { Hint.of(me.dh.pub, d + it).contentEquals(hint) }
    }

    /** Tries to decrypt a packet addressed to us. Returns false if it was not for us after all. */
    private fun deliver(p: Packet): Boolean = runCatching {
        val r = Rd(p.payload)
        val type = r.u8()
        val sidHex = r.raw(8).hex()
        val pre = if (type == 1) r.raw(64) else null
        val body = r.rest()
        var session = sessions[sidHex]?.copy()
        val known = session != null
        if (session == null) {
            pre ?: return false
            session = Session.responder(me, pre.copyOf(32), pre.copyOfRange(32, 64))
            if (session.sid.hex() != sidHex) return false
        }
        val plain = Rd(session.decrypt(body))
        val cardBytes = plain.bytes()
        val owner = if (known) sessionOwner[sidHex]!! else {
            val card = Card.decode(cardBytes ?: return false) ?: return false
            if (!card.dhPub.contentEquals(pre!!.copyOf(32)) || card.idHex == me.card.idHex) return false
            val c = contacts[card.idHex] ?: Contact(card, card.name.ifBlank { "Peer " + card.idHex.take(4) }, null)
                .also { contacts[it.idHex] = it; listener.onContact(it) }
            c.sendSid = session.sid
            save(c)
            c.idHex
        }
        session.pre = null
        sessions[sidHex] = session
        sessionOwner[sidHex] = owner
        db.saveSession(sidHex, owner, session.encode())

        val kind = plain.u8(); val sentAt = plain.i64(); val ackSecret = plain.raw(16)
        if (kind == KIND_TEXT) listener.onText(owner, String(plain.rest()), sentAt, p.idHex)
        if (Crypto.sha256(ackSecret).copyOf(16).contentEquals(p.msgId)) {
            val ack = Packet(Packet.ACK, TTL, p.msgId, ByteArray(8), now() + LIFETIME, ackSecret)
            seen.add(ack.key)
            keep(ack)
            forward(ack, null)
        }
        true
    }.getOrDefault(false)

    private fun save(c: Contact) { contacts[c.idHex] = c; db.saveContact(c.idHex, c.encode()) }

    private fun remember(key: String): Boolean {
        if (!seen.add(key)) return false
        if (seen.size > MAX_SEEN) seen.remove(seen.first())
        return true
    }

    private fun keep(p: Packet) {
        store[p.key] = p
        db.putPacket(p.key, p.encode())
        while (store.size > MAX_STORED) store.keys.first().let { store.remove(it); db.removePacket(it) }
    }

    private fun purgeExpired() {
        val t = now()
        store.values.filter { it.expires <= t }.forEach { store.remove(it.key); db.removePacket(it.key) }
    }

    private fun forward(p: Packet, except: String?) = links.values.filter { it.id != except }.forEach { sendOn(it, p) }

    private fun sendOn(link: Link, p: Packet) {
        if (p.expires <= now() || sentOn[link.id]?.add(p.key) != true) return
        link.send(p.encode())
        if (p.type == Packet.DATA) listener.onRelayed(p.idHex)
    }

    companion object {
        const val TTL = 7
        const val LIFETIME = 24 * 3600L
        private const val MAX_STORED = 2000
        private const val MAX_SEEN = 20_000
        private const val KIND_TEXT = 1
    }
}

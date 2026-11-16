package org.tucnet.core

/**
 * Double Ratchet session (Signal specification), AES-256-GCM as the AEAD.
 * Every message gets its own key; a DH ratchet step happens whenever the conversation changes direction.
 */
class Session private constructor(
    private var rk: ByteArray,
    private var dhs: KeyPair,
    private var dhr: ByteArray?,
    private var cks: ByteArray?,
    private var ckr: ByteArray?,
    private var ns: Int,
    private var nr: Int,
    private var pn: Int,
    private val ad: ByteArray,
    val sid: ByteArray,
    /** X3DH header (our identity DH key + ephemeral key) sent until the peer's first reply arrives. */
    var pre: ByteArray?,
    private val skipped: LinkedHashMap<String, ByteArray>,
) {
    fun encrypt(plain: ByteArray): ByteArray {
        val (ck, mk) = kdfCk(cks ?: error("session cannot send yet"))
        cks = ck
        val header = Wr().raw(dhs.pub).i32(pn).i32(ns).done()
        ns++
        return header + aead(mk, true, plain, ad + header)
    }

    /** Throws on any failure. Callers must decrypt on a [copy] and keep it only on success. */
    fun decrypt(msg: ByteArray): ByteArray {
        val r = Rd(msg)
        val dh = r.raw(32); val hpn = r.i32(); val n = r.i32()
        val header = msg.copyOf(HEADER)
        val body = r.rest()
        skipped.remove(dh.hex() + ":" + n)?.let { return aead(it, false, body, ad + header) }
        if (dhr == null || !dh.contentEquals(dhr)) {
            skip(hpn)
            pn = ns; ns = 0; nr = 0; dhr = dh
            kdfRk(rk, Crypto.dh(dhs.priv, dh)).let { rk = it.first; ckr = it.second }
            dhs = Crypto.dhKeyPair()
            kdfRk(rk, Crypto.dh(dhs.priv, dh)).let { rk = it.first; cks = it.second }
        }
        skip(n)
        val (ck, mk) = kdfCk(ckr!!)
        ckr = ck; nr++
        return aead(mk, false, body, ad + header)
    }

    private fun skip(until: Int) {
        val chain = ckr ?: return
        require(until - nr <= MAX_SKIP) { "too many skipped messages" }
        var ck = chain
        while (nr < until) {
            val (next, mk) = kdfCk(ck)
            ck = next
            skipped[dhr!!.hex() + ":" + nr] = mk
            nr++
        }
        ckr = ck
        while (skipped.size > MAX_SKIP) skipped.remove(skipped.keys.first())
    }

    fun encode(): ByteArray {
        val w = Wr().raw(rk).raw(dhs.priv).raw(dhs.pub).bytes(dhr).bytes(cks).bytes(ckr)
            .i32(ns).i32(nr).i32(pn).bytes(ad).raw(sid).bytes(pre).u16(skipped.size)
        skipped.forEach { (k, v) -> w.bytes(k.toByteArray()).raw(v) }
        return w.done()
    }

    fun copy() = decode(encode())

    companion object {
        private const val HEADER = 40
        private const val MAX_SKIP = 1000
        private val ZERO = ByteArray(32)

        private fun kdfRk(rk: ByteArray, dhOut: ByteArray): Pair<ByteArray, ByteArray> =
            Crypto.hkdf(dhOut, rk, "TN-ratchet", 64).let { it.copyOf(32) to it.copyOfRange(32, 64) }

        private fun kdfCk(ck: ByteArray) = Crypto.hmac(ck, byteArrayOf(2)) to Crypto.hmac(ck, byteArrayOf(1))

        private fun aead(mk: ByteArray, seal: Boolean, data: ByteArray, aad: ByteArray): ByteArray {
            val okm = Crypto.hkdf(mk, ZERO, "TN-msg", 44)
            val key = okm.copyOf(32); val nonce = okm.copyOfRange(32, 44)
            return if (seal) Crypto.seal(key, nonce, data, aad) else Crypto.open(key, nonce, data, aad)
        }

        fun sidOf(sk: ByteArray) = Crypto.hkdf(sk, ZERO, "TN-sid", 8)

        /** X3DH shared secret from the three DH outputs (no one-time prekey). */
        fun x3dh(dh1: ByteArray, dh2: ByteArray, dh3: ByteArray) =
            Crypto.hkdf(ByteArray(32) { 0xFF.toByte() } + dh1 + dh2 + dh3, ZERO, "TN-X3DH", 32)

        fun initiator(me: Identity, peer: Card): Session {
            val ek = Crypto.dhKeyPair()
            val sk = x3dh(Crypto.dh(me.dh.priv, peer.spkPub), Crypto.dh(ek.priv, peer.dhPub), Crypto.dh(ek.priv, peer.spkPub))
            val dhs = Crypto.dhKeyPair()
            val (rk, cks) = kdfRk(sk, Crypto.dh(dhs.priv, peer.spkPub))
            return Session(rk, dhs, peer.spkPub, cks, null, 0, 0, 0, me.dh.pub + peer.dhPub, sidOf(sk), me.dh.pub + ek.pub, LinkedHashMap())
        }

        fun responder(me: Identity, peerDhPub: ByteArray, peerEk: ByteArray): Session {
            val sk = x3dh(Crypto.dh(me.spk.priv, peerDhPub), Crypto.dh(me.dh.priv, peerEk), Crypto.dh(me.spk.priv, peerEk))
            return Session(sk, me.spk, null, null, null, 0, 0, 0, peerDhPub + me.dh.pub, sidOf(sk), null, LinkedHashMap())
        }

        fun decode(b: ByteArray): Session {
            val r = Rd(b)
            val s = Session(r.raw(32), KeyPair(r.raw(32), r.raw(32)), r.bytes(), r.bytes(), r.bytes(),
                r.i32(), r.i32(), r.i32(), r.bytes()!!, r.raw(8), r.bytes(), LinkedHashMap())
            repeat(r.u16()) { s.skipped[String(r.bytes()!!)] = r.raw(32) }
            return s
        }
    }
}

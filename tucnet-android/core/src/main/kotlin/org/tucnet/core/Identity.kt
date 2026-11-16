package org.tucnet.core

import java.util.Base64

/**
 * Public contact card: what a QR code carries. The signature binds the DH identity key and the
 * signed prekey to the Ed25519 identity key. The display name is not signed and may change.
 */
class Card(val sigPub: ByteArray, val dhPub: ByteArray, val spkPub: ByteArray, val spkSig: ByteArray, val name: String) {
    val id: ByteArray by lazy { Crypto.sha256(sigPub, dhPub).copyOf(16) }
    val idHex: String get() = id.hex()

    fun valid() = sigPub.size == 32 && dhPub.size == 32 && spkPub.size == 32 &&
        Crypto.verify(sigPub, signedPart(dhPub, spkPub), spkSig)

    fun encode(): ByteArray = Wr().raw(sigPub).raw(dhPub).raw(spkPub).raw(spkSig).bytes(name.toByteArray()).done()
    fun toText(): String = PREFIX + Base64.getUrlEncoder().withoutPadding().encodeToString(encode())

    companion object {
        const val PREFIX = "tucnet1:"
        internal fun signedPart(dhPub: ByteArray, spkPub: ByteArray) = "TN1".toByteArray() + dhPub + spkPub

        fun decode(b: ByteArray): Card? = runCatching {
            val r = Rd(b)
            Card(r.raw(32), r.raw(32), r.raw(32), r.raw(64), String(r.bytes()!!).take(40))
        }.getOrNull()?.takeIf { it.valid() }

        fun fromText(s: String): Card? = runCatching {
            val t = s.trim()
            require(t.startsWith(PREFIX))
            decode(Base64.getUrlDecoder().decode(t.removePrefix(PREFIX)))
        }.getOrNull()
    }
}

/** This device's private identity. Generated locally; never leaves the device. */
class Identity(val sign: KeyPair, val dh: KeyPair, val spk: KeyPair, val spkSig: ByteArray, var name: String) {
    val card get() = Card(sign.pub, dh.pub, spk.pub, spkSig, name)

    fun encode(): ByteArray = Wr().raw(sign.priv).raw(sign.pub).raw(dh.priv).raw(dh.pub)
        .raw(spk.priv).raw(spk.pub).raw(spkSig).bytes(name.toByteArray()).done()

    companion object {
        fun create(name: String): Identity {
            val sign = Crypto.signKeyPair()
            val dh = Crypto.dhKeyPair()
            val spk = Crypto.dhKeyPair()
            return Identity(sign, dh, spk, Crypto.sign(sign.priv, Card.signedPart(dh.pub, spk.pub)), name)
        }

        fun decode(b: ByteArray): Identity {
            val r = Rd(b)
            return Identity(KeyPair(r.raw(32), r.raw(32)), KeyPair(r.raw(32), r.raw(32)),
                KeyPair(r.raw(32), r.raw(32)), r.raw(64), String(r.bytes()!!))
        }
    }
}

/** Rotating 8-byte address a relay can match without learning who it belongs to. */
object Hint {
    fun of(dhPub: ByteArray, day: Long): ByteArray =
        Crypto.hmac(dhPub, "TN-hint".toByteArray(), Wr().i64(day).done()).copyOf(8)

    fun day(nowSec: Long) = nowSec / 86400
}

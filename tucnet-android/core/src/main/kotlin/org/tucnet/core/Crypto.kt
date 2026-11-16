package org.tucnet.core

import org.bouncycastle.crypto.digests.SHA256Digest
import org.bouncycastle.crypto.generators.HKDFBytesGenerator
import org.bouncycastle.crypto.params.HKDFParameters
import org.bouncycastle.math.ec.rfc7748.X25519
import org.bouncycastle.math.ec.rfc8032.Ed25519
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.Mac
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

class KeyPair(val priv: ByteArray, val pub: ByteArray)

fun ByteArray.hex(): String = joinToString("") { "%02x".format(it) }
fun String.unhex(): ByteArray = ByteArray(length / 2) { substring(it * 2, it * 2 + 2).toInt(16).toByte() }

object Crypto {
    private val rng = SecureRandom()

    fun random(n: Int) = ByteArray(n).also { rng.nextBytes(it) }

    fun sha256(vararg parts: ByteArray): ByteArray =
        MessageDigest.getInstance("SHA-256").apply { parts.forEach { update(it) } }.digest()

    fun hmac(key: ByteArray, vararg parts: ByteArray): ByteArray =
        Mac.getInstance("HmacSHA256").apply { init(SecretKeySpec(key, "HmacSHA256")); parts.forEach { update(it) } }.doFinal()

    fun hkdf(ikm: ByteArray, salt: ByteArray, info: String, len: Int): ByteArray {
        val g = HKDFBytesGenerator(SHA256Digest())
        g.init(HKDFParameters(ikm, salt, info.toByteArray()))
        return ByteArray(len).also { g.generateBytes(it, 0, len) }
    }

    fun dhKeyPair(): KeyPair {
        val priv = ByteArray(32)
        X25519.generatePrivateKey(rng, priv)
        val pub = ByteArray(32)
        X25519.generatePublicKey(priv, 0, pub, 0)
        return KeyPair(priv, pub)
    }

    fun dh(priv: ByteArray, pub: ByteArray): ByteArray {
        val out = ByteArray(32)
        require(pub.size == 32 && X25519.calculateAgreement(priv, 0, pub, 0, out, 0)) { "bad public key" }
        return out
    }

    fun signKeyPair(): KeyPair {
        val priv = ByteArray(32)
        Ed25519.generatePrivateKey(rng, priv)
        val pub = ByteArray(32)
        Ed25519.generatePublicKey(priv, 0, pub, 0)
        return KeyPair(priv, pub)
    }

    fun sign(priv: ByteArray, msg: ByteArray): ByteArray =
        ByteArray(64).also { Ed25519.sign(priv, 0, msg, 0, msg.size, it, 0) }

    fun verify(pub: ByteArray, msg: ByteArray, sig: ByteArray): Boolean =
        pub.size == 32 && sig.size == 64 && Ed25519.verify(sig, 0, pub, 0, msg, 0, msg.size)

    /** AES-256-GCM. [key] must be used for one message only; the nonce is derived alongside it. */
    fun seal(key: ByteArray, nonce: ByteArray, plain: ByteArray, aad: ByteArray): ByteArray = gcm(Cipher.ENCRYPT_MODE, key, nonce, plain, aad)
    fun open(key: ByteArray, nonce: ByteArray, sealed: ByteArray, aad: ByteArray): ByteArray = gcm(Cipher.DECRYPT_MODE, key, nonce, sealed, aad)

    private fun gcm(mode: Int, key: ByteArray, nonce: ByteArray, data: ByteArray, aad: ByteArray): ByteArray =
        Cipher.getInstance("AES/GCM/NoPadding").run {
            init(mode, SecretKeySpec(key, "AES"), GCMParameterSpec(128, nonce))
            updateAAD(aad)
            doFinal(data)
        }
}

/** Minimal length-prefixed binary writer/reader used for persistence and wire formats. */
class Wr {
    private val o = ByteArrayOutputStream()
    fun raw(b: ByteArray) = apply { o.write(b) }
    fun u8(v: Int) = apply { o.write(v) }
    fun u16(v: Int) = apply { o.write(v shr 8); o.write(v) }
    fun i32(v: Int) = apply { o.write(ByteBuffer.allocate(4).putInt(v).array()) }
    fun i64(v: Long) = apply { o.write(ByteBuffer.allocate(8).putLong(v).array()) }
    fun bytes(b: ByteArray?) = apply { if (b == null) u16(0xFFFF) else { u16(b.size); o.write(b) } }
    fun done(): ByteArray = o.toByteArray()
}

class Rd(private val b: ByteArray, private var p: Int = 0) {
    val left get() = b.size - p
    fun raw(n: Int): ByteArray { require(n in 0..left) { "truncated" }; return b.copyOfRange(p, p + n).also { p += n } }
    fun u8() = raw(1)[0].toInt() and 0xFF
    fun u16() = (u8() shl 8) or u8()
    fun i32() = ByteBuffer.wrap(raw(4)).int
    fun i64() = ByteBuffer.wrap(raw(8)).long
    fun bytes(): ByteArray? { val n = u16(); return if (n == 0xFFFF) null else raw(n) }
    fun rest() = raw(left)
}

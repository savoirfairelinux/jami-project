package org.tucnet.app

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import org.tucnet.core.Persistence
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

data class MsgUi(val id: String, val contact: String, val me: Boolean, val text: String, val ts: Long, val status: Int)

/** Wraps the identity blob with an AES key that never leaves the Android Keystore. */
private object KeyVault {
    private const val ALIAS = "tucnet-identity"

    private fun key(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256).build())
            generateKey()
        }
    }

    fun wrap(plain: ByteArray): ByteArray = Cipher.getInstance("AES/GCM/NoPadding").run {
        init(Cipher.ENCRYPT_MODE, key())
        iv + doFinal(plain)
    }

    fun unwrap(blob: ByteArray): ByteArray = Cipher.getInstance("AES/GCM/NoPadding").run {
        init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, blob, 0, 12))
        doFinal(blob, 12, blob.size - 12)
    }
}

class Db(ctx: Context) : SQLiteOpenHelper(ctx, "tucnet.db", null, 1), Persistence {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE kv(k TEXT PRIMARY KEY, v BLOB)")
        db.execSQL("CREATE TABLE contacts(id TEXT PRIMARY KEY, blob BLOB)")
        db.execSQL("CREATE TABLE sessions(sid TEXT PRIMARY KEY, owner TEXT, blob BLOB)")
        db.execSQL("CREATE TABLE packets(k TEXT PRIMARY KEY, blob BLOB)")
        db.execSQL("CREATE TABLE messages(id TEXT, contact TEXT, me INTEGER, body TEXT, ts INTEGER, status INTEGER, PRIMARY KEY(id, me))")
    }

    override fun onUpgrade(db: SQLiteDatabase, old: Int, new: Int) {}

    private fun put(table: String, vararg kv: Pair<String, Any>) {
        val v = ContentValues()
        kv.forEach { (k, x) ->
            when (x) {
                is String -> v.put(k, x); is ByteArray -> v.put(k, x); is Int -> v.put(k, x); is Long -> v.put(k, x)
            }
        }
        writableDatabase.insertWithOnConflict(table, null, v, SQLiteDatabase.CONFLICT_REPLACE)
    }

    private fun blobs(sql: String): List<ByteArray> = readableDatabase.rawQuery(sql, null).use { c ->
        ArrayList<ByteArray>().apply { while (c.moveToNext()) add(c.getBlob(0)) }
    }

    fun identity(): ByteArray? = blobs("SELECT v FROM kv WHERE k='identity'").firstOrNull()?.let { KeyVault.unwrap(it) }
    fun saveIdentity(plain: ByteArray) = put("kv", "k" to "identity", "v" to KeyVault.wrap(plain))
    fun flag(name: String, default: Boolean) = blobs("SELECT v FROM kv WHERE k='$name'").firstOrNull()?.let { it[0].toInt() == 1 } ?: default
    fun setFlag(name: String, on: Boolean) = put("kv", "k" to name, "v" to byteArrayOf(if (on) 1 else 0))

    override fun saveContact(idHex: String, blob: ByteArray) = put("contacts", "id" to idHex, "blob" to blob)
    override fun loadContacts() = blobs("SELECT blob FROM contacts")
    override fun saveSession(sidHex: String, contactIdHex: String, blob: ByteArray) =
        put("sessions", "sid" to sidHex, "owner" to contactIdHex, "blob" to blob)

    override fun loadSessions(): List<Pair<String, ByteArray>> =
        readableDatabase.rawQuery("SELECT owner, blob FROM sessions", null).use { c ->
            ArrayList<Pair<String, ByteArray>>().apply { while (c.moveToNext()) add(c.getString(0) to c.getBlob(1)) }
        }

    override fun putPacket(key: String, blob: ByteArray) = put("packets", "k" to key, "blob" to blob)
    override fun removePacket(key: String) { writableDatabase.delete("packets", "k=?", arrayOf(key)) }
    override fun loadPackets() = blobs("SELECT blob FROM packets")

    /** Returns false if this message was already stored. */
    fun addMessage(m: MsgUi): Boolean {
        val v = ContentValues().apply {
            put("id", m.id); put("contact", m.contact); put("me", if (m.me) 1 else 0)
            put("body", m.text); put("ts", m.ts); put("status", m.status)
        }
        return writableDatabase.insertWithOnConflict("messages", null, v, SQLiteDatabase.CONFLICT_IGNORE) != -1L
    }

    fun setStatus(id: String, status: Int) =
        writableDatabase.execSQL("UPDATE messages SET status=? WHERE id=? AND me=1 AND status<?", arrayOf<Any>(status, id, status))

    fun messages(): List<MsgUi> = readableDatabase.rawQuery("SELECT id, contact, me, body, ts, status FROM messages ORDER BY ts, rowid", null).use { c ->
        ArrayList<MsgUi>().apply {
            while (c.moveToNext()) add(MsgUi(c.getString(0), c.getString(1), c.getInt(2) == 1, c.getString(3), c.getLong(4), c.getInt(5)))
        }
    }
}

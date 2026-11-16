package org.tucnet.app

import android.Manifest
import android.app.Application
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import org.tucnet.core.Card
import org.tucnet.core.Contact
import org.tucnet.core.Engine
import org.tucnet.core.Identity
import org.tucnet.core.Link
import org.tucnet.core.Listener
import org.tucnet.core.hex

class TucnetApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Mesh.init(this)
    }
}

data class ContactUi(val id: String, val name: String)
data class Near(val hint: String, val rssi: Int, val seenAt: Long, val contactId: String?)

/** App-wide state: owns the engine and the radio, and mirrors what the UI shows. Mutated on the main thread only. */
object Mesh : Listener, BleBearer.Callbacks {
    private lateinit var app: Context
    private lateinit var db: Db
    private val main = Handler(Looper.getMainLooper())
    private var bearer: BleBearer? = null
    var engine: Engine? = null
        private set

    val contacts = mutableStateListOf<ContactUi>()
    val messages = mutableStateListOf<MsgUi>()
    val near = mutableStateMapOf<String, Near>()
    var ready by mutableStateOf(false)
    var radio by mutableStateOf("Off")
    var links by mutableIntStateOf(0)
    var carried by mutableIntStateOf(0)
    var relay by mutableStateOf(true)
    var openChat: String? = null

    val myCard: Card? get() = engine?.me?.card

    fun init(ctx: Context) {
        app = ctx.applicationContext
        db = Db(app)
        runCatching { db.identity() }.getOrNull()?.let { boot(Identity.decode(it)) }
        main.postDelayed(object : Runnable {
            override fun run() { tick(); main.postDelayed(this, 5000) }
        }, 5000)
    }

    fun createIdentity(name: String) {
        val id = Identity.create(name.trim().take(40))
        db.saveIdentity(id.encode())
        boot(id)
    }

    private fun boot(id: Identity) {
        relay = db.flag("relay", true)
        engine = Engine(id, db, this).also { it.relayEnabled = relay }
        refreshContacts()
        messages.clear(); messages.addAll(db.messages())
        ready = true
        tick()
    }

    fun changeRelay(on: Boolean) { relay = on; db.setFlag("relay", on); engine?.relayEnabled = on }

    private fun refreshContacts() {
        contacts.clear()
        engine?.contacts()?.forEach { contacts.add(ContactUi(it.idHex, it.name)) }
    }

    /** Returns null on success or a reason the code was rejected. */
    fun addContact(text: String): String? {
        val card = Card.fromText(text) ?: return "That is not a valid Tucnet code."
        if (card.idHex == myCard?.idHex) return "That is your own code."
        engine?.addContact(card) ?: return "Could not add this contact."
        refreshContacts()
        return null
    }

    fun send(contactId: String, text: String) {
        val id = runCatching { engine?.sendText(contactId, text) }.getOrNull() ?: return
        val m = MsgUi(id, contactId, true, text, System.currentTimeMillis() / 1000, 0)
        db.addMessage(m)
        messages.add(m)
    }

    private fun setStatus(id: String, status: Int) {
        val i = messages.indexOfFirst { it.id == id && it.me }
        if (i < 0 || messages[i].status >= status) return
        db.setStatus(id, status)
        messages[i] = messages[i].copy(status = status)
    }

    private fun tick() {
        links = engine?.linkCount() ?: 0
        carried = engine?.storedCount() ?: 0
        val cutoff = System.currentTimeMillis() - 30_000
        near.values.filter { it.seenAt < cutoff }.forEach { near.remove(it.hint) }
    }

    // ---- radio

    fun hasPermissions(ctx: Context) = permissions().all { ContextCompat.checkSelfPermission(ctx, it) == PackageManager.PERMISSION_GRANTED }

    fun permissions(): Array<String> = when {
        Build.VERSION.SDK_INT >= 33 -> arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_ADVERTISE,
            Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.POST_NOTIFICATIONS)
        Build.VERSION.SDK_INT >= 31 -> arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_ADVERTISE,
            Manifest.permission.BLUETOOTH_CONNECT)
        else -> arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
    }

    private fun radioPermissions(ctx: Context) = permissions().filter { it != Manifest.permission.POST_NOTIFICATIONS }
        .all { ContextCompat.checkSelfPermission(ctx, it) == PackageManager.PERMISSION_GRANTED }

    fun startService(ctx: Context) {
        if (!ready || !radioPermissions(ctx)) return
        runCatching { ContextCompat.startForegroundService(ctx, Intent(ctx, MeshService::class.java)) }
    }

    fun startRadio() {
        if (engine == null) return
        if (bearer == null) bearer = BleBearer(app, this)
        bearer?.start()
    }

    fun stopRadio() { bearer?.stop() }

    override fun hint(): ByteArray = engine!!.myHint()
    override fun onUp(link: Link) { engine?.linkUp(link); main.post { tick() } }
    override fun onDown(linkId: String) { engine?.linkDown(linkId); main.post { tick() } }
    override fun onFrame(linkId: String, frame: ByteArray) { engine?.receive(linkId, frame) }
    override fun onState(state: String) { main.post { radio = state; if (state == "Off") near.clear() } }
    override fun onSeen(hint: ByteArray, rssi: Int) {
        val contact = engine?.contactForHint(hint)?.idHex
        val h = hint.hex()
        main.post { near[h] = Near(h, rssi, System.currentTimeMillis(), contact) }
    }

    // ---- engine events (may arrive on Bluetooth threads)

    override fun onContact(contact: Contact) { main.post { refreshContacts() } }
    override fun onRelayed(msgIdHex: String) { main.post { setStatus(msgIdHex, 1); tick() } }
    override fun onDelivered(msgIdHex: String) { main.post { setStatus(msgIdHex, 2); tick() } }
    override fun onText(contactIdHex: String, text: String, sentAt: Long, msgIdHex: String) {
        main.post {
            val m = MsgUi(msgIdHex, contactIdHex, false, text, System.currentTimeMillis() / 1000, 2)
            if (!db.addMessage(m)) return@post
            messages.add(m)
            if (openChat != contactIdHex) notifyMessage(contactIdHex, text)
        }
    }

    private fun notifyMessage(contactId: String, text: String) {
        val nm = app.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel("messages", "Messages", NotificationManager.IMPORTANCE_HIGH))
        val open = PendingIntent.getActivity(app, 0, Intent(app, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val name = contacts.firstOrNull { it.id == contactId }?.name ?: "New message"
        val n = Notification.Builder(app, "messages").setSmallIcon(R.drawable.ic_stat).setContentTitle(name)
            .setContentText(text).setAutoCancel(true).setContentIntent(open).build()
        runCatching { nm.notify(contactId.hashCode(), n) }
    }
}

/** Keeps the process and the Bluetooth mesh alive while the app is in the background. */
class MeshService : Service() {
    private val bluetoothState = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, -1)) {
                BluetoothAdapter.STATE_ON -> Mesh.startRadio()
                BluetoothAdapter.STATE_TURNING_OFF, BluetoothAdapter.STATE_OFF -> { Mesh.stopRadio(); Mesh.startRadio() }  // start() reports "Bluetooth is off"
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel("mesh", "Mesh relay", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val n = Notification.Builder(this, "mesh").setSmallIcon(R.drawable.ic_stat).setContentTitle("Tucnet mesh is on")
            .setContentText("Finding nearby devices over Bluetooth").setOngoing(true).setContentIntent(open).build()
        runCatching {
            if (Build.VERSION.SDK_INT >= 29) startForeground(1, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
            else startForeground(1, n)
        }
        ContextCompat.registerReceiver(this, bluetoothState, IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED), ContextCompat.RECEIVER_EXPORTED)
        Mesh.startRadio()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        runCatching { unregisterReceiver(bluetoothState) }
        Mesh.stopRadio()
        super.onDestroy()
    }
}

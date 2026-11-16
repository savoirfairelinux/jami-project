package org.tucnet.app

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.os.SystemClock
import org.tucnet.core.Link
import java.nio.ByteBuffer
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Bluetooth Low Energy bearer. Every phone advertises and scans at once. Of two phones that see
 * each other, the one with the lower advertised hint connects as GATT client, so a pair forms one link.
 * Frames are length-prefixed and cut into MTU-sized chunks, one chunk in flight per link.
 */
@SuppressLint("MissingPermission")
@Suppress("DEPRECATION")
class BleBearer(private val ctx: Context, private val cb: Callbacks) {
    interface Callbacks {
        fun hint(): ByteArray
        fun onUp(link: Link)
        fun onDown(linkId: String)
        fun onFrame(linkId: String, frame: ByteArray)
        fun onSeen(hint: ByteArray, rssi: Int)
        fun onState(state: String)
    }

    private val manager = ctx.getSystemService(BluetoothManager::class.java)
    private val handler = Handler(Looper.getMainLooper())
    private val links = ConcurrentHashMap<String, BleLink>()
    private val connecting = ConcurrentHashMap<String, Long>()
    private val serverMtu = ConcurrentHashMap<String, Int>()
    /** Address -> advertised hint of peers we dialled; addresses rotate, hints identify the phone for the day. */
    private val dialled = ConcurrentHashMap<String, String>()
    private var server: BluetoothGattServer? = null
    private var tx: BluetoothGattCharacteristic? = null
    @Volatile private var running = false

    private abstract inner class BleLink(override val id: String, @Volatile var mtu: Int) : Link {
        private val queue = ArrayDeque<ByteArray>()
        private var busy = false
        private var buf = ByteArray(0)

        abstract fun write(chunk: ByteArray): Boolean
        abstract fun close()

        override fun send(frame: ByteArray) {
            val data = ByteBuffer.allocate(4 + frame.size).putInt(frame.size).put(frame).array()
            val size = (mtu - 3).coerceIn(20, 509)
            synchronized(queue) {
                if (queue.size > MAX_QUEUE) return
                var off = 0
                while (off < data.size) { queue.addLast(data.copyOfRange(off, minOf(off + size, data.size))); off += size }
            }
            pump()
        }

        fun pump() {
            val chunk = synchronized(queue) {
                if (busy || queue.isEmpty()) return
                busy = true
                queue.removeFirst()
            }
            if (!runCatching { write(chunk) }.getOrDefault(false)) { synchronized(queue) { busy = false; queue.clear() }; close() }
        }

        fun done() { synchronized(queue) { busy = false }; pump() }

        @Synchronized fun feed(data: ByteArray) {
            buf += data
            while (buf.size >= 4) {
                val len = ByteBuffer.wrap(buf, 0, 4).int
                if (len < 0 || len > MAX_FRAME) { buf = ByteArray(0); close(); return }
                if (buf.size < 4 + len) return
                val frame = buf.copyOfRange(4, 4 + len)
                buf = buf.copyOfRange(4 + len, buf.size)
                cb.onFrame(id, frame)
            }
        }
    }

    // ------------------------------------------------------------ lifecycle

    fun start() {
        if (running) return
        val adapter = manager?.adapter
        if (adapter == null) { cb.onState("No Bluetooth on this phone"); return }
        if (!adapter.isEnabled) { cb.onState("Bluetooth is off"); return }
        running = true
        runCatching {
            openServer()
            advertise()
            scan()
            cb.onState("On")
        }.onFailure { stop(); cb.onState("Bluetooth permission needed") }
        handler.postDelayed(refresh, REFRESH_MS)
    }

    fun stop() {
        running = false
        handler.removeCallbacks(refresh)
        val adapter = manager?.adapter
        runCatching { adapter?.bluetoothLeScanner?.stopScan(scanCallback) }
        runCatching { adapter?.bluetoothLeAdvertiser?.stopAdvertising(advertiseCallback) }
        links.values.toList().forEach { it.close() }
        links.keys.toList().forEach { links.remove(it); cb.onDown(it) }
        runCatching { server?.close() }
        server = null
        connecting.clear()
        dialled.clear()
        cb.onState("Off")
    }

    /** Long scans get throttled by Android and the hint rotates daily, so restart both periodically. */
    private val refresh = object : Runnable {
        override fun run() {
            if (!running) return
            val adapter = manager?.adapter
            runCatching { adapter?.bluetoothLeScanner?.stopScan(scanCallback) }
            runCatching { adapter?.bluetoothLeAdvertiser?.stopAdvertising(advertiseCallback) }
            runCatching { advertise(); scan() }
            handler.postDelayed(this, REFRESH_MS)
        }
    }

    // ------------------------------------------------------------ advertise + scan

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartFailure(errorCode: Int) { cb.onState("On (cannot advertise: $errorCode)") }
    }

    private fun advertise() {
        val advertiser = manager.adapter.bluetoothLeAdvertiser ?: run { cb.onState("On (this phone cannot advertise)"); return }
        val settings = AdvertiseSettings.Builder().setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM).setConnectable(true).setTimeout(0).build()
        val data = AdvertiseData.Builder().setIncludeDeviceName(false).addServiceUuid(ParcelUuid(SERVICE)).build()
        val response = AdvertiseData.Builder().setIncludeDeviceName(false).addManufacturerData(MANUFACTURER, cb.hint()).build()
        advertiser.startAdvertising(settings, data, response, advertiseCallback)
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val theirs = result.scanRecord?.getManufacturerSpecificData(MANUFACTURER) ?: return
            if (theirs.size != 8) return
            cb.onSeen(theirs, result.rssi)
            if (compare(cb.hint(), theirs) < 0) connect(result.device, theirs.joinToString("") { "%02x".format(it) })
        }
    }

    private fun scan() {
        val scanner = manager.adapter.bluetoothLeScanner ?: return
        val filter = ScanFilter.Builder().setServiceUuid(ParcelUuid(SERVICE)).build()
        val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_BALANCED).build()
        scanner.startScan(listOf(filter), settings, scanCallback)
    }

    private fun compare(a: ByteArray, b: ByteArray): Int {
        for (i in a.indices) { val d = (a[i].toInt() and 0xFF) - (b[i].toInt() and 0xFF); if (d != 0) return d }
        return 0
    }

    // ------------------------------------------------------------ client role

    private fun connect(device: BluetoothDevice, hint: String) {
        val addr = device.address
        if (dialled.containsValue(hint)) return
        if (!running || links.containsKey("c:$addr") || links.containsKey("s:$addr") || links.size >= MAX_LINKS) return
        val t = SystemClock.elapsedRealtime()
        connecting[addr]?.let { if (t - it < CONNECT_TIMEOUT_MS) return }
        connecting[addr] = t
        dialled[addr] = hint

        val callback = object : BluetoothGattCallback() {
            var link: BleLink? = null
            var mtu = 23
            var rx: BluetoothGattCharacteristic? = null

            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                if (newState == BluetoothProfile.STATE_CONNECTED && status == BluetoothGatt.GATT_SUCCESS) {
                    if (!gatt.requestMtu(517)) gatt.discoverServices()
                } else {
                    connecting.remove(addr)
                    dialled.remove(addr)
                    link?.let { links.remove(it.id); cb.onDown(it.id) }
                    link = null
                    gatt.close()
                }
            }

            override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS) this.mtu = mtu
                gatt.discoverServices()
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                val service = gatt.getService(SERVICE)
                val notify = service?.getCharacteristic(TX)
                rx = service?.getCharacteristic(RX)
                val cccd = notify?.getDescriptor(CCCD)
                if (rx == null || notify == null || cccd == null) { gatt.disconnect(); return }
                gatt.setCharacteristicNotification(notify, true)
                cccd.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                if (!gatt.writeDescriptor(cccd)) gatt.disconnect()
            }

            override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
                if (status != BluetoothGatt.GATT_SUCCESS) { gatt.disconnect(); return }
                val target = rx ?: return
                val l = object : BleLink("c:$addr", mtu) {
                    override fun write(chunk: ByteArray): Boolean {
                        target.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                        target.value = chunk
                        return gatt.writeCharacteristic(target)
                    }
                    override fun close() { runCatching { gatt.disconnect() } }
                }
                link = l
                links[l.id] = l
                cb.onUp(l)
            }

            override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS) link?.done() else gatt.disconnect()
            }

            override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
                link?.feed(value)
            }

            @Deprecated("Used below Android 13")
            override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
                if (Build.VERSION.SDK_INT < 33) characteristic.value?.let { link?.feed(it) }
            }
        }
        runCatching { device.connectGatt(ctx, false, callback, BluetoothDevice.TRANSPORT_LE) }
            .onFailure { connecting.remove(addr); dialled.remove(addr) }
    }

    // ------------------------------------------------------------ server role

    private fun openServer() {
        val notify = BluetoothGattCharacteristic(TX, BluetoothGattCharacteristic.PROPERTY_NOTIFY, 0).apply {
            addDescriptor(BluetoothGattDescriptor(CCCD, BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE))
        }
        val write = BluetoothGattCharacteristic(RX, BluetoothGattCharacteristic.PROPERTY_WRITE, BluetoothGattCharacteristic.PERMISSION_WRITE)
        val service = BluetoothGattService(SERVICE, BluetoothGattService.SERVICE_TYPE_PRIMARY).apply {
            addCharacteristic(write); addCharacteristic(notify)
        }
        tx = notify
        server = manager.openGattServer(ctx, serverCallback)?.also { it.addService(service) }
    }

    private val serverCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                serverMtu.remove(device.address)
                links.remove("s:${device.address}")?.let { cb.onDown(it.id) }
            }
        }

        override fun onMtuChanged(device: BluetoothDevice, mtu: Int) {
            serverMtu[device.address] = mtu
            links["s:${device.address}"]?.mtu = mtu
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice, requestId: Int, characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean, responseNeeded: Boolean, offset: Int, value: ByteArray,
        ) {
            if (responseNeeded) server?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
            links["s:${device.address}"]?.feed(value)
        }

        override fun onDescriptorReadRequest(device: BluetoothDevice, requestId: Int, offset: Int, descriptor: BluetoothGattDescriptor) {
            server?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
        }

        override fun onDescriptorWriteRequest(
            device: BluetoothDevice, requestId: Int, descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean, responseNeeded: Boolean, offset: Int, value: ByteArray,
        ) {
            if (responseNeeded) server?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
            val id = "s:${device.address}"
            if (!value.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE) || links.containsKey(id)) return
            val l = object : BleLink(id, serverMtu[device.address] ?: 23) {
                override fun write(chunk: ByteArray): Boolean {
                    val c = tx ?: return false
                    c.value = chunk
                    return server?.notifyCharacteristicChanged(device, c, false) ?: false
                }
                override fun close() { runCatching { server?.cancelConnection(device) } }
            }
            links[id] = l
            cb.onUp(l)
        }

        override fun onNotificationSent(device: BluetoothDevice, status: Int) {
            val l = links["s:${device.address}"] ?: return
            if (status == BluetoothGatt.GATT_SUCCESS) l.done() else l.close()
        }
    }

    companion object {
        val SERVICE: UUID = UUID.fromString("7e5c0001-7a3b-4c1d-9f20-54554e455431")
        val RX: UUID = UUID.fromString("7e5c0002-7a3b-4c1d-9f20-54554e455431")
        val TX: UUID = UUID.fromString("7e5c0003-7a3b-4c1d-9f20-54554e455431")
        val CCCD: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
        private const val MANUFACTURER = 0xFFFF
        private const val MAX_LINKS = 6
        private const val MAX_QUEUE = 4000
        private const val MAX_FRAME = 70_000
        private const val CONNECT_TIMEOUT_MS = 20_000L
        private const val REFRESH_MS = 20 * 60_000L
    }
}

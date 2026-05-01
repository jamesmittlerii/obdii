package com.rheosoft.obdii.android.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.rheosoft.obdii.core.communication.ble.BleCharacteristic
import com.rheosoft.obdii.core.communication.ble.BlePeripheral
import com.rheosoft.obdii.core.communication.ble.BlePlatformAdapter
import com.rheosoft.obdii.core.communication.ble.BleService
import com.rheosoft.obdii.core.protocols.CommunicationError
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

private class GattSession(
    val gatt: BluetoothGatt,
    val callback: BluetoothGattCallback,
) {
    @Volatile var connectContinuation: CancellableContinuation<Unit>? = null
    @Volatile var writeContinuation: CancellableContinuation<Unit>? = null
    @Volatile var discoverContinuation: CancellableContinuation<List<BleService>>? = null
    @Volatile var descriptorContinuation: CancellableContinuation<Unit>? = null
    val services = mutableListOf<BluetoothGattService>()
}

class AndroidBlePlatformAdapter(private val context: Context) : BlePlatformAdapter {
    private val tag = "OBDII-BLE"
    private val bleDebugLogs = false
    private val bluetoothManager: BluetoothManager? =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    private val adapter: BluetoothAdapter?
        get() = bluetoothManager?.adapter

    private val devices = ConcurrentHashMap<String, android.bluetooth.BluetoothDevice>()
    private val sessions = ConcurrentHashMap<String, GattSession>()
    private val listeners = ConcurrentHashMap<String, (ByteArray) -> Unit>()

    override suspend fun scan(timeoutMs: Long, serviceUuids: Set<String>): List<BlePeripheral> = withContext(Dispatchers.Main) {
        val bt = adapter ?: throw CommunicationError("Bluetooth adapter unavailable")
        if (!bt.isEnabled) throw CommunicationError("Bluetooth is disabled")
        val scanner = bt.bluetoothLeScanner ?: throw CommunicationError("BLE scanner unavailable")
        logI("scan:start timeoutMs=$timeoutMs serviceUuids=$serviceUuids")

        suspendCancellableCoroutine { continuation ->
            val found = LinkedHashMap<String, BlePeripheral>()
            val mainHandler = Handler(Looper.getMainLooper())
            var completed = false

            // Include bonded devices up front as fallback candidates.
            runCatching {
                bt.bondedDevices?.forEach { device ->
                    val id = device.address ?: return@forEach
                    devices[id] = device
                    found[id] = BlePeripheral(id = id, name = device.name)
                    logD("scan:bonded-candidate id=$id name=${device.name}")
                }
            }
            val callback = object : ScanCallback() {
                override fun onScanResult(callbackType: Int, result: ScanResult) {
                    val device = result.device ?: return
                    val id = device.address ?: return
                    devices[id] = device
                    found[id] = BlePeripheral(id = id, name = device.name, rssi = result.rssi)
                    logD("scan:found id=$id name=${device.name} rssi=${result.rssi}")
                    // Swift parity behavior: as soon as a likely OBD adapter is seen, stop scanning.
                    val name = device.name?.uppercase().orEmpty()
                    if (!completed && (name.contains("OBD") || name.contains("ELM") || name.contains("VLINK") || name.contains("VGATE"))) {
                        completed = true
                        mainHandler.removeCallbacksAndMessages(null)
                        runCatching { scanner.stopScan(this) }
                        logI("scan:early-stop candidate name=${device.name} id=$id found=${found.size}")
                        if (continuation.isActive) continuation.resume(found.values.toList())
                    }
                }

                override fun onBatchScanResults(results: MutableList<ScanResult>) {
                    results.forEach { onScanResult(0, it) }
                }

                override fun onScanFailed(errorCode: Int) {
                    logE("scan:failed code=$errorCode")
                    stopAndResumeWithError(scanner, this, mainHandler, continuation, CommunicationError("BLE scan failed: $errorCode"))
                }
            }

            val timeout = Runnable {
                if (completed) return@Runnable
                completed = true
                runCatching { scanner.stopScan(callback) }
                logI("scan:timeout found=${found.size}")
                if (continuation.isActive) continuation.resume(found.values.toList())
            }

            continuation.invokeOnCancellation {
                mainHandler.removeCallbacks(timeout)
                runCatching { scanner.stopScan(callback) }
            }

            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .build()

            runCatching {
                // Flutter parity: broad scan is more reliable on Android adapters that do not advertise service UUIDs.
                scanner.startScan(null, settings, callback)
            }
                .onFailure { error ->
                    stopAndResumeWithError(scanner, callback, mainHandler, continuation, CommunicationError("BLE scan start failed", error))
                    return@suspendCancellableCoroutine
                }

            mainHandler.postDelayed(timeout, timeoutMs.coerceAtLeast(1000))
        }
    }

    @SuppressLint("MissingPermission")
    override suspend fun connect(peripheralId: String, timeoutMs: Long) = withContext(Dispatchers.Main) {
        logI("connect:start id=$peripheralId timeoutMs=$timeoutMs")
        val device = devices[peripheralId] ?: adapter?.getRemoteDevice(peripheralId)
            ?: throw CommunicationError("Unknown BLE peripheral: $peripheralId")

        suspendCancellableCoroutine { continuation ->
            var completed = false
            val mainHandler = Handler(Looper.getMainLooper())
            val timeout = Runnable {
                if (completed) return@Runnable
                completed = true
                val session = sessions.remove(peripheralId)
                runCatching { session?.gatt?.disconnect() }
                runCatching { session?.gatt?.close() }
                if (continuation.isActive) continuation.resumeWithException(CommunicationError("BLE connect timed out"))
            }

            val callback = object : BluetoothGattCallback() {
                override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                    logI("connect:state status=$status newState=$newState id=$peripheralId")
                    if (status != BluetoothGatt.GATT_SUCCESS || newState == BluetoothGatt.STATE_DISCONNECTED) {
                        if (!completed && continuation.isActive) {
                            completed = true
                            mainHandler.removeCallbacks(timeout)
                            continuation.resumeWithException(CommunicationError("BLE connection failed (status=$status, state=$newState)"))
                        }
                        runCatching { gatt.close() }
                        sessions.remove(peripheralId)
                        return
                    }
                    if (newState == BluetoothGatt.STATE_CONNECTED) {
                        if (!gatt.discoverServices() && !completed && continuation.isActive) {
                            completed = true
                            mainHandler.removeCallbacks(timeout)
                            continuation.resumeWithException(CommunicationError("BLE discoverServices failed to start"))
                        }
                    }
                }

                override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                    val session = sessions[peripheralId] ?: return
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        session.services.clear()
                        session.services.addAll(gatt.services ?: emptyList())
                        logI("services:count=${session.services.size} ids=${session.services.joinToString { shortUuid(it.uuid) }}")
                        session.discoverContinuation?.let { cont ->
                            if (cont.isActive) cont.resume(session.services.map { BleService(shortUuid(it.uuid)) })
                            session.discoverContinuation = null
                        }
                        if (!completed && continuation.isActive) {
                            completed = true
                            mainHandler.removeCallbacks(timeout)
                            continuation.resume(Unit)
                        }
                    } else {
                        session.discoverContinuation?.let { cont ->
                            if (cont.isActive) cont.resumeWithException(CommunicationError("BLE service discovery failed: $status"))
                            session.discoverContinuation = null
                        }
                        if (!completed && continuation.isActive) {
                            completed = true
                            mainHandler.removeCallbacks(timeout)
                            continuation.resumeWithException(CommunicationError("BLE service discovery failed: $status"))
                        }
                    }
                }

                override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
                    val key = listenerKey(peripheralId, shortUuid(characteristic.uuid))
                    logD("notify:char=${shortUuid(characteristic.uuid)} payload=${value.toHexPreview()}")
                    listeners[key]?.invoke(value)
                }

                @Suppress("DEPRECATION")
                override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
                    val payload = characteristic.value ?: ByteArray(0)
                    val key = listenerKey(peripheralId, shortUuid(characteristic.uuid))
                    logD("notify:char=${shortUuid(characteristic.uuid)} payload=${payload.toHexPreview()}")
                    listeners[key]?.invoke(payload)
                }

                override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
                    val session = sessions[peripheralId] ?: return
                    val cont = session.writeContinuation ?: return
                    session.writeContinuation = null
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        if (cont.isActive) cont.resume(Unit)
                    } else {
                        if (cont.isActive) cont.resumeWithException(CommunicationError("BLE write failed: $status"))
                    }
                }

                override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
                    val session = sessions[peripheralId] ?: return
                    val cont = session.descriptorContinuation ?: return
                    session.descriptorContinuation = null
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        if (cont.isActive) cont.resume(Unit)
                    } else {
                        if (cont.isActive) cont.resumeWithException(CommunicationError("BLE descriptor write failed: $status"))
                    }
                }
            }

            val gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
            } else {
                device.connectGatt(context, false, callback)
            } ?: run {
                continuation.resumeWithException(CommunicationError("BLE connectGatt returned null"))
                return@suspendCancellableCoroutine
            }

            sessions[peripheralId] = GattSession(gatt, callback)
            continuation.invokeOnCancellation {
                mainHandler.removeCallbacks(timeout)
                val session = sessions.remove(peripheralId)
                runCatching { session?.gatt?.disconnect() }
                runCatching { session?.gatt?.close() }
            }
            mainHandler.postDelayed(timeout, timeoutMs.coerceAtLeast(1000))
        }
    }

    override suspend fun disconnect(peripheralId: String): Unit = withContext(Dispatchers.Main) {
        val session = sessions.remove(peripheralId) ?: return@withContext
        runCatching { session.gatt.disconnect() }
        runCatching { session.gatt.close() }
    }

    override suspend fun discoverServices(peripheralId: String): List<BleService> = withContext(Dispatchers.Main) {
        val session = sessions[peripheralId] ?: throw CommunicationError("BLE session not connected")
        if (session.services.isNotEmpty()) {
            return@withContext session.services.map { BleService(shortUuid(it.uuid)) }
        }
        suspendCancellableCoroutine { continuation ->
            session.discoverContinuation = continuation
            if (!session.gatt.discoverServices()) {
                session.discoverContinuation = null
                continuation.resumeWithException(CommunicationError("BLE discoverServices failed to start"))
            }
        }
    }

    override suspend fun discoverCharacteristics(peripheralId: String, serviceUuid: String): List<BleCharacteristic> = withContext(Dispatchers.Main) {
        val session = sessions[peripheralId] ?: throw CommunicationError("BLE session not connected")
        val services = if (session.services.isEmpty()) {
            discoverServices(peripheralId)
            session.services
        } else {
            session.services
        }
        val target = services.firstOrNull { shortUuid(it.uuid) == shortUuid(serviceUuid) }
            ?: return@withContext emptyList()
        val mapped = target.characteristics.map { ch ->
            BleCharacteristic(
                uuid = shortUuid(ch.uuid),
                canRead = ch.properties and BluetoothGattCharacteristic.PROPERTY_READ != 0,
                canWrite = ch.properties and BluetoothGattCharacteristic.PROPERTY_WRITE != 0 ||
                    ch.properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0,
                canNotify = ch.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0 ||
                    ch.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0,
            )
        }
        logI("chars:service=${shortUuid(target.uuid)} count=${mapped.size} values=${mapped.joinToString { "${it.uuid}(r=${it.canRead},w=${it.canWrite},n=${it.canNotify})" }}")
        return@withContext mapped
    }

    override suspend fun enableNotifications(peripheralId: String, characteristicUuid: String) = withContext(Dispatchers.Main) {
        val session = sessions[peripheralId] ?: throw CommunicationError("BLE session not connected")
        val characteristic = findCharacteristic(session.gatt, characteristicUuid)
            ?: throw CommunicationError("BLE characteristic $characteristicUuid not found")
        if (!session.gatt.setCharacteristicNotification(characteristic, true)) {
            throw CommunicationError("BLE setCharacteristicNotification failed")
        }
        val cccdUuid = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
        val descriptor = characteristic.getDescriptor(cccdUuid)
        if (descriptor != null) {
            val supportsNotify = characteristic.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0
            val supportsIndicate = characteristic.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0
            val descriptorValue = when {
                supportsNotify -> BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                supportsIndicate -> BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
                else -> BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            }
            suspendCancellableCoroutine<Unit> { continuation ->
                session.descriptorContinuation = continuation
                val started = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    val rc = session.gatt.writeDescriptor(descriptor, descriptorValue)
                    rc == BluetoothGatt.GATT_SUCCESS
                } else {
                    @Suppress("DEPRECATION")
                    descriptor.value = descriptorValue
                    @Suppress("DEPRECATION")
                    session.gatt.writeDescriptor(descriptor)
                }
                if (!started) {
                    session.descriptorContinuation = null
                    continuation.resumeWithException(CommunicationError("BLE writeDescriptor failed"))
                    return@suspendCancellableCoroutine
                }
                continuation.invokeOnCancellation {
                    if (session.descriptorContinuation === continuation) {
                        session.descriptorContinuation = null
                    }
                }
            }
        }
    }

    override suspend fun write(peripheralId: String, characteristicUuid: String, payload: ByteArray) = withContext(Dispatchers.Main) {
        val session = sessions[peripheralId] ?: throw CommunicationError("BLE session not connected")
        val characteristic = findCharacteristic(session.gatt, characteristicUuid)
            ?: throw CommunicationError("BLE characteristic $characteristicUuid not found")
        val props = characteristic.properties
        val supportsWrite = props and BluetoothGattCharacteristic.PROPERTY_WRITE != 0
        val supportsWriteNoResp = props and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0
        characteristic.writeType = when {
            supportsWrite -> BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            supportsWriteNoResp -> BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            else -> BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        }
        logD("write:start char=${shortUuid(characteristic.uuid)} type=${characteristic.writeType} payload=${payload.toHexPreview()}")

        if (characteristic.writeType == BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE) {
            val started = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val rc = session.gatt.writeCharacteristic(characteristic, payload, characteristic.writeType)
                rc == BluetoothGatt.GATT_SUCCESS
            } else {
                @Suppress("DEPRECATION")
                characteristic.value = payload
                @Suppress("DEPRECATION")
                session.gatt.writeCharacteristic(characteristic)
            }
            if (!started) throw CommunicationError("BLE write(no-response) start failed")
            return@withContext
        }

        suspendCancellableCoroutine<Unit> { continuation ->
            session.writeContinuation = continuation
            val started = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val rc = session.gatt.writeCharacteristic(characteristic, payload, characteristic.writeType)
                rc == BluetoothGatt.GATT_SUCCESS
            } else {
                @Suppress("DEPRECATION")
                characteristic.value = payload
                @Suppress("DEPRECATION")
                session.gatt.writeCharacteristic(characteristic)
            }
            if (!started) {
                session.writeContinuation = null
                continuation.resumeWithException(CommunicationError("BLE write start failed"))
            }
            continuation.invokeOnCancellation {
                if (session.writeContinuation === continuation) {
                    session.writeContinuation = null
                }
            }
        }
    }

    override fun setNotificationListener(peripheralId: String, characteristicUuid: String, listener: (ByteArray) -> Unit) {
        listeners[listenerKey(peripheralId, shortUuid(characteristicUuid))] = listener
    }

    private fun findCharacteristic(gatt: BluetoothGatt, uuid: String): BluetoothGattCharacteristic? {
        val target = shortUuid(uuid)
        return gatt.services
            ?.asSequence()
            ?.flatMap { it.characteristics.asSequence() }
            ?.firstOrNull { shortUuid(it.uuid) == target }
    }

    private fun listenerKey(peripheralId: String, characteristicUuid: String): String =
        "$peripheralId|${shortUuid(characteristicUuid)}"

    private fun shortUuid(uuid: UUID): String = shortUuid(uuid.toString())

    private fun shortUuid(raw: String): String {
        val lower = raw.lowercase()
        val basePrefix = "0000"
        val baseSuffix = "-0000-1000-8000-00805f9b34fb"
        return if (lower.startsWith(basePrefix) && lower.endsWith(baseSuffix) && lower.length == 36) {
            lower.substring(4, 8).uppercase()
        } else {
            raw.replace("-", "").uppercase()
        }
    }

    private fun stopAndResumeWithError(
        scanner: android.bluetooth.le.BluetoothLeScanner,
        callback: ScanCallback,
        handler: Handler,
        continuation: CancellableContinuation<List<BlePeripheral>>,
        error: Throwable,
    ) {
        handler.removeCallbacksAndMessages(null)
        runCatching { scanner.stopScan(callback) }
        if (continuation.isActive) continuation.resumeWithException(error)
    }

    private fun ByteArray.toHexPreview(maxLen: Int = 24): String {
        if (isEmpty()) return "0b"
        val head = take(maxLen).joinToString(" ") { "%02X".format(it) }
        val suffix = if (size > maxLen) " …(${size}b)" else " (${size}b)"
        return head + suffix
    }

    private fun logD(message: String) {
        if (bleDebugLogs) Log.d(tag, message)
    }

    private fun logI(message: String) {
        if (bleDebugLogs) Log.i(tag, message)
    }

    private fun logE(message: String) {
        if (bleDebugLogs) Log.e(tag, message)
    }
}

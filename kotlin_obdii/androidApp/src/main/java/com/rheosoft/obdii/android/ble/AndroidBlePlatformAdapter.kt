package com.rheosoft.obdii.android.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothProfile
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
import androidx.core.content.ContextCompat
import com.rheosoft.obdii.core.LogCategory
import com.rheosoft.obdii.core.ObdLogger
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

private const val ERR_SESSION_NOT_CONNECTED = "BLE session not connected"
private val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

class AndroidBlePlatformAdapter(private val context: Context) : BlePlatformAdapter {
    private val bleDebugLogs = true
    private val bluetoothManager: BluetoothManager? =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    private val adapter: BluetoothAdapter?
        get() = bluetoothManager?.adapter

    private val devices = ConcurrentHashMap<String, android.bluetooth.BluetoothDevice>()
    private val sessions = ConcurrentHashMap<String, GattSession>()
    private val listeners = ConcurrentHashMap<String, (ByteArray) -> Unit>()



    @SuppressLint("MissingPermission")
    override suspend fun scan(timeoutMs: Long, serviceUuids: Set<String>): List<BlePeripheral> = withContext(Dispatchers.Main) {
        val bt = adapter ?: throw CommunicationError("Bluetooth adapter unavailable")
        if (!bt.isEnabled) throw CommunicationError("Bluetooth is disabled")
        val scanner = bt.bluetoothLeScanner ?: throw CommunicationError("BLE scanner unavailable")
        logI("scan:start timeoutMs=$timeoutMs serviceUuids=$serviceUuids")

        suspendCancellableCoroutine { continuation ->
            val found = LinkedHashMap<String, BlePeripheral>()
            val mainHandler = Handler(Looper.getMainLooper())
            var completed = false
            fun completeWith(results: List<BlePeripheral>) {
                completed = true
                mainHandler.removeCallbacksAndMessages(null)
                if (continuation.isActive) continuation.resume(results)
            }

            // Include only bonded OBD-like devices as fallback candidates.
            addBondedCandidates(bt, found)
            val callback = object : ScanCallback() {
                @SuppressLint("MissingPermission")
                override fun onScanResult(callbackType: Int, result: ScanResult) {
                    val peripheral = recordScanResult(result, found) ?: return
                    // Swift parity behavior: as soon as a likely OBD adapter is seen, stop scanning.
                    if (!completed && isLikelyObdDeviceName(peripheral.name)) {
                        runCatching { scanner.stopScan(this) }
                        logI("scan:early-stop candidate name=${peripheral.name} id=${peripheral.id} found=${found.size}")
                        completeWith(found.values.toList())
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
                @SuppressLint("MissingPermission")
                runCatching { scanner.stopScan(callback) }
                logI("scan:timeout found=${found.size}")
                completeWith(found.values.toList())
            }

            continuation.invokeOnCancellation {
                mainHandler.removeCallbacks(timeout)
                @SuppressLint("MissingPermission")
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
    private fun recordScanResult(
        result: ScanResult,
        found: LinkedHashMap<String, BlePeripheral>,
    ): BlePeripheral? {
        val device = result.device ?: return null
        val id = device.address ?: return null
        val peripheral = BlePeripheral(id = id, name = device.name, rssi = result.rssi)
        devices[id] = device
        found[id] = peripheral
        logD("scan:found id=$id name=${device.name} rssi=${result.rssi}")
        return peripheral
    }

    @SuppressLint("MissingPermission")
    private fun addBondedCandidates(bt: BluetoothAdapter, found: LinkedHashMap<String, BlePeripheral>) {
        runCatching {
            bt.bondedDevices?.forEach { device ->
                val id = device.address ?: return@forEach
                if (!isLikelyObdDeviceName(device.name)) {
                    logD("scan:bonded-skip id=$id name=${device.name}")
                    return@forEach
                }
                devices[id] = device
                found[id] = BlePeripheral(id = id, name = device.name)
                logD("scan:bonded-candidate id=$id name=${device.name}")
            }
        }
    }

    @SuppressLint("MissingPermission")
    override suspend fun connect(peripheralId: String, timeoutMs: Long) = withContext(Dispatchers.Main) {
        logI("connect:start id=$peripheralId timeoutMs=$timeoutMs")
        val device = devices[peripheralId] ?: adapter?.getRemoteDevice(peripheralId)
            ?: throw CommunicationError("Unknown BLE peripheral: $peripheralId")

        suspendCancellableCoroutine { continuation ->
            val attempt = ConnectionAttempt(peripheralId, continuation)
            val gatt = device.openGatt(attempt.callback) ?: run {
                continuation.resumeWithException(CommunicationError("BLE connectGatt returned null"))
                return@suspendCancellableCoroutine
            }

            sessions[peripheralId] = GattSession(gatt, attempt.callback)
            continuation.invokeOnCancellation {
                attempt.cancelTimeout()
                closeSession(peripheralId, disconnect = true)
            }
            attempt.scheduleTimeout(timeoutMs)
        }
    }

    private inner class ConnectionAttempt(
        private val peripheralId: String,
        private val continuation: CancellableContinuation<Unit>,
    ) {
        private var completed = false
        private val mainHandler = Handler(Looper.getMainLooper())
        private val timeout = Runnable {
            if (completed) return@Runnable
            completed = true
            closeSession(peripheralId, disconnect = true)
            if (continuation.isActive) {
                continuation.resumeWithException(CommunicationError("BLE connect timed out"))
            }
        }

        val callback: BluetoothGattCallback = object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                handleConnectionStateChange(gatt, status, newState)
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                handleServicesDiscovered(gatt, status)
            }

            override fun onCharacteristicChanged(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                value: ByteArray,
            ) {
                notifyListener(peripheralId, characteristic, value)
            }

            @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
            override fun onCharacteristicChanged(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
            ) {
                notifyListener(peripheralId, characteristic, characteristic.value ?: ByteArray(0))
            }

            override fun onCharacteristicWrite(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                status: Int,
            ) {
                resumeWrite(status)
            }

            override fun onDescriptorWrite(
                gatt: BluetoothGatt,
                descriptor: BluetoothGattDescriptor,
                status: Int,
            ) {
                resumeDescriptorWrite(status)
            }
        }

        fun scheduleTimeout(timeoutMs: Long) {
            mainHandler.postDelayed(timeout, timeoutMs.coerceAtLeast(1000))
        }

        fun cancelTimeout() {
            mainHandler.removeCallbacks(timeout)
        }

        @SuppressLint("MissingPermission")
        private fun handleConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            logI("connect:state status=$status newState=$newState id=$peripheralId")
            when {
                isFailedConnectionState(status, newState) -> failConnectionState(gatt, status, newState)
                newState == BluetoothProfile.STATE_CONNECTED && !gatt.discoverServices() ->
                    failConnection("BLE discoverServices failed to start")
            }
        }

        private fun handleServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            val session = sessions[peripheralId] ?: return
            if (status == BluetoothGatt.GATT_SUCCESS) {
                completeServiceDiscovery(session, gatt)
            } else {
                failServiceDiscovery(session, status)
            }
        }

        private fun completeServiceDiscovery(session: GattSession, gatt: BluetoothGatt) {
            cacheDiscoveredServices(session, gatt)
            resumeDiscovery(session)
            completeConnection()
        }

        private fun failServiceDiscovery(session: GattSession, status: Int) {
            val error = CommunicationError("BLE service discovery failed: $status")
            resumeDiscoveryWithError(session, error)
            failConnection("BLE service discovery failed: $status")
        }

        private fun completeConnection() {
            if (completed || !continuation.isActive) return
            completed = true
            cancelTimeout()
            continuation.resume(Unit)
        }

        private fun failConnectionState(gatt: BluetoothGatt, status: Int, newState: Int) {
            failConnection("BLE connection failed (status=$status, state=$newState)")
            runCatching { gatt.close() }
            sessions.remove(peripheralId)
        }

        private fun failConnection(message: String, cause: Throwable? = null) {
            if (completed || !continuation.isActive) return
            completed = true
            cancelTimeout()
            continuation.resumeWithException(CommunicationError(message, cause))
        }

        private fun resumeWrite(status: Int) {
            val session = sessions[peripheralId] ?: return
            resumeUnitContinuation(
                continuation = session.writeContinuation,
                error = statusError(status, "BLE write failed"),
            )
            session.writeContinuation = null
        }

        private fun resumeDescriptorWrite(status: Int) {
            val session = sessions[peripheralId] ?: return
            resumeUnitContinuation(
                continuation = session.descriptorContinuation,
                error = statusError(status, "BLE descriptor write failed"),
            )
            session.descriptorContinuation = null
        }
    }

    @SuppressLint("MissingPermission")
    private fun BluetoothDevice.openGatt(callback: BluetoothGattCallback): BluetoothGatt? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
        } else {
            @Suppress("DEPRECATION")
            connectGatt(context, false, callback)
        }

    private fun isFailedConnectionState(status: Int, newState: Int): Boolean =
        status != BluetoothGatt.GATT_SUCCESS || newState == BluetoothProfile.STATE_DISCONNECTED

    @SuppressLint("MissingPermission")
    private fun closeSession(peripheralId: String, disconnect: Boolean) {
        val session = sessions.remove(peripheralId) ?: return
        if (disconnect) runCatching { session.gatt.disconnect() }
        runCatching { session.gatt.close() }
    }

    private fun cacheDiscoveredServices(session: GattSession, gatt: BluetoothGatt) {
        session.services.clear()
        session.services.addAll(gatt.services ?: emptyList())
        logI("services:count=${session.services.size} ids=${session.services.joinToString { shortUuid(it.uuid) }}")
    }

    private fun resumeDiscovery(session: GattSession) {
        val cont = session.discoverContinuation ?: return
        session.discoverContinuation = null
        if (cont.isActive) cont.resume(session.services.map { BleService(shortUuid(it.uuid)) })
    }

    private fun resumeDiscoveryWithError(session: GattSession, error: Throwable) {
        val cont = session.discoverContinuation ?: return
        session.discoverContinuation = null
        if (cont.isActive) cont.resumeWithException(error)
    }

    private fun notifyListener(
        peripheralId: String,
        characteristic: BluetoothGattCharacteristic,
        payload: ByteArray,
    ) {
        val shortCharacteristicUuid = shortUuid(characteristic.uuid)
        logD("notify:char=$shortCharacteristicUuid payload=${payload.toHexPreview()}")
        listeners[listenerKey(peripheralId, shortCharacteristicUuid)]?.invoke(payload)
    }

    private fun statusError(status: Int, message: String): CommunicationError? =
        if (status == BluetoothGatt.GATT_SUCCESS) null else CommunicationError("$message: $status")

    private fun resumeUnitContinuation(
        continuation: CancellableContinuation<Unit>?,
        error: Throwable?,
    ) {
        val cont = continuation ?: return
        if (!cont.isActive) return
        if (error == null) cont.resume(Unit) else cont.resumeWithException(error)
    }

    override suspend fun disconnect(peripheralId: String): Unit = withContext(Dispatchers.Main) {
        val session = sessions.remove(peripheralId) ?: return@withContext

        runCatching { @SuppressLint("MissingPermission")
        session.gatt.disconnect() }
        runCatching { @SuppressLint("MissingPermission")
        session.gatt.close() }
    }

    @SuppressLint("MissingPermission")
    override suspend fun discoverServices(peripheralId: String): List<BleService> = withContext(Dispatchers.Main) {
        val session = sessions[peripheralId] ?: throw CommunicationError(ERR_SESSION_NOT_CONNECTED)
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
        val session = sessions[peripheralId] ?: throw CommunicationError(ERR_SESSION_NOT_CONNECTED)
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
    @SuppressLint("MissingPermission")
    override suspend fun enableNotifications(peripheralId: String, characteristicUuid: String) = withContext(Dispatchers.Main) {
        val session = sessions[peripheralId] ?: throw CommunicationError(ERR_SESSION_NOT_CONNECTED)
        val characteristic = findCharacteristic(session.gatt, characteristicUuid)
            ?: throw CommunicationError("BLE characteristic $characteristicUuid not found")
        if (!session.gatt.setCharacteristicNotification(characteristic, true)) {
            throw CommunicationError("BLE setCharacteristicNotification failed")
        }
        writeNotificationDescriptor(session, characteristic)
    }

    @SuppressLint("MissingPermission")
    private suspend fun writeNotificationDescriptor(
        session: GattSession,
        characteristic: BluetoothGattCharacteristic,
    ) {
        val descriptor = characteristic.getDescriptor(CCCD_UUID) ?: return
        val descriptorValue = notificationDescriptorValue(characteristic)
        suspendCancellableCoroutine<Unit> { continuation ->
            session.descriptorContinuation = continuation
            if (!startDescriptorWrite(session.gatt, descriptor, descriptorValue)) {
                session.descriptorContinuation = null
                continuation.resumeWithException(CommunicationError("BLE writeDescriptor failed"))
                return@suspendCancellableCoroutine
            }
            clearDescriptorContinuationOnCancel(session, continuation)
        }
    }

    private fun notificationDescriptorValue(characteristic: BluetoothGattCharacteristic): ByteArray {
        val supportsNotify = characteristic.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0
        val supportsIndicate = characteristic.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0
        return when {
            supportsNotify -> BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            supportsIndicate -> BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
            else -> BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        }
    }

    @SuppressLint("MissingPermission")
    private fun startDescriptorWrite(
        gatt: BluetoothGatt,
        descriptor: BluetoothGattDescriptor,
        descriptorValue: ByteArray,
    ): Boolean = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        gatt.writeDescriptor(descriptor, descriptorValue) == BluetoothGatt.GATT_SUCCESS
    } else {
        @Suppress("DEPRECATION")
        descriptor.value = descriptorValue
        @Suppress("DEPRECATION")
        gatt.writeDescriptor(descriptor)
    }

    private fun clearDescriptorContinuationOnCancel(
        session: GattSession,
        continuation: CancellableContinuation<Unit>,
    ) {
        continuation.invokeOnCancellation {
            if (session.descriptorContinuation === continuation) {
                session.descriptorContinuation = null
            }
        }
    }

    @SuppressLint("MissingPermission")
    override suspend fun write(peripheralId: String, characteristicUuid: String, payload: ByteArray) = withContext(Dispatchers.Main) {
        val session = sessions[peripheralId] ?: throw CommunicationError(ERR_SESSION_NOT_CONNECTED)
        val characteristic = findCharacteristic(session.gatt, characteristicUuid)
            ?: throw CommunicationError("BLE characteristic $characteristicUuid not found")
        characteristic.writeType = preferredWriteType(characteristic)
        logD("write:start char=${shortUuid(characteristic.uuid)} type=${characteristic.writeType} payload=${payload.toHexPreview()}")

        if (characteristic.writeType == BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE) {
            val started = startCharacteristicWrite(session.gatt, characteristic, payload)
            if (!started) throw CommunicationError("BLE write(no-response) start failed")
            return@withContext
        }

        suspendCancellableCoroutine<Unit> { continuation ->
            session.writeContinuation = continuation
            val started = startCharacteristicWrite(session.gatt, characteristic, payload)
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

    private fun preferredWriteType(characteristic: BluetoothGattCharacteristic): Int {
        val props = characteristic.properties
        val supportsWriteNoResp = props and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0
        return if (supportsWriteNoResp && props and BluetoothGattCharacteristic.PROPERTY_WRITE == 0) {
            BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
        } else {
            BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        }
    }

    @SuppressLint("MissingPermission")
    private fun startCharacteristicWrite(
        gatt: BluetoothGatt,
        characteristic: BluetoothGattCharacteristic,
        payload: ByteArray,
    ): Boolean = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        gatt.writeCharacteristic(characteristic, payload, characteristic.writeType) == BluetoothGatt.GATT_SUCCESS
    } else {
        @Suppress("DEPRECATION")
        characteristic.value = payload
        @Suppress("DEPRECATION")
        gatt.writeCharacteristic(characteristic)
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

    private fun isLikelyObdDeviceName(name: String?): Boolean {
        val normalized = name?.uppercase().orEmpty()
        return com.rheosoft.obdii.core.communication.ble.commonObdDeviceNames.any { 
            normalized.contains(it) 
        }
    }

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

    @SuppressLint("MissingPermission")
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
        if (bleDebugLogs) ObdLogger.log(message, LogCategory.Communication, "debug")
    }

    private fun logI(message: String) {
        if (bleDebugLogs) ObdLogger.log(message, LogCategory.Communication, "info")
    }

    private fun logE(message: String) {
        if (bleDebugLogs) ObdLogger.log(message, LogCategory.Communication, "error")
    }
}

package com.rheosoft.obdii.android.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.rheosoft.obdii.core.LogCategory
import com.rheosoft.obdii.core.ObdLogger
import com.rheosoft.obdii.core.communication.ble.BleCharacteristic
import com.rheosoft.obdii.core.communication.ble.BlePeripheral
import com.rheosoft.obdii.core.communication.ble.BlePlatformAdapter
import com.rheosoft.obdii.core.communication.ble.BleService
import com.rheosoft.obdii.core.protocols.CommunicationError
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import no.nordicsemi.android.ble.BleManager
import no.nordicsemi.android.ble.ktx.suspend
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

private class NordicGattManager(context: Context) : BleManager(context) {
    private var discoveredGattServices: List<BluetoothGattService> = emptyList()
    private val characteristicsMap = ConcurrentHashMap<String, BluetoothGattCharacteristic>()
    var onNotificationReceived: ((UUID, ByteArray) -> Unit)? = null

    @Deprecated("Deprecated in Java")
    override fun getGattCallback(): BleManagerGattCallback = object : BleManagerGattCallback() {
        @Deprecated("Deprecated in Java")
        override fun isRequiredServiceSupported(gatt: BluetoothGatt): Boolean {
            discoveredGattServices = gatt.services
            gatt.services.forEach { service ->
                service.characteristics.forEach { char ->
                    characteristicsMap[shortUuid(char.uuid)] = char
                }
            }
            return true
        }

        @Deprecated("Deprecated in Java")
        override fun onServicesInvalidated() {
            characteristicsMap.clear()
            discoveredGattServices = emptyList()
        }
    }

    fun getDiscoveredServicesList(): List<BleService> = 
        discoveredGattServices.map { BleService(shortUuid(it.uuid)) }

    fun getCharacteristicsForService(serviceUuid: String): List<BleCharacteristic> {
        val service = discoveredGattServices.firstOrNull { shortUuid(it.uuid) == serviceUuid.uppercase() }
            ?: return emptyList()
        return service.characteristics.map { ch ->
            BleCharacteristic(
                uuid = shortUuid(ch.uuid),
                canRead = (ch.properties and BluetoothGattCharacteristic.PROPERTY_READ) != 0,
                canWrite = (ch.properties and (BluetoothGattCharacteristic.PROPERTY_WRITE or 
                           BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE)) != 0,
                canNotify = (ch.properties and (BluetoothGattCharacteristic.PROPERTY_NOTIFY or 
                            BluetoothGattCharacteristic.PROPERTY_INDICATE)) != 0,
            )
        }
    }
    
    fun getGattCharacteristic(uuid: String): BluetoothGattCharacteristic? = characteristicsMap[shortUuid(uuid)]

    fun shortUuid(uuid: UUID): String = shortUuid(uuid.toString())
    
    fun shortUuid(raw: String): String {
        val lower = raw.lowercase()
        return if (lower.startsWith("0000") && lower.endsWith("-0000-1000-8000-00805f9b34fb")) {
            lower.substring(4, 8).uppercase()
        } else {
            raw.replace("-", "").uppercase()
        }
    }

    override fun log(priority: Int, message: String) {
        if (priority >= android.util.Log.INFO) {
            ObdLogger.log("Nordic: $message", LogCategory.Communication, "debug")
        }
    }

    // Public wrappers for protected methods
    fun publicEnableNotifications(char: BluetoothGattCharacteristic) = enableNotifications(char)
    fun publicWriteCharacteristic(char: BluetoothGattCharacteristic, data: ByteArray, type: Int) = writeCharacteristic(char, data, type)
    fun publicSetNotificationCallback(char: BluetoothGattCharacteristic) = setNotificationCallback(char)
}

class NordicBlePlatformAdapter(private val context: Context) : BlePlatformAdapter {
    private val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val adapter: BluetoothAdapter? = bluetoothManager.adapter
    private val managers = ConcurrentHashMap<String, NordicGattManager>()
    private val devices = ConcurrentHashMap<String, BluetoothDevice>()

    @SuppressLint("MissingPermission")
    override suspend fun scan(timeoutMs: Long, serviceUuids: Set<String>): List<BlePeripheral> = withContext(Dispatchers.Main) {
        val bt = adapter ?: throw CommunicationError("Bluetooth adapter unavailable")
        val scanner = bt.bluetoothLeScanner ?: throw CommunicationError("BLE scanner unavailable")
        
        suspendCancellableCoroutine { continuation ->
            val found = LinkedHashMap<String, BlePeripheral>()
            val mainHandler = Handler(Looper.getMainLooper())
            var completed = false

            val callback = object : ScanCallback() {
                override fun onScanResult(callbackType: Int, result: ScanResult) {
                    val device = result.device ?: return
                    val id = device.address ?: return
                    devices[id] = device
                    val peripheral = BlePeripheral(id = id, name = device.name, rssi = result.rssi)
                    found[id] = peripheral
                    
                    if (!completed && isLikelyObdDevice(device.name)) {
                        stop(this)
                        if (continuation.isActive) continuation.resume(found.values.toList())
                    }
                }

                override fun onScanFailed(errorCode: Int) {
                    stop(this)
                    if (continuation.isActive) continuation.resumeWithException(CommunicationError("Scan failed: $errorCode"))
                }

                private fun stop(cb: ScanCallback) {
                    completed = true
                    mainHandler.removeCallbacksAndMessages(null)
                    runCatching { scanner.stopScan(cb) }
                }
            }

            val timeout = Runnable {
                if (!completed) {
                    completed = true
                    runCatching { scanner.stopScan(callback) }
                    if (continuation.isActive) continuation.resume(found.values.toList())
                }
            }

            continuation.invokeOnCancellation {
                completed = true
                mainHandler.removeCallbacks(timeout)
                runCatching { scanner.stopScan(callback) }
            }

            scanner.startScan(null, ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(), callback)
            mainHandler.postDelayed(timeout, timeoutMs)
        }
    }

    @SuppressLint("MissingPermission")
    override suspend fun connect(peripheralId: String, timeoutMs: Long) {
        val device = devices[peripheralId] ?: adapter?.getRemoteDevice(peripheralId)
            ?: throw CommunicationError("Device not found: $peripheralId")
        
        val manager = NordicGattManager(context)
        managers[peripheralId] = manager
        
        manager.connect(device)
            .retry(3, 100)
            .useAutoConnect(false)
            .timeout(timeoutMs)
            .suspend()
    }

    override suspend fun disconnect(peripheralId: String) {
        managers.remove(peripheralId)?.disconnect()?.suspend()
    }

    override suspend fun discoverServices(peripheralId: String): List<BleService> {
        val manager = managers[peripheralId] ?: throw CommunicationError("Not connected")
        return manager.getDiscoveredServicesList()
    }

    override suspend fun discoverCharacteristics(peripheralId: String, serviceUuid: String): List<BleCharacteristic> {
        val manager = managers[peripheralId] ?: throw CommunicationError("Not connected")
        return manager.getCharacteristicsForService(serviceUuid)
    }

    override suspend fun enableNotifications(peripheralId: String, characteristicUuid: String) {
        val manager = managers[peripheralId] ?: throw CommunicationError("Not connected")
        val char = manager.getGattCharacteristic(characteristicUuid) ?: throw CommunicationError("Char not found")
        
        manager.publicSetNotificationCallback(char).with { _, data ->
            manager.onNotificationReceived?.invoke(char.uuid, data.value ?: ByteArray(0))
        }
        manager.publicEnableNotifications(char).suspend()
    }

    override suspend fun write(peripheralId: String, characteristicUuid: String, payload: ByteArray) {
        val manager = managers[peripheralId] ?: throw CommunicationError("Not connected")
        val char = manager.getGattCharacteristic(characteristicUuid) ?: throw CommunicationError("Char not found")
        
        manager.publicWriteCharacteristic(char, payload, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT).suspend()
    }

    override fun setNotificationListener(peripheralId: String, characteristicUuid: String, listener: (ByteArray) -> Unit) {
        val manager = managers[peripheralId] ?: return
        manager.onNotificationReceived = { uuid, data ->
            if (manager.shortUuid(uuid) == characteristicUuid.uppercase()) {
                listener(data)
            }
        }
    }

    private fun isLikelyObdDevice(name: String?): Boolean {
        val n = name?.uppercase() ?: return false
        return com.rheosoft.obdii.core.communication.ble.commonObdDeviceNames.any { 
            n.contains(it) 
        }
    }
}

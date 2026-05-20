package com.rheosoft.obdii.windows.ble

import com.rheosoft.obdii.core.LogCategory
import com.rheosoft.obdii.core.communication.ble.BleCharacteristic
import com.rheosoft.obdii.core.communication.ble.BlePeripheral
import com.rheosoft.obdii.core.communication.ble.BlePlatformAdapter
import com.rheosoft.obdii.core.communication.ble.BleScanPreferences
import com.rheosoft.obdii.core.communication.ble.BleService
import com.rheosoft.obdii.core.communication.ble.commonObdDeviceNames
import com.rheosoft.obdii.core.obdDebug
import com.rheosoft.obdii.core.protocols.CommunicationError
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import org.simplejavable.Adapter
import org.simplejavable.BluetoothUUID
import org.simplejavable.Peripheral
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

private const val ERR_NOT_CONNECTED = "BLE session not connected"
private const val SCAN_RESULTS_POLL_MS = 350L

/**
 * Windows desktop BLE transport via SimpleJavaBLE (WinRT backend).
 * Maps [BlePlatformAdapter] onto org.simplejavable APIs.
 */
class SimpleBlePlatformAdapter : BlePlatformAdapter {
    private val bleDispatcher = Dispatchers.IO
    private val timeoutExecutor = Executors.newSingleThreadScheduledExecutor { runnable ->
        Thread(runnable, "simpleble-timeout").apply { isDaemon = true }
    }

    private var adapter: Adapter? = null
    private val peripherals = ConcurrentHashMap<String, Peripheral>()
    private val connected = ConcurrentHashMap.newKeySet<String>()
    private val listeners = ConcurrentHashMap<String, (ByteArray) -> Unit>()
    private val notificationCallbacks = ConcurrentHashMap<String, Peripheral.DataCallback>()
    private val activeSubscriptions = ConcurrentHashMap<String, NotifySubscription>()

    private data class NotifySubscription(
        val peripheralId: String,
        val serviceUuid: BluetoothUUID,
        val characteristicUuid: BluetoothUUID,
    )

    @Suppress("UNUSED_PARAMETER")
    override suspend fun scan(timeoutMs: Long, serviceUuids: Set<String>): List<BlePeripheral> =
        withContext(bleDispatcher) {
            val bt = requireAdapter()
            if (!Adapter.isBluetoothEnabled()) {
                throw CommunicationError("Bluetooth is disabled")
            }

            val found = LinkedHashMap<String, BlePeripheral>()
            val scanStartedAt = System.currentTimeMillis()
            addPairedCandidates(bt, found)

            val timeout = timeoutMs.coerceAtLeast(1000)
            val completed = AtomicBoolean(false)
            obdDebug(
                "scan:start timeoutMs=$timeout pairedCandidates=${found.size} " +
                    formatPeripheralSummary(found.values),
                LogCategory.Bluetooth,
            )

            suspendCancellableCoroutine { continuation ->
                val timeoutTaskRef = arrayOf<java.util.concurrent.ScheduledFuture<*>?>(null)
                val pollTaskRef = arrayOf<java.util.concurrent.ScheduledFuture<*>?>(null)

                fun finishScan(reason: String) {
                    if (!completed.compareAndSet(false, true)) return
                    timeoutTaskRef[0]?.cancel(false)
                    pollTaskRef[0]?.cancel(false)
                    runCatching { bt.scanStop() }
                    obdDebug(
                        "scan:early-stop elapsedMs=${elapsedMs(scanStartedAt)} reason=$reason " +
                            formatPeripheralSummary(found.values),
                        LogCategory.Bluetooth,
                    )
                    if (continuation.isActive) {
                        continuation.resume(found.values.toList())
                    }
                }

                bt.setEventListener(object : Adapter.EventListener {
                    override fun onScanFound(peripheral: Peripheral) {
                        recordPeripheral(peripheral, found)
                        tryFinishScan(found, ::finishScan)
                    }
                })

                runCatching { bt.scanStart() }
                    .onFailure { error ->
                        obdDebug(
                            "scan:start-failed elapsedMs=${elapsedMs(scanStartedAt)} error=${error.message}",
                            LogCategory.Bluetooth,
                        )
                        if (continuation.isActive) {
                            continuation.resumeWithException(
                                CommunicationError("BLE scan start failed", error),
                            )
                        }
                        return@suspendCancellableCoroutine
                    }
                obdDebug("scan:active elapsedMs=${elapsedMs(scanStartedAt)}", LogCategory.Bluetooth)

                pollTaskRef[0] = timeoutExecutor.scheduleAtFixedRate({
                    if (completed.get()) return@scheduleAtFixedRate
                    mergeScanResults(bt, found, scanStartedAt)
                    tryFinishScan(found, ::finishScan)
                }, SCAN_RESULTS_POLL_MS, SCAN_RESULTS_POLL_MS, TimeUnit.MILLISECONDS)

                timeoutTaskRef[0] = timeoutExecutor.schedule({
                    if (!completed.compareAndSet(false, true)) return@schedule
                    pollTaskRef[0]?.cancel(false)
                    runCatching { bt.scanStop() }
                    mergeScanResults(bt, found, scanStartedAt)
                    obdDebug(
                        "scan:timeout elapsedMs=${elapsedMs(scanStartedAt)} total=${found.size} " +
                            formatPeripheralSummary(found.values),
                        LogCategory.Bluetooth,
                    )
                    if (continuation.isActive) {
                        continuation.resume(found.values.toList())
                    }
                }, timeout, TimeUnit.MILLISECONDS)

                continuation.invokeOnCancellation {
                    completed.set(true)
                    timeoutTaskRef[0]?.cancel(false)
                    pollTaskRef[0]?.cancel(false)
                    runCatching { bt.scanStop() }
                    obdDebug("scan:cancelled elapsedMs=${elapsedMs(scanStartedAt)}", LogCategory.Bluetooth)
                }
            }
        }

    override suspend fun connect(peripheralId: String, timeoutMs: Long) = withContext(bleDispatcher) {
        val peripheral = peripherals[peripheralId]
            ?: throw CommunicationError("Unknown BLE peripheral: $peripheralId")

        withTimeout(timeoutMs.coerceAtLeast(1000)) {
            peripheral.connectAsync().get()
        }
        connected.add(peripheralId)
        BleScanPreferences.preferredPeripheralId = peripheralId
        Unit
    }

    override suspend fun disconnect(peripheralId: String) = withContext(bleDispatcher) {
        tearDownPeripheral(peripheralId, disconnectTimeoutSec = 5)
    }

    override suspend fun discoverServices(peripheralId: String): List<BleService> =
        withContext(bleDispatcher) {
            val peripheral = requireConnected(peripheralId)
            peripheral.services().map { BleService(shortUuid(it.uuid())) }
        }

    override suspend fun discoverCharacteristics(
        peripheralId: String,
        serviceUuid: String,
    ): List<BleCharacteristic> = withContext(bleDispatcher) {
        val peripheral = requireConnected(peripheralId)
        val service = peripheral.services().firstOrNull { shortUuid(it.uuid()) == shortUuid(serviceUuid) }
            ?: return@withContext emptyList()
        service.characteristics().map { ch ->
            BleCharacteristic(
                uuid = shortUuid(ch.uuid()),
                canRead = ch.canRead(),
                canWrite = ch.canWriteRequest() || ch.canWriteCommand(),
                canNotify = ch.canNotify() || ch.canIndicate(),
            )
        }
    }

    override suspend fun enableNotifications(peripheralId: String, characteristicUuid: String) =
        withContext(bleDispatcher) {
            val peripheral = requireConnected(peripheralId)
            val location = findCharacteristic(peripheral, characteristicUuid)
            val callback = Peripheral.DataCallback { payload ->
                listeners[listenerKey(peripheralId, location.shortCharacteristicUuid)]?.invoke(payload)
            }
            val key = listenerKey(peripheralId, location.shortCharacteristicUuid)
            notificationCallbacks[key] = callback
            activeSubscriptions[key] = NotifySubscription(
                peripheralId = peripheralId,
                serviceUuid = location.serviceUuid,
                characteristicUuid = location.characteristicUuid,
            )
            val ch = location.characteristic
            // Prefer notify (Flutter setNotifyValue / CoreBluetooth notify path). WinRT often
            // reports both properties; indicate-first drops data on some ELM adapters (e.g. IOS-Vlink).
            when {
                ch.canNotify() -> {
                    obdDebug(
                        "ble:subscribe notify peripheral=$peripheralId char=${location.shortCharacteristicUuid}",
                        LogCategory.Bluetooth,
                    )
                    peripheral.notifyAsync(location.serviceUuid, location.characteristicUuid, callback)
                        .get(5, TimeUnit.SECONDS)
                }
                ch.canIndicate() -> {
                    obdDebug(
                        "ble:subscribe indicate peripheral=$peripheralId char=${location.shortCharacteristicUuid}",
                        LogCategory.Bluetooth,
                    )
                    peripheral.indicateAsync(location.serviceUuid, location.characteristicUuid, callback)
                        .get(5, TimeUnit.SECONDS)
                }
                else -> throw CommunicationError(
                    "BLE characteristic ${location.shortCharacteristicUuid} does not support notify",
                )
            }
            Unit
        }

    override suspend fun write(peripheralId: String, characteristicUuid: String, payload: ByteArray) =
        withContext(bleDispatcher) {
            val peripheral = requireConnected(peripheralId)
            val location = findCharacteristic(peripheral, characteristicUuid)
            val ch = location.characteristic
            when {
                ch.canWriteCommand() ->
                    peripheral.writeCommandAsync(location.serviceUuid, location.characteristicUuid, payload)
                        .get(10, TimeUnit.SECONDS)
                ch.canWriteRequest() ->
                    peripheral.writeRequestAsync(location.serviceUuid, location.characteristicUuid, payload)
                        .get(10, TimeUnit.SECONDS)
                else -> throw CommunicationError("BLE characteristic $characteristicUuid is not writable")
            }
            Unit
        }

    override fun setNotificationListener(
        peripheralId: String,
        characteristicUuid: String,
        listener: (ByteArray) -> Unit,
    ) {
        listeners[listenerKey(peripheralId, shortUuid(characteristicUuid))] = listener
    }

    private fun requireAdapter(): Adapter {
        adapter?.let { return it }
        val adapters = Adapter.getAdapters()
        if (adapters.isEmpty()) {
            throw CommunicationError("Bluetooth adapter unavailable")
        }
        val selected = adapters.first()
        adapter = selected
        return selected
    }

    private fun requireConnected(peripheralId: String): Peripheral {
        if (!connected.contains(peripheralId)) {
            throw CommunicationError(ERR_NOT_CONNECTED)
        }
        return peripherals[peripheralId] ?: throw CommunicationError(ERR_NOT_CONNECTED)
    }

    private fun addPairedCandidates(bt: Adapter, found: LinkedHashMap<String, BlePeripheral>) {
        runCatching {
            val paired = bt.getPairedPeripherals()
            obdDebug("scan:paired total=${paired.size}", LogCategory.Bluetooth)
            paired.forEach { peripheral ->
                val name = peripheralAdvertisedName(peripheral)
                val likelyObd = isLikelyObdDeviceName(name)
                obdDebug(
                    "scan:paired-device name=$name likelyObd=$likelyObd",
                    LogCategory.Bluetooth,
                )
                if (!likelyObd) return@forEach
                recordPeripheral(peripheral, found)
            }
        }.onFailure { error ->
            obdDebug("scan:paired-failed error=${error.message}", LogCategory.Bluetooth)
        }
    }

    private fun elapsedMs(startedAt: Long): Long = System.currentTimeMillis() - startedAt

    private fun formatPeripheralSummary(peripherals: Collection<BlePeripheral>): String =
        peripherals.joinToString(prefix = "[", postfix = "]") { p ->
            "${p.name ?: "?"}:${p.id}:rssi=${p.rssi}"
        }

    private fun recordPeripheral(peripheral: Peripheral, found: LinkedHashMap<String, BlePeripheral>) {
        val id = peripheralId(peripheral)
        peripherals[id] = peripheral
        val previous = found[id]
        val advertisedName = peripheralAdvertisedName(peripheral)
        found[id] = BlePeripheral(
            id = id,
            name = advertisedName ?: previous?.name,
            rssi = peripheral.rssi,
        )
    }

    private fun peripheralAdvertisedName(peripheral: Peripheral): String? =
        peripheral.getIdentifier().takeIf { it.isNotBlank() }

    /** WinRT fills GAP names in [Adapter.scanGetResults], not always in [Adapter.EventListener.onScanFound]. */
    private fun mergeScanResults(
        bt: Adapter,
        found: LinkedHashMap<String, BlePeripheral>,
        scanStartedAt: Long,
    ) {
        val results = runCatching { bt.scanGetResults() }.getOrElse { emptyList() }
        results.forEach { peripheral ->
            val id = peripheralId(peripheral)
            val previousName = found[id]?.name
            recordPeripheral(peripheral, found)
            val resolvedName = found[id]?.name
            if (previousName.isNullOrBlank() && !resolvedName.isNullOrBlank()) {
                obdDebug(
                    "scan:results-name elapsedMs=${elapsedMs(scanStartedAt)} " +
                        "id=$id name=$resolvedName",
                    LogCategory.Bluetooth,
                )
            }
        }
    }

    private fun tryFinishScan(
        found: LinkedHashMap<String, BlePeripheral>,
        onEarlyStop: (String) -> Unit,
    ) {
        val knownId = BleScanPreferences.preferredPeripheralId
        if (knownId != null && found.containsKey(knownId)) {
            onEarlyStop("known-mac:$knownId")
            return
        }
        val obdCandidate = found.values.firstOrNull { isLikelyObdDeviceName(it.name) }
        if (obdCandidate != null) {
            onEarlyStop("obd-name:${obdCandidate.name}")
        }
    }

    private fun peripheralId(peripheral: Peripheral): String =
        peripheral.address.toString().ifBlank { peripheral.getIdentifier() }

    private data class CharacteristicLocation(
        val serviceUuid: BluetoothUUID,
        val characteristicUuid: BluetoothUUID,
        val shortCharacteristicUuid: String,
        val characteristic: org.simplejavable.Characteristic,
    )

    private fun findCharacteristic(peripheral: Peripheral, characteristicUuid: String): CharacteristicLocation {
        val target = shortUuid(characteristicUuid)
        for (service in peripheral.services()) {
            for (ch in service.characteristics()) {
                if (shortUuid(ch.uuid()) == target) {
                    val shortChar = shortUuid(ch.uuid())
                    return CharacteristicLocation(
                        serviceUuid = BluetoothUUID(service.uuid()),
                        characteristicUuid = BluetoothUUID(ch.uuid()),
                        shortCharacteristicUuid = shortChar,
                        characteristic = ch,
                    )
                }
            }
        }
        throw CommunicationError("BLE characteristic $characteristicUuid not found")
    }

    private fun listenerKey(peripheralId: String, characteristicUuid: String): String =
        "$peripheralId|${shortUuid(characteristicUuid)}"

    private fun isLikelyObdDeviceName(name: String?): Boolean {
        val normalized = name?.uppercase().orEmpty()
        return commonObdDeviceNames.any { normalized.contains(it) }
    }

    fun shutdown() {
        runCatching {
            val bt = adapter
            if (bt != null && bt.scanIsActive) {
                bt.scanStop()
            }
        }
        runBlocking(bleDispatcher) {
            connected.toList().forEach { id ->
                runCatching { tearDownPeripheral(id, disconnectTimeoutSec = 2) }
            }
        }
        connected.clear()
        peripherals.clear()
        listeners.clear()
        notificationCallbacks.clear()
        activeSubscriptions.clear()
        adapter = null
        timeoutExecutor.shutdownNow()
    }

    /** Unsubscribe notify/indicate, then disconnect. WinRT keeps native callbacks until unsubscribe. */
    private fun tearDownPeripheral(peripheralId: String, disconnectTimeoutSec: Long) {
        val peripheral = peripherals[peripheralId] ?: return
        val keys = activeSubscriptions.entries
            .filter { it.value.peripheralId == peripheralId }
            .map { it.key }
        keys.forEach { key ->
            val sub = activeSubscriptions.remove(key) ?: return@forEach
            listeners.remove(key)
            notificationCallbacks.remove(key)
            runCatching {
                peripheral.unsubscribeAsync(sub.serviceUuid, sub.characteristicUuid)
                    .get(disconnectTimeoutSec.coerceAtMost(3), TimeUnit.SECONDS)
            }
        }
        if (peripheral.isConnected) {
            runCatching {
                peripheral.disconnectAsync().get(disconnectTimeoutSec, TimeUnit.SECONDS)
            }
        }
        connected.remove(peripheralId)
    }

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
}

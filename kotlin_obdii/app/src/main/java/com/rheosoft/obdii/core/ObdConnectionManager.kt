package com.rheosoft.obdii.core

import com.rheosoft.obdii.core.communication.ble.BlePlatformAdapter
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * Swift-parity app facade.
 *
 * Owns app-level connection state, interest-driven polling, and decoded app
 * projections while transport/decode primitives live in kotlinobd2.
 */
object OBDConnectionManager : PidStatsProviding, DiagnosticsProviding, FuelStatusProviding, MilStatusProviding, OBDConnectionControlling {
    private val managerScope = CoroutineScope(Dispatchers.Default + Job())
    private val querySupportedPids = true

    private var service = ObdService(ConfigData.connectionType.toLibraryConnectionType(), ConfigData.wifiHost, ConfigData.wifiPort)
    private var serviceMirrorJob: Job? = null
    private var streamJob: Job? = null
    private var bleAdapter: BlePlatformAdapter? = null
    private var supportedMode1Pids: Set<String> = emptySet()
    private var lastStreamingPids: Set<String> = emptySet()
    private var interestedPids: Set<String> = emptySet()

    private val _connectionStateStream = MutableStateFlow(OBDConnectionState.disconnected)
    private val _pidStatsStream = MutableStateFlow<Map<String, PIDStats>>(emptyMap())
    private val _diagnosticsStream = MutableStateFlow<List<TroubleCodeMetadata>?>(null)
    private val _fuelStatusStream = MutableStateFlow<List<StatusCodeMetadata?>?>(null)
    private val _milStatusStream = MutableStateFlow<Status?>(null)

    private var _connectionState = OBDConnectionState.disconnected
        set(value) {
            if (field == value) return
            field = value
            _connectionStateStream.value = value
        }
    private var _troubleCodes: List<TroubleCodeMetadata>? = null
        set(value) {
            field = value
            _diagnosticsStream.value = value
        }
    private var _fuelStatus: List<StatusCodeMetadata?>? = null
        set(value) {
            field = value
            _fuelStatusStream.value = value
        }
    private var _milStatus: Status? = null
        set(value) {
            field = value
            _milStatusStream.value = value
        }
    private var _connectedPeripheralName: String? = null
    private var _pidStats: Map<String, PIDStats> = emptyMap()
        set(value) {
            field = value
            _pidStatsStream.value = value
        }

    init {
        bindServiceMirrors()
        bindConnectionSettings()
        bindInterestRegistry()
        bindUnitChanges()
    }
    override val connectionState: OBDConnectionState
        get() = _connectionState
    override val troubleCodes: List<TroubleCodeMetadata>?
        get() = _troubleCodes
    override val fuelStatus: List<StatusCodeMetadata?>?
        get() = _fuelStatus
    override val milStatus: Status?
        get() = _milStatus
    val connectedPeripheralName: String?
        get() = _connectedPeripheralName
    override val pidStats: Map<String, PIDStats>
        get() = _pidStats

    override val connectionStateStream: StateFlow<OBDConnectionState>
        get() = _connectionStateStream.asStateFlow()
    override val pidStatsStream: StateFlow<Map<String, PIDStats>>
        get() = _pidStatsStream.asStateFlow()
    override val diagnosticsStream: StateFlow<List<TroubleCodeMetadata>?>
        get() = _diagnosticsStream.asStateFlow()
    override val fuelStatusStream: StateFlow<List<StatusCodeMetadata?>?>
        get() = _fuelStatusStream.asStateFlow()
    override val milStatusStream: StateFlow<Status?>
        get() = _milStatusStream.asStateFlow()

    fun initialize() {
        syncTransportConfig()
        syncInterestedPids()
        bindServiceMirrors()
    }

    fun setBleAdapter(adapter: BlePlatformAdapter) {
        bleAdapter = adapter
        service.setBleAdapter(adapter)
    }

    override suspend fun connect() {
        if (_connectionState == OBDConnectionState.connected || _connectionState == OBDConnectionState.connecting) return
        _connectionState = OBDConnectionState.connecting

        try {
            service.startConnection(timeoutMs = 30_000)
            supportedMode1Pids = if (querySupportedPids) querySupportedMode1Pids() else emptySet()
            _connectionState = OBDConnectionState.connected
            _connectedPeripheralName = service.connectedPeripheral?.name
            syncInterestedPids()
            startContinuousUpdates(interestedPids)
        } catch (t: Throwable) {
            streamJob?.cancel()
            streamJob = null
            _connectedPeripheralName = null
            _connectionState = OBDConnectionState.failed
            throw t
        }
    }

    override fun disconnect() {
        streamJob?.cancel()
        streamJob = null
        service.stopConnection()
        clearForTerminalState()
        _connectionState = OBDConnectionState.disconnected
    }

    override fun updateConnectionDetails() {
        if (_connectionState != OBDConnectionState.disconnected) {
            disconnect()
        }
        recreateService()
    }

    override fun statsFor(pidCommand: String): PIDStats? = _pidStats[normalizeCommandId(pidCommand)]

    fun resetForTests() {
        disconnect()
        interestedPids = emptySet()
        supportedMode1Pids = emptySet()
        lastStreamingPids = emptySet()
    }

    private fun bindInterestRegistry() {
        managerScope.launch {
            PidInterestRegistry.instance.interestedStream.collectLatest { interested ->
                val normalized = normalizeInterest(interested)
                if (normalized == interestedPids) return@collectLatest
                interestedPids = normalized
                if (_connectionState == OBDConnectionState.connected) {
                    restartContinuousUpdates(interestedPids)
                } else {
                    streamJob?.cancel()
                    streamJob = null
                    lastStreamingPids = emptySet()
                }
            }
        }
    }

    private fun syncInterestedPids() {
        interestedPids = normalizeInterest(PidInterestRegistry.instance.interested)
    }

    private fun normalizeInterest(interested: Set<String>): Set<String> =
        interested.map(::normalizeCommandId).filter { it.isNotEmpty() }.toSet()

    private fun bindUnitChanges() {
        managerScope.launch {
            ConfigData.unitsStream.collectLatest {
                resetAllStats()
                if (_connectionState == OBDConnectionState.connected) {
                    lastStreamingPids = emptySet()
                    restartContinuousUpdates(interestedPids)
                }
            }
        }
    }

    private fun bindConnectionSettings() {
        managerScope.launch {
            ConfigData.connectionTypeStream.collectLatest {
                syncTransportConfig()
            }
        }
    }

    private fun syncTransportConfig() {
        service.switchConnectionType(ConfigData.connectionType.toLibraryConnectionType(), ConfigData.wifiHost, ConfigData.wifiPort)
        bleAdapter?.let(service::setBleAdapter)
        bindServiceMirrors()
    }

    private fun ConnectionType.toLibraryConnectionType(): LibraryConnectionType = when (this) {
        ConnectionType.bluetooth -> LibraryConnectionType.bluetooth
        ConnectionType.wifi -> LibraryConnectionType.wifi
        ConnectionType.demo -> LibraryConnectionType.demo
    }

    private fun recreateService() {
        service = ObdService(ConfigData.connectionType.toLibraryConnectionType(), ConfigData.wifiHost, ConfigData.wifiPort)
        bleAdapter?.let(service::setBleAdapter)
        bindServiceMirrors()
    }

    private fun bindServiceMirrors() {
        serviceMirrorJob?.cancel()
        serviceMirrorJob = managerScope.launch {
            service.connectionState.collectLatest { handleServiceConnectionState(it) }
        }
    }

    private fun handleServiceConnectionState(state: AdapterConnectionState) {
        when (state) {
            AdapterConnectionState.disconnected -> {
                clearForTerminalState()
                _connectionState = OBDConnectionState.disconnected
            }
            AdapterConnectionState.error -> {
                clearForTerminalState()
                _connectionState = OBDConnectionState.failed
            }
            AdapterConnectionState.connecting -> _connectionState = OBDConnectionState.connecting
            AdapterConnectionState.connectedToAdapter,
            AdapterConnectionState.connectedToVehicle,
            -> _connectionState = OBDConnectionState.connected
        }
        _connectedPeripheralName = service.connectedPeripheral?.name
    }

    private fun clearForTerminalState() {
        streamJob?.cancel()
        streamJob = null
        lastStreamingPids = emptySet()
        _pidStats = emptyMap()
        _troubleCodes = null
        _fuelStatus = null
        _milStatus = null
        _connectedPeripheralName = null
    }

    private fun resetAllStats() {
        _pidStats = _pidStats.mapValues { (_, existing) ->
            existing.copy(
                min = existing.latest.value,
                max = existing.latest.value,
                sampleCount = 1,
            )
        }
    }

    private fun startContinuousUpdates(pids: Set<String>) {
        startContinuousUpdatesInternal(pids)
    }

    private fun restartContinuousUpdates(pids: Set<String>) {
        streamJob?.cancel()
        streamJob = null
        lastStreamingPids = emptySet()
        startContinuousUpdatesInternal(pids)
    }

    private fun startContinuousUpdatesInternal(pids: Set<String>) {
        val enabledNow = filterSupportedPids(pids)
        if (enabledNow.isEmpty()) {
            streamJob?.cancel()
            streamJob = null
            lastStreamingPids = emptySet()
            return
        }
        if (enabledNow == lastStreamingPids) return

        streamJob?.cancel()
        lastStreamingPids = enabledNow
        streamJob = managerScope.launch {
            val statsAccumulator = _pidStats.toMutableMap()
            while (isActive && _connectionState == OBDConnectionState.connected) {
                for (pid in enabledNow) {
                    val lines = runCatching { service.sendCommand(pid) }.getOrNull() ?: continue
                    handlePidResponse(pid, lines, statsAccumulator)
                }
                delay(1_000)
            }
        }
    }

    private fun filterSupportedPids(pids: Set<String>): Set<String> {
        if (!querySupportedPids) return pids
        return pids.filterTo(mutableSetOf()) { command ->
            !command.startsWith("01") || supportedMode1Pids.contains(command)
        }
    }

    private suspend fun querySupportedMode1Pids(): Set<String> {
        val supported = mutableSetOf<String>()
        val getterCommands = CommandCatalog.pidGetterCommands
            .map(::normalizeCommandId)
            .filter { it.startsWith("01") && it.length == 4 }
            .sorted()

        for (command in getterCommands) {
            val bytes = runCatching { responseBytes(service.sendCommand(command)) }.getOrNull() ?: continue
            val serviceIndex = bytes.indexOf(0x41)
            if (serviceIndex < 0 || bytes.getOrNull(serviceIndex + 1) != command.takeLast(2).toInt(16)) continue
            val bitmap = bytes.drop(serviceIndex + 2).take(4)
            if (bitmap.size < 4) continue

            val base = command.takeLast(2).toInt(16)
            bitmap.forEachIndexed { byteIndex, value ->
                for (bitIndex in 0 until 8) {
                    if (value and (1 shl (7 - bitIndex)) != 0) {
                        supported += "01%02X".format(base + byteIndex * 8 + bitIndex + 1)
                    }
                }
            }
        }
        return supported
    }

    private fun handlePidResponse(
        pid: String,
        lines: List<String>,
        statsAccumulator: MutableMap<String, PIDStats>,
    ) {
        val bytes = responseBytes(lines)
        if (bytes.isEmpty()) return

        when (val result = decode(pid, bytes)) {
            is DecodeResult.Measurement -> {
                val existing = statsAccumulator[pid]
                statsAccumulator[pid] = existing?.copyWith(result.value) ?: PIDStats(pid, result.value)
                _pidStats = statsAccumulator.toMap()
            }
            is DecodeResult.StatusResult -> _milStatus = result.value
            is DecodeResult.TroubleCodes -> _troubleCodes = result.codes
            is DecodeResult.FuelStatusResult -> _fuelStatus = result.status
            is DecodeResult.Failure -> Unit
        }
    }

    private fun decode(commandId: String, bytes: List<Int>): DecodeResult {
        val command = when {
            commandId == "03" -> OBDCommand.Mode3()
            commandId.startsWith("01") && commandId.length >= 4 -> OBDCommand.Mode1(commandId.takeLast(2))
            else -> return DecodeResult.Failure("Unsupported command: $commandId")
        }
        return command.properties.decode(bytes, ConfigData.units)
    }

    private fun normalizeCommandId(command: String): String =
        CommandCatalog.resolveCommandId(command).trim().uppercase()

    private fun responseBytes(lines: List<String>): List<Int> {
        val frames = Parser.parseFrames(lines)
        if (frames.isEmpty()) return emptyList()

        val firstFrame = frames.firstOrNull { it.type == FrameType.FirstFrame }
        if (firstFrame != null) {
            return Parser.parseMessages(frames).firstOrNull()?.data ?: emptyList()
        }

        val singleFrame = frames.firstOrNull { it.type == FrameType.SingleFrame } ?: return emptyList()
        val hasCanHeader = singleFrame.raw.substringBefore(' ').length == 3
        return if (hasCanHeader) singleFrame.data.drop(1) else singleFrame.data
    }
}

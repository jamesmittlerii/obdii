package com.rheosoft.obdii.core

import com.rheosoft.obdii.core.communication.ble.BlePlatformAdapter
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
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
    private val managerJob = SupervisorJob()
    private val managerScope = CoroutineScope(Dispatchers.Default + managerJob)
    private val querySupportedPids = true
    private const val PID_INTER_COMMAND_SETTLE_MS = 50L
    private const val MAX_CONSECUTIVE_STREAM_FAILURES = 3
    private const val STREAM_RECONNECT_DELAY_MS = 2_000L

    private var service = ObdService(ConfigData.connectionType.toLibraryConnectionType(), ConfigData.wifiHost, ConfigData.wifiPort)
    private var serviceMirrorJob: Job? = null
    private var streamJob: Job? = null
    private var connectionJob: Job? = null
    private var bleAdapter: BlePlatformAdapter? = null
    private var supportedMode1Pids: Set<String> = emptySet()
    private var lastStreamingPids: Set<String> = emptySet()
    private var interestedPids: Set<String> = emptySet()

    private val _connectionStateStream = MutableStateFlow(OBDConnectionState.disconnected)
    private val _pidStatsStream = MutableStateFlow<Map<String, PIDStats>>(emptyMap())
    private val _diagnosticsStream = MutableStateFlow<List<TroubleCodeMetadata>?>(null)
    private val _fuelStatusStream = MutableStateFlow<List<StatusCodeMetadata?>?>(null)
    private val _milStatusStream = MutableStateFlow<Status?>(null)

    private var isInitialized = false

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
        if (isInitialized) return
        isInitialized = true
        syncTransportConfigInternal()
        syncInterestedPids()
    }

    fun setBleAdapter(adapter: BlePlatformAdapter) {
        bleAdapter = adapter
        service.setBleAdapter(adapter)
    }

    override suspend fun connect() {
        if (_connectionState == OBDConnectionState.connected || _connectionState == OBDConnectionState.connecting) {
            obdWarning("Connection attempt ignored, already connected or connecting.", LogCategory.Service)
            return
        }

        connectionJob?.cancelAndJoin()
        connectionJob = currentCoroutineContext()[Job]

        syncTransportConfigInternal()
        _connectionState = OBDConnectionState.connecting
        obdInfo("Starting connection with timeout: 30s", LogCategory.Connection)

        try {
            obdDebug("Connecting to adapter...", LogCategory.Connection)
            service.startConnection(timeoutMs = 30_000)

            _connectionState = OBDConnectionState.settingUpVehicle
            obdDebug("Initializing vehicle connection...", LogCategory.Connection)

            if (service.currentConnectionType.value == LibraryConnectionType.bluetooth) {
                // Flutter: 1s after ATSP0 before first 0100; ELM may still be finishing protocol search.
                delay(1_000)
            }
            supportedMode1Pids = if (querySupportedPids) querySupportedMode1Pids() else emptySet()
            _connectionState = OBDConnectionState.connected
            _connectedPeripheralName = service.connectedPeripheral?.name
            syncInterestedPids()
            startContinuousUpdates(interestedPids)
            obdInfo("Successfully connected to vehicle: ${service.connectedPeripheral?.name ?: "Unknown"}", LogCategory.Connection)
        } catch (t: Throwable) {
            if (t is CancellationException) {
                obdDebug("Connection attempt cancelled.", LogCategory.Connection)
                throw t
            }
            streamJob?.cancel()
            streamJob = null
            _connectedPeripheralName = null
            _connectionState = OBDConnectionState.failed
            obdError("Connection failed: ${t.message}", LogCategory.Connection)
            throw t
        } finally {
            if (connectionJob === currentCoroutineContext()[Job]) {
                connectionJob = null
            }
        }
    }

    override fun disconnect() {
        connectionJob?.cancel()
        connectionJob = null
        val activeStream = streamJob
        streamJob = null
        activeStream?.cancel()
        runCatching {
            runBlocking {
                withTimeout(2_000) {
                    activeStream?.cancelAndJoin()
                }
            }
        }
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
        isInitialized = false
        interestedPids = emptySet()
        supportedMode1Pids = emptySet()
        lastStreamingPids = emptySet()
        recreateService()
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
                obdInfo("Units changed to ${ConfigData.units.name}; resetting stats and restarting updates.", LogCategory.Service)
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
                syncTransportConfigInternal()
            }
        }
    }

    private fun syncTransportConfigInternal() {
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
        val oldState = _connectionState
        when (state) {
            AdapterConnectionState.disconnected -> {
                if (_connectionState == OBDConnectionState.connecting) return
                clearForTerminalState()
                _connectionState = OBDConnectionState.disconnected
            }
            AdapterConnectionState.error -> {
                clearForTerminalState()
                _connectionState = OBDConnectionState.failed
            }
            AdapterConnectionState.connecting -> {
                _connectionState = OBDConnectionState.connecting
            }
            AdapterConnectionState.connectedToAdapter -> {
                if (_connectionState == OBDConnectionState.connecting) {
                    _connectionState = OBDConnectionState.connectedToAdapter
                }
            }
            AdapterConnectionState.connectedToVehicle -> {
                if (_connectionState != OBDConnectionState.connected) {
                    _connectionState = OBDConnectionState.connected
                }
            }
        }
        if (oldState != _connectionState) {
            obdInfo("Connection state changed: $oldState -> $_connectionState", LogCategory.Connection)
        }
        _connectedPeripheralName = service.connectedPeripheral?.name
    }

    fun setSettingUpVehicle() {
        if (_connectionState == OBDConnectionState.connectedToAdapter) {
            _connectionState = OBDConnectionState.settingUpVehicle
        }
    }

    private fun clearForTerminalState() {
        streamJob?.cancel()
        streamJob = null
        supportedMode1Pids = emptySet()
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
            obdInfo("No interested PIDs to monitor.", LogCategory.Service)
            return
        }
        if (enabledNow == lastStreamingPids) return

        streamJob?.cancel()
        lastStreamingPids = enabledNow
        obdInfo("Starting continuous updates for ${enabledNow.size} PIDs.", LogCategory.Service)
        streamJob = managerScope.launch {
            val statsAccumulator = _pidStats.toMutableMap()
            var cycleDelayMs = 1_000L
            var consecutiveFailures = 0
            while (isActive && _connectionState == OBDConnectionState.connected) {
                var hadFailure = false
                for (pid in enabledNow) {
                    val lines = runCatching { service.sendCommand(pid) }.getOrNull()
                    if (lines == null) {
                        hadFailure = true
                        consecutiveFailures++
                        if (consecutiveFailures >= MAX_CONSECUTIVE_STREAM_FAILURES) {
                            handleContinuousUpdateFailure(consecutiveFailures)
                            return@launch
                        }
                        delay(PID_INTER_COMMAND_SETTLE_MS)
                        continue
                    }
                    consecutiveFailures = 0
                    handlePidResponse(pid, lines, statsAccumulator)
                    delay(PID_INTER_COMMAND_SETTLE_MS)
                }
                cycleDelayMs = if (hadFailure) {
                    minOf(4_000L, (cycleDelayMs * 1.5).toLong())
                } else {
                    maxOf(1_000L, (cycleDelayMs * 0.9).toLong())
                }
                delay(cycleDelayMs)
            }
        }
    }

    private fun handleContinuousUpdateFailure(consecutiveFailures: Int) {
        obdError(
            "Stopping continuous updates after $consecutiveFailures consecutive PID timeouts.",
            LogCategory.Service,
        )
        service.stopConnection()
        clearForTerminalState()
        _connectionState = OBDConnectionState.failed
        if (!ConfigData.autoConnectToOBD) return

        managerScope.launch {
            delay(STREAM_RECONNECT_DELAY_MS)
            if (_connectionState != OBDConnectionState.failed) return@launch
            runCatching {
                obdInfo("Attempting reconnect after BLE polling failure.", LogCategory.Connection)
                connect()
            }.onFailure { error ->
                obdError(
                    "Reconnect after BLE polling failure failed: ${error.message}",
                    LogCategory.Connection,
                )
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
            obdInfo("Getting supported PIDs for $command", LogCategory.Communication)
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
            is DecodeResult.StatusResult -> {
                _milStatus = result.value
                obdDebug("Status response: ${result.value}", LogCategory.Communication)
            }
            is DecodeResult.TroubleCodes -> {
                _troubleCodes = result.codes
                obdInfo("Found ${result.codes.size} trouble codes", LogCategory.Communication)
            }
            is DecodeResult.FuelStatusResult -> {
                _fuelStatus = result.status
                obdDebug("Fuel status updated", LogCategory.Communication)
            }
            is DecodeResult.Failure -> {
                obdError("Failed to decode command $pid: ${result.message} | Data: ${bytes.joinToString(" ") { "%02X".format(it) }}", LogCategory.Parsing)
            }
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

        return Parser.parseMessages(frames).firstOrNull()?.data ?: emptyList()
    }
}

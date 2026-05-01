package com.rheosoft.obdii.core

import com.rheosoft.obdii.core.communication.ble.BlePlatformAdapter
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

/**
 * Swift-parity app facade.
 *
 * The app references OBDConnectionManager while transport/decode logic lives in
 * the externalized library singleton (ObdConnectionLibrary).
 */
object OBDConnectionManager : PidStatsProviding, DiagnosticsProviding, FuelStatusProviding, MilStatusProviding, OBDConnectionControlling {
    private val managerScope = CoroutineScope(Dispatchers.Default + Job())

    init {
        bindConnectionSettings()
        bindInterestRegistry()
        bindUnitChanges()
    }
    override val connectionState: OBDConnectionState
        get() = ObdConnectionLibrary.connectionState
    override val troubleCodes: List<TroubleCodeMetadata>?
        get() = ObdConnectionLibrary.troubleCodes
    override val fuelStatus: List<StatusCodeMetadata?>?
        get() = ObdConnectionLibrary.fuelStatus
    override val milStatus: Status?
        get() = ObdConnectionLibrary.milStatus
    val connectedPeripheralName: String?
        get() = ObdConnectionLibrary.connectedPeripheralName
    override val pidStats: Map<String, PIDStats>
        get() = ObdConnectionLibrary.pidStats

    override val connectionStateStream: StateFlow<OBDConnectionState>
        get() = ObdConnectionLibrary.connectionStateStream
    override val pidStatsStream: StateFlow<Map<String, PIDStats>>
        get() = ObdConnectionLibrary.pidStatsStream
    override val diagnosticsStream: StateFlow<List<TroubleCodeMetadata>?>
        get() = ObdConnectionLibrary.diagnosticsStream
    override val fuelStatusStream: StateFlow<List<StatusCodeMetadata?>?>
        get() = ObdConnectionLibrary.fuelStatusStream
    override val milStatusStream: StateFlow<Status?>
        get() = ObdConnectionLibrary.milStatusStream

    fun initialize() {
        ObdConnectionLibrary.initialize()
        syncTransportConfig()
    }

    fun setBleAdapter(adapter: BlePlatformAdapter) = ObdConnectionLibrary.setBleAdapter(adapter)

    override suspend fun connect() {
        syncTransportConfig()
        ObdConnectionLibrary.connect()
    }

    override fun disconnect() = ObdConnectionLibrary.disconnect()

    override fun updateConnectionDetails() {
        syncTransportConfig()
        ObdConnectionLibrary.updateConnectionDetails()
    }

    override fun statsFor(pidCommand: String): PIDStats? = ObdConnectionLibrary.statsFor(pidCommand)

    fun resetForTests() = ObdConnectionLibrary.resetForTests()

    private fun bindInterestRegistry() {
        managerScope.launch {
            PidInterestRegistry.instance.interestedStream.collectLatest { interested ->
                ObdConnectionLibrary.setInterestedPids(interested)
            }
        }
    }

    private fun bindUnitChanges() {
        managerScope.launch {
            ConfigData.unitsStream.collectLatest {
                ObdConnectionLibrary.onUnitsChanged()
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
        ObdConnectionLibrary.configureTransport(
            type = ConfigData.connectionType.toLibraryConnectionType(),
            host = ConfigData.wifiHost,
            port = ConfigData.wifiPort,
        )
    }

    private fun ConnectionType.toLibraryConnectionType(): LibraryConnectionType = when (this) {
        ConnectionType.bluetooth -> LibraryConnectionType.bluetooth
        ConnectionType.wifi -> LibraryConnectionType.wifi
        ConnectionType.demo -> LibraryConnectionType.demo
    }
}

package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.ConfigData
import com.rheosoft.obdii.core.ConnectionType
import com.rheosoft.obdii.core.MeasurementUnit
import com.rheosoft.obdii.core.OBDConnectionControlling
import com.rheosoft.obdii.core.OBDConnectionManager
import com.rheosoft.obdii.core.OBDConnectionState
import com.rheosoft.obdii.core.SettingsConfigProviding
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

data class SettingsUiState(
    val wifiHost: String,
    val wifiPort: Int,
    val autoConnectToOBD: Boolean,
    val connectionType: ConnectionType,
    val units: MeasurementUnit,
    val connectionState: OBDConnectionState,
    val appVersion: String = "",
)

class SettingsViewModel(
    private val config: SettingsConfigProviding = ConfigData,
    private val connection: OBDConnectionControlling = OBDConnectionManager,
) : BaseViewModel() {
    private val scope = CoroutineScope(Dispatchers.Default + Job())
    private var hostDebounceVersion = 0L
    private var portDebounceVersion = 0L

    var wifiHost: String = config.wifiHost
        private set
    var wifiPort: Int = config.wifiPort
        private set
    var autoConnectToOBD: Boolean = config.autoConnectToOBD
        private set
    var connectionType: ConnectionType = config.connectionType
        private set
    var units: MeasurementUnit = config.units
        private set
    var connectionState: OBDConnectionState = connection.connectionState
        private set
    private var _appVersion: String = ""
    private val _uiStateStream = MutableStateFlow(buildUiState())
    val uiStateStream: StateFlow<SettingsUiState> = _uiStateStream.asStateFlow()

    init {
        scope.launch {
            connection.connectionStateStream.collectLatest {
                connectionState = it
                emitUiState()
                notifyChanged()
            }
        }
        scope.launch {
            config.unitsStream.collectLatest {
                units = it
                emitUiState()
                notifyChanged()
            }
        }
        scope.launch {
            config.connectionTypeStream.collectLatest {
                connectionType = it
                emitUiState()
                notifyChanged()
            }
        }
    }

    fun onWifiHostChanged(newHost: String) {
        wifiHost = newHost
        emitUiState()
        notifyChanged()
        val local = ++hostDebounceVersion
        scope.launch {
            delay(500)
            if (local != hostDebounceVersion) return@launch
            config.wifiHost = wifiHost
            if (connectionType == ConnectionType.wifi) connection.updateConnectionDetails()
        }
    }

    fun onWifiPortChanged(newPort: Int) {
        wifiPort = newPort
        emitUiState()
        notifyChanged()
        val local = ++portDebounceVersion
        scope.launch {
            delay(500)
            if (local != portDebounceVersion) return@launch
            config.wifiPort = wifiPort
            if (connectionType == ConnectionType.wifi) connection.updateConnectionDetails()
        }
    }

    fun onConnectionTypeChanged(newType: ConnectionType) {
        if (newType == connectionType) return
        connectionType = newType
        config.connectionType = newType
        connection.updateConnectionDetails()
        emitUiState()
        notifyChanged()
    }

    fun onUnitsChanged(newUnits: MeasurementUnit) {
        if (newUnits == units) return
        units = newUnits
        config.setUnits(newUnits)
        emitUiState()
        notifyChanged()
    }

    fun onAutoConnectChanged(value: Boolean) {
        autoConnectToOBD = value
        config.autoConnectToOBD = value
        emitUiState()
        notifyChanged()
    }

    val isConnectButtonDisabled: Boolean
        get() = connectionState == OBDConnectionState.connecting

    fun handleConnectionButtonTap() {
        when (connectionState) {
            OBDConnectionState.disconnected, OBDConnectionState.failed -> scope.launch {
                runCatching { connection.connect() }
            }
            OBDConnectionState.connected -> connection.disconnect()
            OBDConnectionState.connecting -> Unit
        }
    }

    fun setAppVersion(version: String) {
        if (_appVersion == version) return
        _appVersion = version
        emitUiState()
    }

    fun prepareLogExport(): String {
        val uiState = _uiStateStream.value
        return """
            {
              "timestamp":"${java.time.Instant.now()}",
              "connectionType":"${uiState.connectionType}",
              "units":"${uiState.units}",
              "connectionState":"${uiState.connectionState}",
              "appVersion":"${uiState.appVersion}",
              "wifiHost":"${uiState.wifiHost}",
              "wifiPort":${uiState.wifiPort}
            }
        """.trimIndent()
    }

    private fun emitUiState() {
        _uiStateStream.value = buildUiState()
    }

    private fun buildUiState(): SettingsUiState = SettingsUiState(
        wifiHost = wifiHost,
        wifiPort = wifiPort,
        autoConnectToOBD = autoConnectToOBD,
        connectionType = connectionType,
        units = units,
        connectionState = connectionState,
        appVersion = _appVersion,
    )
}

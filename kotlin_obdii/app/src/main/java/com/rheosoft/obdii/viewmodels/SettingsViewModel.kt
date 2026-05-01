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
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

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

    init {
        scope.launch {
            connection.connectionStateStream.collectLatest {
                connectionState = it
                notifyChanged()
            }
        }
        scope.launch {
            config.unitsStream.collectLatest {
                units = it
                notifyChanged()
            }
        }
        scope.launch {
            config.connectionTypeStream.collectLatest {
                connectionType = it
                notifyChanged()
            }
        }
    }

    fun onWifiHostChanged(newHost: String) {
        wifiHost = newHost
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
        notifyChanged()
    }

    fun onUnitsChanged(newUnits: MeasurementUnit) {
        if (newUnits == units) return
        units = newUnits
        config.setUnits(newUnits)
        notifyChanged()
    }

    fun onAutoConnectChanged(value: Boolean) {
        autoConnectToOBD = value
        config.autoConnectToOBD = value
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
}

package com.rheosoft.obdii.core

object CarplayBridge {
    data class SettingsSnapshot(
        val units: MeasurementUnit,
        val connectionType: ConnectionType,
        val autoConnectToOBD: Boolean,
        val wifiHost: String,
        val wifiPort: Int,
    )

    @Volatile
    var latestSettings: SettingsSnapshot? = null
        private set

    @Volatile
    var gaugePreferencesChangeCount: Int = 0
        private set

    fun settingsChanged(
        units: MeasurementUnit,
        connectionType: ConnectionType,
        autoConnectToOBD: Boolean,
        wifiHost: String,
        wifiPort: Int,
    ) {
        latestSettings = SettingsSnapshot(
            units = units,
            connectionType = connectionType,
            autoConnectToOBD = autoConnectToOBD,
            wifiHost = wifiHost,
            wifiPort = wifiPort,
        )
    }

    fun gaugePreferencesChanged() {
        gaugePreferencesChangeCount += 1
    }

    fun resetForTests() {
        latestSettings = null
        gaugePreferencesChangeCount = 0
    }
}

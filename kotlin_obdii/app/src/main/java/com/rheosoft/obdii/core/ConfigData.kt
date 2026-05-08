package com.rheosoft.obdii.core

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/*
enum class MeasurementUnit(val displayName: String) {
    metric("Metric"),
    imperial("Imperial");

    val next: MeasurementUnit
        get() = if (this == metric) imperial else metric
}
*/
enum class ConnectionType(val rawValue: String) {
    bluetooth("bluetooth"),
    wifi("wifi"),
    demo("demo");

    companion object {
        fun fromRaw(raw: String): ConnectionType =
            entries.firstOrNull { it.rawValue == raw } ?: bluetooth
    }
}

enum class GaugesDisplayMode { gauges, list }

interface SettingsConfigProviding {
    var wifiHost: String
    var wifiPort: Int
    var autoConnectToOBD: Boolean
    var connectionType: ConnectionType
    var gaugesDisplayMode: GaugesDisplayMode
    val units: MeasurementUnit
    fun setUnits(units: MeasurementUnit)
    val unitsStream: StateFlow<MeasurementUnit>
    val connectionTypeStream: StateFlow<ConnectionType>
    val gaugesDisplayModeStream: StateFlow<GaugesDisplayMode>
}

interface UnitsProviding {
    val units: MeasurementUnit
    var gaugesDisplayMode: GaugesDisplayMode
    val unitsStream: StateFlow<MeasurementUnit>
    val gaugesDisplayModeStream: StateFlow<GaugesDisplayMode>
}

interface KeyValueStore {
    fun putString(key: String, value: String)
    fun putInt(key: String, value: Int)
    fun putBoolean(key: String, value: Boolean)
    fun getString(key: String): String?
    fun getInt(key: String): Int?
    fun getBoolean(key: String): Boolean?
}

class InMemoryKeyValueStore : KeyValueStore {
    private val map = mutableMapOf<String, Any>()
    override fun putString(key: String, value: String) { map[key] = value }
    override fun putInt(key: String, value: Int) { map[key] = value }
    override fun putBoolean(key: String, value: Boolean) { map[key] = value }
    override fun getString(key: String): String? = map[key] as? String
    override fun getInt(key: String): Int? = map[key] as? Int
    override fun getBoolean(key: String): Boolean? = map[key] as? Boolean
}

object ConfigData : SettingsConfigProviding, UnitsProviding {
    private const val K_WIFI_HOST = "wifiHost"
    private const val K_WIFI_PORT = "wifiPort"
    private const val K_AUTO_CONNECT = "autoConnectToOBD"
    private const val K_CONNECTION_TYPE = "connectionType"
    private const val K_UNITS = "units"
    private const val K_GAUGES_MODE = "gaugesDisplayMode"

    var store: KeyValueStore = InMemoryKeyValueStore()

    override var wifiHost: String = DEFAULT_WIFI_HOST
        set(value) {
            if (field == value) return
            field = value
            store.putString(K_WIFI_HOST, value)
        }

    override var wifiPort: Int = 35000
        set(value) {
            if (field == value) return
            field = value
            store.putInt(K_WIFI_PORT, value)
        }

    override var autoConnectToOBD: Boolean = true
        set(value) {
            if (field == value) return
            field = value
            store.putBoolean(K_AUTO_CONNECT, value)
        }

    override var connectionType: ConnectionType = ConnectionType.bluetooth
        set(value) {
            if (field == value) return
            field = value
            store.putString(K_CONNECTION_TYPE, value.rawValue)
            _connectionTypeFlow.value = value
        }

    override var gaugesDisplayMode: GaugesDisplayMode = GaugesDisplayMode.gauges
        set(value) {
            if (field == value) return
            field = value
            store.putString(K_GAUGES_MODE, value.name)
            _gaugesModeFlow.value = value
        }

    override var units: MeasurementUnit = MeasurementUnit.Metric
        private set

    private val _unitsFlow = MutableStateFlow(MeasurementUnit.Metric)
    private val _connectionTypeFlow = MutableStateFlow(ConnectionType.bluetooth)
    private val _gaugesModeFlow = MutableStateFlow(GaugesDisplayMode.gauges)

    override val unitsStream: StateFlow<MeasurementUnit> = _unitsFlow.asStateFlow()
    override val connectionTypeStream: StateFlow<ConnectionType> = _connectionTypeFlow.asStateFlow()
    override val gaugesDisplayModeStream: StateFlow<GaugesDisplayMode> = _gaugesModeFlow.asStateFlow()

    fun load() {
        wifiHost = store.getString(K_WIFI_HOST) ?: DEFAULT_WIFI_HOST
        wifiPort = store.getInt(K_WIFI_PORT) ?: 35000
        autoConnectToOBD = store.getBoolean(K_AUTO_CONNECT) ?: true
        connectionType = ConnectionType.fromRaw(store.getString(K_CONNECTION_TYPE) ?: "bluetooth")
        units = MeasurementUnit.entries.firstOrNull { it.name == (store.getString(K_UNITS) ?: "metric") }
            ?: MeasurementUnit.Metric
        gaugesDisplayMode = GaugesDisplayMode.entries.firstOrNull { it.name == (store.getString(K_GAUGES_MODE) ?: "gauges") }
            ?: GaugesDisplayMode.gauges
        _unitsFlow.value = units
        _connectionTypeFlow.value = connectionType
        _gaugesModeFlow.value = gaugesDisplayMode
    }

    override fun setUnits(units: MeasurementUnit) {
        if (this.units == units) return
        this.units = units
        store.putString(K_UNITS, units.name)
        _unitsFlow.value = units
    }

    fun resetForTests() {
        wifiHost = DEFAULT_WIFI_HOST
        wifiPort = 35000
        autoConnectToOBD = true
        connectionType = ConnectionType.bluetooth
        setUnits(MeasurementUnit.Metric)
    }
}

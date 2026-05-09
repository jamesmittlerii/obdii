package com.rheosoft.obdii.core

import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ConfigDataTest {
    @BeforeTest
    fun setup() {
        ConfigData.store = InMemoryKeyValueStore()
        ConfigData.resetForTests()
    }

    @Test
    fun `defaults are correct`() {
        assertEquals(DEFAULT_WIFI_HOST, ConfigData.wifiHost)
        assertEquals(35000, ConfigData.wifiPort)
        assertTrue(ConfigData.autoConnectToOBD)
        assertEquals(ConnectionType.bluetooth, ConfigData.connectionType)
        assertEquals(MeasurementUnit.Metric, ConfigData.units)
    }

    @Test
    fun `units and connection stream state updates`() {
        ConfigData.setUnits(MeasurementUnit.Imperial)
        ConfigData.connectionType = ConnectionType.wifi
        ConfigData.gaugesDisplayMode = GaugesDisplayMode.list
        assertEquals(MeasurementUnit.Imperial, ConfigData.unitsStream.value)
        assertEquals(ConnectionType.wifi, ConfigData.connectionTypeStream.value)
        assertEquals(GaugesDisplayMode.list, ConfigData.gaugesDisplayModeStream.value)
    }

    @Test
    fun `values persist in backing store`() {
        ConfigData.wifiHost = "10.0.0.1"
        ConfigData.wifiPort = 1234
        ConfigData.autoConnectToOBD = false
        ConfigData.setUnits(MeasurementUnit.Imperial)
        ConfigData.gaugesDisplayMode = GaugesDisplayMode.list
        val store = ConfigData.store as InMemoryKeyValueStore
        assertEquals("10.0.0.1", store.getString("wifiHost"))
        assertEquals(1234, store.getInt("wifiPort"))
        assertFalse(store.getBoolean("autoConnectToOBD") ?: true)
        assertEquals("Imperial", store.getString("units"))
        assertEquals("list", store.getString("gaugesDisplayMode"))
    }

    @Test
    fun `load correctly restores state from store`() {
        val store = InMemoryKeyValueStore()
        store.putString("wifiHost", "192.168.0.10")
        store.putInt("wifiPort", 8888)
        store.putBoolean("autoConnectToOBD", value = false)
        store.putString("connectionType", "demo")
        store.putString("units", "Imperial")
        store.putString("gaugesDisplayMode", "list")

        ConfigData.store = store
        ConfigData.load()

        assertEquals("192.168.0.10", ConfigData.wifiHost)
        assertEquals(8888, ConfigData.wifiPort)
        assertFalse(ConfigData.autoConnectToOBD)
        assertEquals(ConnectionType.demo, ConfigData.connectionType)
        assertEquals(MeasurementUnit.Imperial, ConfigData.units)
        assertEquals(GaugesDisplayMode.list, ConfigData.gaugesDisplayMode)
    }

    @Test
    fun `connection type fromRaw fallback`() {
        assertEquals(ConnectionType.bluetooth, ConnectionType.fromRaw("unknown"))
        assertEquals(ConnectionType.wifi, ConnectionType.fromRaw("wifi"))
        assertEquals(ConnectionType.demo, ConnectionType.fromRaw("demo"))
    }

    @Test
    fun `setting same values does not trigger store updates`() {
        val store = MockKeyValueStore()
        ConfigData.store = store
        ConfigData.resetForTests()
        
        val initialWriteCount = store.writeCount
        ConfigData.wifiHost = ConfigData.wifiHost
        ConfigData.wifiPort = ConfigData.wifiPort
        ConfigData.autoConnectToOBD = ConfigData.autoConnectToOBD
        ConfigData.connectionType = ConfigData.connectionType
        ConfigData.gaugesDisplayMode = ConfigData.gaugesDisplayMode
        ConfigData.setUnits(ConfigData.units)
        
        assertEquals(initialWriteCount, store.writeCount, "Should not write to store if value is unchanged")
    }
}

private class MockKeyValueStore : KeyValueStore {
    var writeCount = 0
    private val map = mutableMapOf<String, Any>()
    override fun putString(key: String, value: String) { writeCount++; map[key] = value }
    override fun putInt(key: String, value: Int) { writeCount++; map[key] = value }
    override fun putBoolean(key: String, value: Boolean) { writeCount++; map[key] = value }
    override fun getString(key: String): String? = map[key] as? String
    override fun getInt(key: String): Int? = map[key] as? Int
    override fun getBoolean(key: String): Boolean? = map[key] as? Boolean
}

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
        assertEquals(MeasurementUnit.Imperial, ConfigData.unitsStream.value)
        assertEquals(ConnectionType.wifi, ConfigData.connectionTypeStream.value)
    }

    @Test
    fun `values persist in backing store`() {
        ConfigData.wifiHost = "10.0.0.1"
        ConfigData.autoConnectToOBD = false
        ConfigData.setUnits(MeasurementUnit.Imperial)
        val store = ConfigData.store as InMemoryKeyValueStore
        assertEquals("10.0.0.1", store.getString("wifiHost"))
        assertFalse(store.getBoolean("autoConnectToOBD") ?: true)
        assertEquals("Imperial", store.getString("units"))
    }
}

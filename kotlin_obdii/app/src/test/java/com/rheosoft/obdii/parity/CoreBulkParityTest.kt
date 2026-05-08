package com.rheosoft.obdii.parity

import com.rheosoft.obdii.core.CarplayBridge
import com.rheosoft.obdii.core.ConnectionType
import com.rheosoft.obdii.core.MeasurementUnit
import com.rheosoft.obdii.core.DEFAULT_WIFI_HOST
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

class CoreBulkParityTest {
    @Test
    fun `carplay bridge records latest settings snapshot`() {
        CarplayBridge.resetForTests()
        CarplayBridge.settingsChanged(
            units = MeasurementUnit.Metric,
            connectionType = ConnectionType.bluetooth,
            autoConnectToOBD = true,
            wifiHost = DEFAULT_WIFI_HOST,
            wifiPort = 35000,
        )
        val snapshot = CarplayBridge.latestSettings
        assertNotNull(snapshot)
        assertEquals(MeasurementUnit.Metric, snapshot.units)
        assertEquals(ConnectionType.bluetooth, snapshot.connectionType)
    }
}

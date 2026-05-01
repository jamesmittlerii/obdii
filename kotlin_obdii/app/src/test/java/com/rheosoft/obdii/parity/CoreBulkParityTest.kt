package com.rheosoft.obdii.parity

import com.rheosoft.obdii.core.CarplayBridge
import com.rheosoft.obdii.core.ConnectionType
import com.rheosoft.obdii.core.MeasurementUnit
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
            wifiHost = "192.168.0.10",
            wifiPort = 35000,
        )
        val snapshot = CarplayBridge.latestSettings
        assertNotNull(snapshot)
        assertEquals(MeasurementUnit.Metric, snapshot.units)
        assertEquals(ConnectionType.bluetooth, snapshot.connectionType)
    }
}

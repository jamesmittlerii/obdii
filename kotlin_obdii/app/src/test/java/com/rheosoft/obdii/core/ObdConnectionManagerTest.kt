package com.rheosoft.obdii.core

import kotlinx.coroutines.test.runTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class ObdConnectionManagerTest {
    @BeforeTest
    fun setup() {
        OBDConnectionManager.resetForTests()
        ConfigData.connectionType = ConnectionType.demo
        OBDConnectionManager.initialize()
    }

    @Test
    fun `initial state disconnected`() {
        assertEquals(OBDConnectionState.disconnected, OBDConnectionManager.connectionState)
        assertTrue(OBDConnectionManager.pidStats.isEmpty())
        assertNull(OBDConnectionManager.troubleCodes)
        assertNull(OBDConnectionManager.fuelStatus)
        assertNull(OBDConnectionManager.milStatus)
    }

    @Test
    fun `connect demo transitions to connected`() = runTest {
        OBDConnectionManager.connect()
        assertEquals(OBDConnectionState.connected, OBDConnectionManager.connectionState)
    }

    @Test
    fun `disconnect clears stats`() = runTest {
        OBDConnectionManager.connect()
        OBDConnectionManager.disconnect()
        assertEquals(OBDConnectionState.disconnected, OBDConnectionManager.connectionState)
        assertTrue(OBDConnectionManager.pidStats.isEmpty())
    }

    @Test
    fun `pid stats copyWith updates range`() {
        var stats = PIDStats("010C", MeasurementResult(2500.0, "rpm"))
        stats = stats.copyWith(MeasurementResult(3000.0, "rpm"))
        assertEquals(2500.0, stats.min)
        assertEquals(3000.0, stats.max)
        assertEquals(2, stats.sampleCount)
    }
}

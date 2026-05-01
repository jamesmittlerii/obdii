package com.rheosoft.obdii.core

import kotlinx.coroutines.test.runTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
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
    fun `connect demo streams interested pid stats`() = runTest {
        val token = PidInterestRegistry.instance.makeToken()
        PidInterestRegistry.instance.replace(setOf("010C"), token)

        try {
            OBDConnectionManager.connect()

            var stats: PIDStats? = null
            repeat(20) {
                stats = OBDConnectionManager.statsFor("010C")
                if (stats != null) return@repeat
                Thread.sleep(100)
            }

            assertNotNull(stats)
        } finally {
            PidInterestRegistry.instance.clear(token)
            OBDConnectionManager.disconnect()
        }
    }

    @Test
    fun `connect demo streams interested mil status`() = runTest {
        val token = PidInterestRegistry.instance.makeToken()
        PidInterestRegistry.instance.replace(setOf("0101"), token)

        try {
            OBDConnectionManager.connect()

            var status: Status? = null
            repeat(20) {
                status = OBDConnectionManager.milStatus
                if (status != null) return@repeat
                Thread.sleep(100)
            }

            val decoded = assertNotNull(status)
            assertTrue(decoded.monitors.isNotEmpty())
        } finally {
            PidInterestRegistry.instance.clear(token)
            OBDConnectionManager.disconnect()
        }
    }

    @Test
    fun `connect demo streams interested diagnostics`() = runTest {
        val token = PidInterestRegistry.instance.makeToken()
        PidInterestRegistry.instance.replace(setOf("03"), token)

        try {
            OBDConnectionManager.connect()

            var codes: List<TroubleCodeMetadata>? = null
            repeat(20) {
                codes = OBDConnectionManager.troubleCodes
                if (codes != null) return@repeat
                Thread.sleep(100)
            }

            val decoded = assertNotNull(codes)
            assertTrue(decoded.isNotEmpty())
        } finally {
            PidInterestRegistry.instance.clear(token)
            OBDConnectionManager.disconnect()
        }
    }

    @Test
    fun `initialize and connect resyncs existing diagnostics interest`() = runTest {
        val token = PidInterestRegistry.instance.makeToken()
        PidInterestRegistry.instance.replace(setOf("03"), token)

        try {
            OBDConnectionManager.initialize()
            OBDConnectionManager.connect()

            var codes: List<TroubleCodeMetadata>? = null
            repeat(20) {
                codes = OBDConnectionManager.troubleCodes
                if (codes != null) return@repeat
                Thread.sleep(100)
            }

            assertTrue(assertNotNull(codes).isNotEmpty())
        } finally {
            PidInterestRegistry.instance.clear(token)
            OBDConnectionManager.disconnect()
        }
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

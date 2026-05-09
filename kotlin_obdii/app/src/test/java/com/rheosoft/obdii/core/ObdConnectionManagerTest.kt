package com.rheosoft.obdii.core

import kotlinx.coroutines.test.runTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class ObdConnectionManagerTest {
    @BeforeTest
    fun setup() {
        ConfigData.resetForTests()
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
    fun `disconnect clears all terminal state projections`() = runTest {
        val token = PidInterestRegistry.instance.makeToken()
        PidInterestRegistry.instance.replace(setOf("0101", "03"), token)

        try {
            OBDConnectionManager.connect()

            repeat(20) {
                if (OBDConnectionManager.milStatus != null && OBDConnectionManager.troubleCodes != null) {
                    return@repeat
                }
                Thread.sleep(100)
            }

            OBDConnectionManager.disconnect()

            assertEquals(OBDConnectionState.disconnected, OBDConnectionManager.connectionState)
            assertTrue(OBDConnectionManager.pidStats.isEmpty())
            assertNull(OBDConnectionManager.troubleCodes)
            assertNull(OBDConnectionManager.fuelStatus)
            assertNull(OBDConnectionManager.milStatus)
            assertNull(OBDConnectionManager.connectedPeripheralName)
        } finally {
            PidInterestRegistry.instance.clear(token)
        }
    }

    @Test
    fun `state streams expose current values`() = runTest {
        assertEquals(OBDConnectionState.disconnected, OBDConnectionManager.connectionStateStream.value)
        assertTrue(OBDConnectionManager.pidStatsStream.value.isEmpty())
        assertNull(OBDConnectionManager.diagnosticsStream.value)
        assertNull(OBDConnectionManager.fuelStatusStream.value)
        assertNull(OBDConnectionManager.milStatusStream.value)
    }

    @Test
    fun `connect is ignored while already connected`() = runTest {
        OBDConnectionManager.connect()
        assertEquals(OBDConnectionState.connected, OBDConnectionManager.connectionState)

        OBDConnectionManager.connect()

        assertEquals(OBDConnectionState.connected, OBDConnectionManager.connectionState)
    }

    @Test
    fun `update connection details disconnects active connection`() = runTest {
        OBDConnectionManager.connect()

        ConfigData.connectionType = ConnectionType.wifi
        OBDConnectionManager.updateConnectionDetails()

        assertEquals(OBDConnectionState.disconnected, OBDConnectionManager.connectionState)
        assertTrue(OBDConnectionManager.pidStats.isEmpty())
    }

    @Test
    fun `bluetooth without platform adapter fails on jvm`() = runTest {
        ConfigData.connectionType = ConnectionType.bluetooth
        OBDConnectionManager.updateConnectionDetails()

        runCatching { OBDConnectionManager.connect() }

        assertEquals(OBDConnectionState.failed, OBDConnectionManager.connectionState)
    }

    @Test
    fun `pid stats equality and hash reflect values`() {
        val first = PIDStats("010C", MeasurementResult(2500.0, "rpm"))
        val same = PIDStats("010C", MeasurementResult(2500.0, "rpm"))
        val different = first.copyWith(MeasurementResult(3000.0, "rpm"))

        assertEquals(first, same)
        assertEquals(first.hashCode(), same.hashCode())
        assertNotEquals(first, different)
    }

    @Test
    fun `pid stats copyWith updates range`() {
        var stats = PIDStats("010C", MeasurementResult(2500.0, "rpm"))
        stats = stats.copyWith(MeasurementResult(3000.0, "rpm"))
        assertEquals(2500.0, stats.min)
        assertEquals(3000.0, stats.max)
        assertEquals(2, stats.sampleCount)
    }

    @Test
    fun `resetAllStats clears existing stats`() {
        val method = OBDConnectionManager::class.java.getDeclaredMethod("resetAllStats")
        method.isAccessible = true
        method.invoke(OBDConnectionManager)
        assertTrue(OBDConnectionManager.pidStats.isEmpty())
    }

    @Test
    fun `setBleAdapter method parity`() {
        // Just call it to cover the method on JVM
        val adapter = java.lang.reflect.Proxy.newProxyInstance(
            com.rheosoft.obdii.core.communication.ble.BlePlatformAdapter::class.java.classLoader,
            arrayOf(com.rheosoft.obdii.core.communication.ble.BlePlatformAdapter::class.java)
        ) { _, _, _ -> null } as com.rheosoft.obdii.core.communication.ble.BlePlatformAdapter
        OBDConnectionManager.setBleAdapter(adapter)
    }

}

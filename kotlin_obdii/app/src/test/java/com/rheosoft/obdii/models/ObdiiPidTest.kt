package com.rheosoft.obdii.models

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ObdiiPidTest {
    @Test
    fun `value range contains and clamps`() {
        val range = ValueRange(0.0, 100.0)
        assertTrue(range.contains(50.0))
        assertFalse(range.contains(-1.0))
        assertEquals(0.0, range.clampedValue(-10.0))
        assertEquals(100.0, range.clampedValue(101.0))
    }

    @Test
    fun `value range normalized position`() {
        val range = ValueRange(0.0, 100.0)
        assertEquals(0.5, range.normalizedPosition(50.0), 0.001)
    }

    @Test
    fun `obd pid combined range defaults`() {
        val pid = ObdiiPid(
            id = "rpm_test",
            enabled = true,
            label = "RPM",
            name = "Engine RPM",
            pidCommand = "010C",
            units = "RPM"
        )
        val combined = pid.combinedRange()
        assertEquals(0.0, combined.min)
        assertEquals(1.0, combined.max)
    }

    @Test
    fun `obd pid color for value`() {
        val pid = ObdiiPid(
            id = "c",
            label = "Test",
            name = "Test",
            pidCommand = "010C",
            units = "RPM",
            typicalRange = ValueRange(0.0, 2000.0),
            warningRange = ValueRange(2000.0, 4000.0),
            dangerRange = ValueRange(4000.0, 8000.0),
        )
        assertEquals(PidColor.GREEN, pid.colorForValue(1000.0, true))
        assertEquals(PidColor.ORANGE, pid.colorForValue(3000.0, true))
        assertEquals(PidColor.RED, pid.colorForValue(5000.0, true))
        assertEquals(PidColor.BLUE_GREY, pid.colorForValue(9000.0, true))
    }

    @Test
    fun `metric to imperial conversion`() {
        val tempPid = ObdiiPid(
            id = "temp",
            label = "Coolant",
            name = "Engine Coolant Temp",
            pidCommand = "0105",
            units = "°C"
        )
        
        // 100°C should be 212°F
        assertEquals("100 °C", tempPid.formattedValue(100.0, isMetric = true))
        assertEquals("212 °F", tempPid.formattedValue(100.0, isMetric = false))

        val speedPid = ObdiiPid(
            id = "speed",
            label = "Speed",
            name = "Vehicle Speed",
            pidCommand = "010D",
            units = "km/h"
        )
        // 100 km/h should be ~62 mph
        assertEquals("100 km/h", speedPid.formattedValue(100.0, isMetric = true))
        assertEquals("62 mph", speedPid.formattedValue(100.0, isMetric = false))
    }
}

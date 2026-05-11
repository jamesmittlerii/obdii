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
    fun `value range overlap and zero width normalization edge cases`() {
        val range = ValueRange(10.0, 20.0)

        assertTrue(range.overlaps(ValueRange(0.0, 10.0)))
        assertTrue(range.overlaps(ValueRange(20.0, 30.0)))
        assertFalse(range.overlaps(ValueRange(21.0, 30.0)))
        assertEquals(0.0, ValueRange(4.0, 4.0).normalizedPosition(99.0))
    }

    @Test
    fun `value range conversion falls back for unknown units`() {
        val range = ValueRange(1.0, 2.0)

        assertEquals(range, range.converted("unknown", isMetric = false))
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
    fun `obd pid combined range spans all configured ranges`() {
        val pid = ObdiiPid(
            id = "combined",
            label = "Combined",
            name = "Combined",
            pidCommand = "010C",
            units = "RPM",
            typicalRange = ValueRange(700.0, 2500.0),
            warningRange = ValueRange(2500.0, 4000.0),
            dangerRange = ValueRange(4000.0, 6500.0),
        )

        assertEquals(ValueRange(700.0, 6500.0), pid.combinedRange())
        assertEquals("700 – 6500 RPM", pid.displayRange(isMetric = true))
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
    fun `color uses converted imperial ranges`() {
        val pid = ObdiiPid(
            id = "speed",
            label = "Speed",
            name = "Vehicle Speed",
            pidCommand = "010D",
            units = "km/h",
            typicalRange = ValueRange(0.0, 100.0),
            warningRange = ValueRange(100.0, 130.0),
            dangerRange = ValueRange(130.0, 200.0),
        )

        assertEquals(PidColor.GREEN, pid.colorForValue(60.0, isMetric = false))
        assertEquals(PidColor.ORANGE, pid.colorForValue(115.0, isMetric = false))
        assertEquals(PidColor.RED, pid.colorForValue(150.0, isMetric = false))
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

    @Test
    fun `metric conversions cover pressure distance mass air and fuel rate formatting`() {
        val pressure = ObdiiPid("pressure", label = "Pressure", name = "Pressure", pidCommand = "010A", units = "kPa")
        val distance = pressure.copy(id = "distance", units = "km")
        val massAir = pressure.copy(id = "mass_air", units = "g/s")
        val fuelRate = pressure.copy(id = "fuel_rate", units = "L/h")

        assertEquals("15 psi", pressure.formattedValue(100.0, isMetric = false))
        assertEquals("6 mi", distance.formattedValue(10.0, isMetric = false))
        assertEquals("1 lb/min", massAir.formattedValue(10.0, isMetric = false))
        assertEquals("3 gal/h", fuelRate.formattedValue(10.0, isMetric = false))
    }

    @Test
    fun `copyWith keeps current enabled value when omitted`() {
        val pid = ObdiiPid(
            id = "copy",
            enabled = true,
            label = "Copy",
            name = "Copy",
            pidCommand = "010C",
        )

        assertTrue(pid.copyWith().enabled)
        assertFalse(pid.copyWith(enabled = false).enabled)
    }

    @Test
    fun `null units use empty labels and unconverted values`() {
        val pid = ObdiiPid(
            id = "no_units",
            label = "No Units",
            name = "No Units",
            pidCommand = "010C",
        )

        assertEquals("", pid.unitLabel(isMetric = true))
        assertEquals(42.4, pid.convertedValue(42.4, isMetric = false))
        assertEquals("", pid.displayRange(isMetric = true))
        assertEquals("42", pid.formattedValue(42.4, isMetric = true))
        assertEquals(null, pid.typicalRangeFor(isMetric = true))
        assertEquals(null, pid.warningRangeFor(isMetric = true))
        assertEquals(null, pid.dangerRangeFor(isMetric = true))
    }

    @Test
    fun `unknown units keep label and omit units when requested`() {
        val pid = ObdiiPid(
            id = "unknown_units",
            label = "Unknown",
            name = "Unknown",
            pidCommand = "01FF",
            units = "widgets",
            typicalRange = ValueRange(0.0, 10.0),
        )

        assertEquals("widgets", pid.unitLabel(isMetric = false))
        assertEquals(7.5, pid.convertedValue(7.5, isMetric = false))
        assertEquals(ValueRange(0.0, 10.0), pid.typicalRangeFor(isMetric = false))
        assertEquals("8 widgets", pid.formattedValue(7.5, isMetric = false))
        assertEquals("8", pid.formattedValue(7.5, isMetric = false, includeUnits = false))
    }

    @Test
    fun `less common unit conversions map to imperial labels and values`() {
        val pressure = UnitConversion.fromMetricLabel("kPa", isMetric = false)!!
        assertEquals("psi", pressure.displayLabel)
        assertEquals(14.5038, pressure.convert(100.0), 0.0001)

        val distance = UnitConversion.fromMetricLabel("km", isMetric = false)!!
        assertEquals("mi", distance.displayLabel)
        assertEquals(6.21371, distance.convert(10.0), 0.0001)

        val massAirFlow = UnitConversion.fromMetricLabel("g/s", isMetric = false)!!
        assertEquals("lb/min", massAirFlow.displayLabel)
        assertEquals(1.32277, massAirFlow.convert(10.0), 0.0001)

        val fuelRate = UnitConversion.fromMetricLabel("L/h", isMetric = false)!!
        assertEquals("gal/h", fuelRate.displayLabel)
        assertEquals(2.64172, fuelRate.convert(10.0), 0.0001)
    }

    @Test
    fun `passthrough unit conversions preserve supported labels`() {
        listOf("RPM", "%", "V", "λ", "NA", "Pa", "mA", "° BTDC", "s", "count").forEach { label ->
            val conversion = UnitConversion.fromMetricLabel(label, isMetric = false)
            assertEquals(label, conversion?.displayLabel)
            assertEquals(12.34, conversion?.convert?.invoke(12.34))
        }
        assertEquals(null, UnitConversion.fromMetricLabel("mystery", isMetric = true))
    }

    @Test
    fun `formatting uses expected fractional digits by unit`() {
        val voltage = ObdiiPid(
            id = "voltage",
            label = "Voltage",
            name = "Voltage",
            pidCommand = "0142",
            units = "V",
        )
        val lambda = voltage.copy(id = "lambda", units = "λ")
        val fuelRate = voltage.copy(id = "fuel", units = "L/h")

        assertEquals("12.35 V", voltage.formattedValue(12.345, isMetric = true))
        assertEquals("1.23 λ", lambda.formattedValue(1.234, isMetric = true))
        assertEquals("3.5 L/h", fuelRate.formattedValue(3.45, isMetric = true))
    }

    @Test
    fun `range conversion preserves null ranges and converts present ranges`() {
        val pid = ObdiiPid(
            id = "pressure",
            label = "Pressure",
            name = "Pressure",
            pidCommand = "010A",
            units = "kPa",
            typicalRange = ValueRange(0.0, 100.0),
        )

        assertEquals(ValueRange(0.0, 100.0), pid.typicalRangeFor(isMetric = true))
        assertEquals(14.5038, pid.typicalRangeFor(isMetric = false)!!.max, 0.0001)
        assertEquals(null, pid.warningRangeFor(isMetric = false))
        assertEquals(null, pid.dangerRangeFor(isMetric = false))
    }

    @Test
    fun `generated ids are stable prefix and incrementing`() {
        val first = ObdiiPid.generateId()
        val second = ObdiiPid.generateId()

        assertTrue(first.startsWith("pid_"))
        assertTrue(second.startsWith("pid_"))
        assertTrue(second.removePrefix("pid_").toInt() > first.removePrefix("pid_").toInt())
    }
}

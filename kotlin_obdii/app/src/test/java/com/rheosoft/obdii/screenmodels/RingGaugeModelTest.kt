package com.rheosoft.obdii.screenmodels

import com.rheosoft.obdii.models.PidColor
import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.models.ValueRange
import kotlin.test.Test
import kotlin.test.assertEquals

class RingGaugeViewTest {
    @Test
    fun `shows placeholder when no measurement exists`() {
        val pid = ObdiiPid("rpm", true, "RPM", "Engine RPM", "010C", units = "RPM")
        val view = RingGaugeModel(pid = pid, value = null)
        assertEquals("—", view.valueLine)
        assertEquals("RPM", view.unitLine)
        assertEquals(0.0, view.normalized)
    }

    @Test
    fun `formats measured value without units for center text`() {
        val pid = ObdiiPid("rpm", true, "RPM", "Engine RPM", "010C", units = "RPM")
        val view = RingGaugeModel(pid = pid, value = 2500.0)
        assertEquals("2500", view.valueLine)
    }

    @Test
    fun `uses converted imperial unit label`() {
        val pid = ObdiiPid("spd", true, "Speed", "Vehicle Speed", "010D", units = "km/h")
        val view = RingGaugeModel(pid = pid, value = 60.0, isMetric = false)
        assertEquals("mph", view.unitLine)
    }

    @Test
    fun `picks color based on range bands`() {
        val pid = ObdiiPid(
            id = "load",
            enabled = true,
            label = "Load",
            name = "Engine Load",
            pidCommand = "0104",
            units = "%",
            typicalRange = ValueRange(0.0, 60.0),
            warningRange = ValueRange(61.0, 80.0),
            dangerRange = ValueRange(81.0, 100.0),
        )
        assertEquals(PidColor.GREEN, RingGaugeModel(pid, 30.0).progressColor)
        assertEquals(PidColor.ORANGE, RingGaugeModel(pid, 70.0).progressColor)
        assertEquals(PidColor.RED, RingGaugeModel(pid, 90.0).progressColor)
    }

    @Test
    fun `uses blue grey color when no measurement exists`() {
        val pid = ObdiiPid("rpm", true, "RPM", "Engine RPM", "010C", units = "RPM")
        assertEquals(PidColor.BLUE_GREY, RingGaugeModel(pid, null).progressColor)
    }

    @Test
    fun `normalizes value across combined range`() {
        val pid = ObdiiPid(
            id = "temp",
            enabled = true,
            label = "Temp",
            name = "Engine Temp",
            pidCommand = "0105",
            units = "°C",
            typicalRange = ValueRange(20.0, 80.0),
            warningRange = ValueRange(80.0, 100.0),
            dangerRange = ValueRange(100.0, 120.0),
        )

        assertEquals(0.5, RingGaugeModel(pid, 70.0).normalized, 0.001)
    }

    @Test
    fun `normalization clamps below and above range`() {
        val pid = ObdiiPid(
            id = "load",
            enabled = true,
            label = "Load",
            name = "Engine Load",
            pidCommand = "0104",
            units = "%",
            typicalRange = ValueRange(0.0, 100.0),
        )

        assertEquals(0.0, RingGaugeModel(pid, -10.0).normalized)
        assertEquals(1.0, RingGaugeModel(pid, 110.0).normalized)
    }

    @Test
    fun `normalization uses default range when pid has no ranges`() {
        val pid = ObdiiPid("plain", true, "Plain", "Plain", "010C", units = "RPM")

        assertEquals(1.0, RingGaugeModel(pid, 2.0).normalized)
    }

    @Test
    fun `normalization handles flat range without divide by zero`() {
        val pid = ObdiiPid(
            id = "flat",
            enabled = true,
            label = "Flat",
            name = "Flat",
            pidCommand = "010C",
            units = "RPM",
            typicalRange = ValueRange(5.0, 5.0),
        )

        assertEquals(0.0, RingGaugeModel(pid, 5.0).normalized)
    }
}

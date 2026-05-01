package com.rheosoft.obdii.views

import com.rheosoft.obdii.models.PidColor
import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.models.ValueRange
import kotlin.test.Test
import kotlin.test.assertEquals

class RingGaugeViewTest {
    @Test
    fun `shows placeholder when no measurement exists`() {
        val pid = ObdiiPid("rpm", true, "RPM", "Engine RPM", "010C", units = "RPM")
        val view = RingGaugeView(pid = pid, value = null)
        assertEquals("—", view.valueLine)
        assertEquals("RPM", view.unitLine)
        assertEquals(0.0, view.normalized)
    }

    @Test
    fun `formats measured value without units for center text`() {
        val pid = ObdiiPid("rpm", true, "RPM", "Engine RPM", "010C", units = "RPM")
        val view = RingGaugeView(pid = pid, value = 2500.0)
        assertEquals("2500", view.valueLine)
    }

    @Test
    fun `uses converted imperial unit label`() {
        val pid = ObdiiPid("spd", true, "Speed", "Vehicle Speed", "010D", units = "km/h")
        val view = RingGaugeView(pid = pid, value = 60.0, isMetric = false)
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
        assertEquals(PidColor.GREEN, RingGaugeView(pid, 30.0).progressColor)
        assertEquals(PidColor.ORANGE, RingGaugeView(pid, 70.0).progressColor)
        assertEquals(PidColor.RED, RingGaugeView(pid, 90.0).progressColor)
    }
}

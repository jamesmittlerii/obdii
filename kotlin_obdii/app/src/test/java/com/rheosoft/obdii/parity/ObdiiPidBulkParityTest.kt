package com.rheosoft.obdii.parity

import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.models.ValueRange
import kotlin.test.Test
import kotlin.test.assertTrue

class ObdiiPidBulkParityTest {
    @Test
    fun `display formatting remains deterministic`() {
        val pid = ObdiiPid(
            id = "rpm",
            enabled = true,
            label = "RPM",
            name = "Engine RPM",
            pidCommand = "010C",
            units = "RPM",
            typicalRange = ValueRange(0.0, 8000.0),
        )
        val display = pid.displayRange(isMetric = true)
        assertTrue(display.contains("RPM"))
    }
}

package com.rheosoft.obdii.screenmodels

import com.rheosoft.obdii.models.PidColor
import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.models.ValueRange
import kotlin.math.max
import kotlin.math.min

data class RingGaugeModel(
    val pid: ObdiiPid,
    val value: Double?,
    val isMetric: Boolean = true,
) {
    val valueLine: String
        get() = value?.let { pid.formattedValue(it, isMetric, includeUnits = false) } ?: "—"

    val unitLine: String
        get() = pid.unitLabel(isMetric)

    val normalized: Double
        get() {
            val v = value ?: return 0.0
            val range = combinedRange()
            val span = if (range.max == range.min) 1.0 else range.max - range.min
            return ((v - range.min) / span).coerceIn(0.0, 1.0)
        }

    val progressColor: PidColor
        get() = value?.let { pid.colorForValue(it, isMetric) } ?: PidColor.BLUE_GREY

    private fun combinedRange(): ValueRange {
        val ranges = listOfNotNull(
            pid.typicalRangeFor(isMetric),
            pid.warningRangeFor(isMetric),
            pid.dangerRangeFor(isMetric),
        )
        if (ranges.isEmpty()) return ValueRange(0.0, 1.0)
        val minV = ranges.map { it.min }.reduce(::min)
        val maxV = ranges.map { it.max }.reduce(::max)
        return ValueRange(minV, maxV)
    }
}

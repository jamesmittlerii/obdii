package com.rheosoft.obdii.models

import kotlin.math.max
import kotlin.math.min
import java.util.concurrent.atomic.AtomicInteger

data class ValueRange(val min: Double, val max: Double) {
    fun contains(value: Double): Boolean = value >= min && value <= max
    fun clampedValue(value: Double): Double = max(min, min(value, max))
    fun overlaps(other: ValueRange): Boolean = !(other.max < min || other.min > max)
    fun normalizedPosition(value: Double): Double = if (max == min) 0.0 else (value - min) / (max - min)
    fun converted(unitLabel: String, isMetric: Boolean): ValueRange {
        val conv = UnitConversion.fromMetricLabel(unitLabel, isMetric) ?: return this
        return ValueRange(conv.convert(min), conv.convert(max))
    }
}

data class UnitConversion(
    val displayLabel: String,
    val convert: (Double) -> Double,
) {
    companion object {
        fun fromMetricLabel(label: String, isMetric: Boolean): UnitConversion? = when (label) {
            "°C" -> if (isMetric) UnitConversion("°C") { it } else UnitConversion("°F") { (it * 9 / 5) + 32 }
            "km/h" -> if (isMetric) UnitConversion("km/h") { it } else UnitConversion("mph") { it * 0.621371 }
            "kPa" -> if (isMetric) UnitConversion("kPa") { it } else UnitConversion("psi") { it * 0.145038 }
            "km" -> if (isMetric) UnitConversion("km") { it } else UnitConversion("mi") { it * 0.621371 }
            "g/s" -> if (isMetric) UnitConversion("g/s") { it } else UnitConversion("lb/min") { it * 0.132277 }
            "L/h" -> if (isMetric) UnitConversion("L/h") { it } else UnitConversion("gal/h") { it * 0.264172 }
            "RPM", "%", "V", "λ", "NA", "Pa", "mA", "° BTDC", "s", "count" -> UnitConversion(label) { it }
            else -> null
        }
    }
}

enum class ObdPidKind { gauge, status }
enum class PidColor { GREEN, ORANGE, RED, BLUE_GREY }

data class ObdiiPid(
    val id: String,
    var enabled: Boolean = false,
    val label: String,
    val name: String,
    val pidCommand: String,
    val formula: String? = null,
    val units: String? = null,
    val typicalRange: ValueRange? = null,
    val warningRange: ValueRange? = null,
    val dangerRange: ValueRange? = null,
    val notes: String? = null,
    val kind: ObdPidKind = ObdPidKind.gauge,
) {
    fun copyWith(enabled: Boolean? = null): ObdiiPid = copy(enabled = enabled ?: this.enabled)

    fun unitLabel(isMetric: Boolean): String =
        units?.let { UnitConversion.fromMetricLabel(it, isMetric)?.displayLabel ?: it } ?: ""

    fun convertedValue(value: Double, isMetric: Boolean): Double =
        units?.let { UnitConversion.fromMetricLabel(it, isMetric)?.convert?.invoke(value) } ?: value

    private fun convertedRange(range: ValueRange?, isMetric: Boolean): ValueRange? {
        if (range == null || units == null) return range
        return range.converted(units, isMetric)
    }

    fun typicalRangeFor(isMetric: Boolean): ValueRange? = convertedRange(typicalRange, isMetric)
    fun warningRangeFor(isMetric: Boolean): ValueRange? = convertedRange(warningRange, isMetric)
    fun dangerRangeFor(isMetric: Boolean): ValueRange? = convertedRange(dangerRange, isMetric)

    fun combinedRange(): ValueRange {
        val all = listOfNotNull(typicalRange, warningRange, dangerRange)
        if (all.isEmpty()) return ValueRange(0.0, 1.0)
        return ValueRange(all.minOf { it.min }, all.maxOf { it.max })
    }

    fun displayRange(isMetric: Boolean): String {
        if (units == null) return ""
        val converted = combinedRange().converted(units, isMetric)
        val label = unitLabel(isMetric)
        val digits = preferredFractionDigits(label)
        return "${fmt(converted.min, digits)} – ${fmt(converted.max, digits)} $label"
    }

    fun formattedValue(value: Double, isMetric: Boolean, includeUnits: Boolean = true): String {
        val label = unitLabel(isMetric)
        val converted = convertedValue(value, isMetric)
        val formatted = fmt(converted, preferredFractionDigits(label))
        return if (includeUnits && label.isNotEmpty()) "$formatted $label" else formatted
    }

    fun colorForValue(value: Double, isMetric: Boolean): PidColor {
        val converted = convertedValue(value, isMetric)
        return when {
            dangerRangeFor(isMetric)?.contains(converted) == true -> PidColor.RED
            warningRangeFor(isMetric)?.contains(converted) == true -> PidColor.ORANGE
            typicalRangeFor(isMetric)?.contains(converted) == true -> PidColor.GREEN
            else -> PidColor.BLUE_GREY
        }
    }

    private fun preferredFractionDigits(label: String): Int = when (label) {
        "RPM", "°C", "°F", "%", "kPa", "psi", "km/h", "mph", "km", "mi", "s", "count" -> 0
        "V", "g/s", "λ" -> 2
        "L/h" -> 1
        else -> 0
    }

    private fun fmt(value: Double, digits: Int): String = "%.${digits}f".format(value)

    companion object {
        private val idCounter = AtomicInteger(0)
        fun generateId(): String = "pid_${idCounter.incrementAndGet()}"
    }
}

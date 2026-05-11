package com.rheosoft.obdii.parity

import com.rheosoft.obdii.core.CommandCatalog
import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.models.PidColor
import com.rheosoft.obdii.models.ValueRange
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ObdiiPidBulkParityTest {

    private fun pidFromCommand(alias: String): ObdiiPid {
        return ObdiiPid(
            id = "test_$alias",
            label = "Test",
            name = "Test",
            pidCommand = CommandCatalog.resolveCommandId(alias)
        )
    }

    private fun pidWithRanges(
        typical: ValueRange,
        warning: ValueRange? = null,
        danger: ValueRange? = null,
        units: String = "°C"
    ): ObdiiPid = ObdiiPid(
        id = "ranges",
        enabled = true,
        label = "L",
        name = "N",
        pidCommand = "0105",
        units = units,
        typicalRange = typical,
        warningRange = warning,
        dangerRange = danger
    )

    // Command mapping parity
    @Test fun testMapsRpm() = assertEquals("010C", pidFromCommand("rpm").pidCommand)
    @Test fun testMapsSpeed() = assertEquals("010D", pidFromCommand("speed").pidCommand)
    @Test fun testMapsCoolantTemp() = assertEquals("0105", pidFromCommand("coolantTemp").pidCommand)
    @Test fun testMapsIntakeTemp() = assertEquals("010F", pidFromCommand("intakeTemp").pidCommand)
    @Test fun testMapsStatus() = assertEquals("0101", pidFromCommand("status").pidCommand)
    @Test fun testMapsFuelStatus() = assertEquals("0103", pidFromCommand("fuelStatus").pidCommand)
    @Test fun testMapsGETDTC() = assertEquals("03", pidFromCommand("GET_DTC").pidCommand)
    @Test fun testMapsControlModuleVoltage() = assertEquals("0142", pidFromCommand("controlModuleVoltage").pidCommand)
    @Test fun testMapsCommandedEquivRatio() = assertEquals("0144", pidFromCommand("commandedEquivRatio").pidCommand)
    @Test fun testMapsEngineOilTemp() = assertEquals("015C", pidFromCommand("engineOilTemp").pidCommand)
    @Test fun testMapsFuelPressure() = assertEquals("010A", pidFromCommand("fuelPressure").pidCommand)
    @Test fun testMapsCatalystTempB1S1() = assertEquals("013C", pidFromCommand("catalystTempB1S1").pidCommand)
    @Test fun testMapsCatalystTempB2S1() = assertEquals("013D", pidFromCommand("catalystTempB2S1").pidCommand)
    @Test fun testMapsCatalystTempB1S2() = assertEquals("013E", pidFromCommand("catalystTempB1S2").pidCommand)
    @Test fun testMapsCatalystTempB2S2() = assertEquals("013F", pidFromCommand("catalystTempB2S2").pidCommand)
    @Test fun testMapsThrottlePos() = assertEquals("0111", pidFromCommand("throttlePos").pidCommand)
    @Test fun testMapsThrottleActuator() = assertEquals("014C", pidFromCommand("throttleActuator").pidCommand)
    @Test fun testMapsThrottlePosB() = assertEquals("0147", pidFromCommand("throttlePosB").pidCommand)
    @Test fun testMapsThrottlePosC() = assertEquals("0148", pidFromCommand("throttlePosC").pidCommand)
    @Test fun testMapsThrottlePosD() = assertEquals("0149", pidFromCommand("throttlePosD").pidCommand)
    @Test fun testMapsThrottlePosE() = assertEquals("014A", pidFromCommand("throttlePosE").pidCommand)
    @Test fun testMapsThrottlePosF() = assertEquals("014B", pidFromCommand("throttlePosF").pidCommand)
    @Test fun testMapsTimingAdvance() = assertEquals("010E", pidFromCommand("timingAdvance").pidCommand)
    @Test fun testMapsAmbientAirTemp() = assertEquals("0146", pidFromCommand("ambientAirTemp").pidCommand)
    @Test fun testMapsRelativeThrottlePos() = assertEquals("0145", pidFromCommand("relativeThrottlePos").pidCommand)
    @Test fun testMapsEngineLoad() = assertEquals("0104", pidFromCommand("engineLoad").pidCommand)
    @Test fun testMapsAbsoluteLoad() = assertEquals("0143", pidFromCommand("absoluteLoad").pidCommand)
    @Test fun testMapsFuelLevel() = assertEquals("012F", pidFromCommand("fuelLevel").pidCommand)
    @Test fun testMapsBarometricPressure() = assertEquals("0133", pidFromCommand("barometricPressure").pidCommand)
    @Test fun testMapsIntakePressure() = assertEquals("010B", pidFromCommand("intakePressure").pidCommand)
    @Test fun testMapsFuelRailPressureAbs() = assertEquals("0159", pidFromCommand("fuelRailPressureAbs").pidCommand)
    @Test fun testMapsFuelRailPressureDirect() = assertEquals("0123", pidFromCommand("fuelRailPressureDirect").pidCommand)
    @Test fun testMapsFuelRailPressureVac() = assertEquals("0122", pidFromCommand("fuelRailPressureVac").pidCommand)
    @Test fun testMapsMaf() = assertEquals("0110", pidFromCommand("maf").pidCommand)
    @Test fun testMapsFuelRate() = assertEquals("015E", pidFromCommand("fuelRate").pidCommand)
    @Test fun testMapsRelativeAccelPos() = assertEquals("015A", pidFromCommand("relativeAccelPos").pidCommand)
    @Test fun testMapsShortFuelTrim1() = assertEquals("0106", pidFromCommand("shortFuelTrim1").pidCommand)
    @Test fun testMapsLongFuelTrim1() = assertEquals("0107", pidFromCommand("longFuelTrim1").pidCommand)
    @Test fun testMapsShortFuelTrim2() = assertEquals("0108", pidFromCommand("shortFuelTrim2").pidCommand)
    @Test fun testMapsLongFuelTrim2() = assertEquals("0109", pidFromCommand("longFuelTrim2").pidCommand)
    @Test fun testMapsO2Bank1Sensor1() = assertEquals("0114", pidFromCommand("O2Bank1Sensor1").pidCommand)
    @Test fun testMapsO2Bank1Sensor2() = assertEquals("0115", pidFromCommand("O2Bank1Sensor2").pidCommand)
    @Test fun testMapsO2Bank1Sensor3() = assertEquals("0116", pidFromCommand("O2Bank1Sensor3").pidCommand)
    @Test fun testMapsO2Bank1Sensor4() = assertEquals("0117", pidFromCommand("O2Bank1Sensor4").pidCommand)
    @Test fun testMapsO2Bank2Sensor1() = assertEquals("0118", pidFromCommand("O2Bank2Sensor1").pidCommand)
    @Test fun testMapsO2Bank2Sensor2() = assertEquals("0119", pidFromCommand("O2Bank2Sensor2").pidCommand)
    @Test fun testMapsO2Bank2Sensor3() = assertEquals("011A", pidFromCommand("O2Bank2Sensor3").pidCommand)
    @Test fun testMapsO2Sensor() = assertEquals("0113", pidFromCommand("O2Sensor").pidCommand)
    @Test fun testMapsFuelType() = assertEquals("0151", pidFromCommand("fuelType").pidCommand)
    @Test fun testMapsObdcompliance() = assertEquals("011C", pidFromCommand("obdcompliance").pidCommand)
    @Test fun testMapsStatusDriveCycle() = assertEquals("0141", pidFromCommand("statusDriveCycle").pidCommand)
    @Test fun testMapsFreezeDTC() = assertEquals("0202", pidFromCommand("freezeDTC").pidCommand)
    @Test fun testMapsAirStatus() = assertEquals("0112", pidFromCommand("airStatus").pidCommand)
    @Test fun testMapsEvapVaporPressure() = assertEquals("0132", pidFromCommand("evapVaporPressure").pidCommand)
    @Test fun testMapsEvapVaporPressureAlt() = assertEquals("0154", pidFromCommand("evapVaporPressureAlt").pidCommand)
    @Test fun testMapsEvapVaporPressureAbs() = assertEquals("0153", pidFromCommand("evapVaporPressureAbs").pidCommand)
    @Test fun testMapsEvaporativePurge() = assertEquals("012E", pidFromCommand("evaporativePurge").pidCommand)
    @Test fun testMapsCommandedEGR() = assertEquals("012C", pidFromCommand("commandedEGR").pidCommand)
    @Test fun testMapsEGRError() = assertEquals("012D", pidFromCommand("EGRError").pidCommand)
    @Test fun testMapsWarmUpsSinceDTCCleared() = assertEquals("0130", pidFromCommand("warmUpsSinceDTCCleared").pidCommand)
    @Test fun testMapsDistanceSinceDTCCleared() = assertEquals("0131", pidFromCommand("distanceSinceDTCCleared").pidCommand)
    @Test fun testMapsDistanceWMIL() = assertEquals("0121", pidFromCommand("distanceWMIL").pidCommand)
    @Test fun testMapsRunTime() = assertEquals("011F", pidFromCommand("runTime").pidCommand)
    @Test fun testMapsRunTimeMIL() = assertEquals("014D", pidFromCommand("runTimeMIL").pidCommand)
    @Test fun testMapsTimeSinceDTCCleared() = assertEquals("014E", pidFromCommand("timeSinceDTCCleared").pidCommand)
    @Test fun testMapsHybridBatteryLife() = assertEquals("015B", pidFromCommand("hybridBatteryLife").pidCommand)
    @Test fun testMapsFuelInjectionTiming() = assertEquals("015D", pidFromCommand("fuelInjectionTiming").pidCommand)
    @Test fun testMapsMaxMAF() = assertEquals("0150", pidFromCommand("maxMAF").pidCommand)
    @Test fun testMapsEthanoPercent() = assertEquals("0152", pidFromCommand("ethanoPercent").pidCommand)
    @Test fun testMapsO2Sensor1WRVolatage() = assertEquals("0124", pidFromCommand("O2Sensor1WRVolatage").pidCommand)
    @Test fun testMapsO2Sensor2WRVolatage() = assertEquals("0125", pidFromCommand("O2Sensor2WRVolatage").pidCommand)
    @Test fun testMapsO2Sensor3WRVolatage() = assertEquals("0126", pidFromCommand("O2Sensor3WRVolatage").pidCommand)
    @Test fun testMapsO2Sensor4WRVolatage() = assertEquals("0127", pidFromCommand("O2Sensor4WRVolatage").pidCommand)
    @Test fun testMapsO2Sensor5WRVolatage() = assertEquals("0128", pidFromCommand("O2Sensor5WRVolatage").pidCommand)
    @Test fun testMapsO2Sensor6WRVolatage() = assertEquals("0129", pidFromCommand("O2Sensor6WRVolatage").pidCommand)
    @Test fun testMapsO2Sensor7WRVolatage() = assertEquals("012A", pidFromCommand("O2Sensor7WRVolatage").pidCommand)
    @Test fun testMapsO2Sensor8WRVolatage() = assertEquals("012B", pidFromCommand("O2Sensor8WRVolatage").pidCommand)
    @Test fun testMapsO2Sensor1WRCurrent() = assertEquals("0134", pidFromCommand("O2Sensor1WRCurrent").pidCommand)
    @Test fun testMapsO2Sensor2WRCurrent() = assertEquals("0135", pidFromCommand("O2Sensor2WRCurrent").pidCommand)
    @Test fun testMapsO2Sensor3WRCurrent() = assertEquals("0136", pidFromCommand("O2Sensor3WRCurrent").pidCommand)
    @Test fun testMapsO2Sensor4WRCurrent() = assertEquals("0137", pidFromCommand("O2Sensor4WRCurrent").pidCommand)
    @Test fun testMapsO2Sensor5WRCurrent() = assertEquals("0138", pidFromCommand("O2Sensor5WRCurrent").pidCommand)
    @Test fun testMapsO2Sensor6WRCurrent() = assertEquals("0139", pidFromCommand("O2Sensor6WRCurrent").pidCommand)
    @Test fun testMapsO2Sensor7WRCurrent() = assertEquals("013A", pidFromCommand("O2Sensor7WRCurrent").pidCommand)
    @Test fun testMapsO2Sensor8WRCurrent() = assertEquals("013B", pidFromCommand("O2Sensor8WRCurrent").pidCommand)

    // ValueRange behavior
    @Test fun testValuerangeContainsLowerBound() = assertTrue(ValueRange(0.0, 10.0).contains(0.0))
    @Test fun testValuerangeContainsUpperBound() = assertTrue(ValueRange(0.0, 10.0).contains(10.0))
    @Test fun testValuerangeExcludesBelow() = assertFalse(ValueRange(0.0, 10.0).contains(-1.0))
    @Test fun testValuerangeExcludesAbove() = assertFalse(ValueRange(0.0, 10.0).contains(11.0))
    @Test fun testValuerangeClampsBelow() = assertEquals(0.0, ValueRange(0.0, 10.0).clampedValue(-5.0))
    @Test fun testValuerangeClampsAbove() = assertEquals(10.0, ValueRange(0.0, 10.0).clampedValue(20.0))
    @Test fun testValuerangeKeepsMid() = assertEquals(7.0, ValueRange(0.0, 10.0).clampedValue(7.0))
    @Test fun testValuerangeOverlapTrue() = assertTrue(ValueRange(0.0, 10.0).overlaps(ValueRange(5.0, 20.0)))
    @Test fun testValuerangeOverlapFalse() = assertFalse(ValueRange(0.0, 10.0).overlaps(ValueRange(11.0, 20.0)))
    @Test fun testValuerangeNormalizedMin() = assertEquals(0.0, ValueRange(0.0, 10.0).normalizedPosition(0.0))
    @Test fun testValuerangeNormalizedMax() = assertEquals(1.0, ValueRange(0.0, 10.0).normalizedPosition(10.0))
    @Test fun testValuerangeNormalizedMid() = assertEquals(0.5, ValueRange(0.0, 10.0).normalizedPosition(5.0))
    @Test fun testValuerangeNormalizedFlatReturns0() = assertEquals(0.0, ValueRange(1.0, 1.0).normalizedPosition(1.0))

    // Formatting and units
    @Test fun testUnitlabelMetricKmh() = assertEquals("km/h", pidWithRanges(ValueRange(0.0, 1.0), units = "km/h").unitLabel(true))
    @Test fun testUnitlabelImperialKmh() = assertEquals("mph", pidWithRanges(ValueRange(0.0, 1.0), units = "km/h").unitLabel(false))
    @Test fun testUnitlabelMetricCelsius() = assertEquals("°C", pidWithRanges(ValueRange(0.0, 1.0), units = "°C").unitLabel(true))
    @Test fun testUnitlabelImperialCelsius() = assertEquals("°F", pidWithRanges(ValueRange(0.0, 1.0), units = "°C").unitLabel(false))
    @Test fun testUnitlabelUnknownPassthrough() = assertEquals("abc", pidWithRanges(ValueRange(0.0, 1.0), units = "abc").unitLabel(true))
    
    @Test fun testFormattedvalueIncludesUnits() = assertEquals("10 km/h", pidWithRanges(ValueRange(0.0, 1.0), units = "km/h").formattedValue(10.0, true))
    @Test fun testFormattedvalueOmitsUnitsWhenRequested() = assertEquals("10", pidWithRanges(ValueRange(0.0, 1.0), units = "km/h").formattedValue(10.0, true, includeUnits = false))
    @Test fun testDisplayrangeProducesLabel() = assertTrue(pidWithRanges(ValueRange(0.0, 100.0), units = "km/h").displayRange(true).contains("km/h"))
    @Test fun testDisplayrangeImperialUsesMph() = assertTrue(pidWithRanges(ValueRange(0.0, 100.0), units = "km/h").displayRange(false).contains("mph"))

    @Test fun testCombinedrangeUsesAllRangesMin() {
        val pid = pidWithRanges(
            typical = ValueRange(20.0, 80.0),
            warning = ValueRange(10.0, 90.0),
            danger = ValueRange(0.0, 100.0)
        )
        assertEquals(0.0, pid.combinedRange().min)
    }

    @Test fun testCombinedrangeUsesAllRangesMax() {
        val pid = pidWithRanges(
            typical = ValueRange(20.0, 80.0),
            warning = ValueRange(10.0, 90.0),
            danger = ValueRange(0.0, 100.0)
        )
        assertEquals(100.0, pid.combinedRange().max)
    }

    @Test fun testCombinedrangeFallbackDefaults() {
        val pid = ObdiiPid(
            id = "no_ranges",
            label = "L",
            name = "N",
            pidCommand = "010C",
            units = "RPM"
        )
        assertEquals(ValueRange(0.0, 1.0), pid.combinedRange())
    }

    // Color thresholds
    @Test fun testColorDangerRed() {
        val pid = pidWithRanges(
            typical = ValueRange(0.0, 60.0),
            warning = ValueRange(61.0, 80.0),
            danger = ValueRange(81.0, 100.0),
            units = "%"
        )
        assertEquals(PidColor.RED, pid.colorForValue(90.0, true))
    }

    @Test fun testColorWarningOrange() {
        val pid = pidWithRanges(
            typical = ValueRange(0.0, 60.0),
            warning = ValueRange(61.0, 80.0),
            danger = ValueRange(81.0, 100.0),
            units = "%"
        )
        assertEquals(PidColor.ORANGE, pid.colorForValue(70.0, true))
    }

    @Test fun testColorTypicalGreen() {
        val pid = pidWithRanges(
            typical = ValueRange(0.0, 60.0),
            warning = ValueRange(61.0, 80.0),
            danger = ValueRange(81.0, 100.0),
            units = "%"
        )
        assertEquals(PidColor.GREEN, pid.colorForValue(30.0, true))
    }

    @Test fun testColorDefaultBlueGrey() {
        val pid = pidWithRanges(
            typical = ValueRange(10.0, 20.0),
            warning = ValueRange(30.0, 40.0),
            danger = ValueRange(50.0, 60.0),
            units = "%"
        )
        assertEquals(PidColor.BLUE_GREY, pid.colorForValue(25.0, true))
    }
}

package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.GaugesDisplayMode
import com.rheosoft.obdii.core.MeasurementResult
import com.rheosoft.obdii.core.PIDStats
import com.rheosoft.obdii.core.PidInterestRegistry
import com.rheosoft.obdii.core.PidStatsProviding
import com.rheosoft.obdii.core.UnitsProviding
import com.rheosoft.obdii.core.MeasurementUnit
import com.rheosoft.obdii.models.ObdiiPid
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

private class MockStatsProvider : PidStatsProviding {
    private val flow = MutableStateFlow<Map<String, PIDStats>>(emptyMap())
    override val pidStats: Map<String, PIDStats> get() = flow.value
    override fun statsFor(pidCommand: String): PIDStats? = flow.value[pidCommand]
    override val pidStatsStream: StateFlow<Map<String, PIDStats>> = flow
    fun send(stats: Map<String, PIDStats>) { flow.value = stats }
}

private class MockUnitsProvider : UnitsProviding {
    private val flow = MutableStateFlow(MeasurementUnit.Metric)
    override val units: MeasurementUnit get() = flow.value
    override var gaugesDisplayMode: GaugesDisplayMode = GaugesDisplayMode.gauges
    override val unitsStream: StateFlow<MeasurementUnit> = flow
    override val gaugesDisplayModeStream: StateFlow<GaugesDisplayMode> = MutableStateFlow(GaugesDisplayMode.gauges)
    fun send(units: MeasurementUnit) { flow.value = units }
}

class GaugeDetailViewModelTest {
    @Test
    fun `stats updates for matching pid`() {
        val pid = ObdiiPid("rpm", true, "RPM", "Engine RPM", "010C", units = "RPM")
        val stats = MockStatsProvider()
        val vm = GaugeDetailViewModel(pid, stats, MockUnitsProvider())
        assertNull(vm.stats)
        stats.send(mapOf("010C" to PIDStats("010C", MeasurementResult(1500.0, "rpm"))))
        Thread.sleep(50)
        assertEquals(1500.0, vm.stats?.latest?.value)
    }

    @Test
    fun `stats ignore non matching pid and duplicate values`() {
        val pid = ObdiiPid("rpm", true, "RPM", "Engine RPM", "010C", units = "RPM")
        val stats = MockStatsProvider()
        val vm = GaugeDetailViewModel(pid, stats, MockUnitsProvider())
        var changeCount = 0
        vm.onChanged = { changeCount++ }
        Thread.sleep(50)
        val baselineChanges = changeCount

        stats.send(mapOf("010D" to PIDStats("010D", MeasurementResult(30.0, "km/h"))))
        Thread.sleep(50)
        assertNull(vm.stats)
        assertEquals(baselineChanges, changeCount)

        val matching = PIDStats("010C", MeasurementResult(1500.0, "rpm"))
        stats.send(mapOf("010C" to matching))
        Thread.sleep(50)
        assertEquals(1500.0, vm.stats?.latest?.value)
        assertEquals(baselineChanges + 1, changeCount)

        stats.send(mapOf("010C" to PIDStats("010C", MeasurementResult(1500.0, "rpm"))))
        Thread.sleep(50)
        assertEquals(baselineChanges + 1, changeCount)
    }

    @Test
    fun `unit changes refresh state and visibility updates interest registry`() {
        val pid = ObdiiPid("rpm", true, "RPM", "Engine RPM", "010C", units = "RPM")
        val stats = MockStatsProvider()
        val units = MockUnitsProvider()
        val registry = PidInterestRegistry()
        val vm = GaugeDetailViewModel(pid, stats, units, registry)

        stats.send(mapOf("010C" to PIDStats("010C", MeasurementResult(900.0, "rpm"))))
        Thread.sleep(50)
        units.send(MeasurementUnit.Imperial)
        Thread.sleep(50)

        assertEquals(900.0, vm.uiStateStream.value.stats?.latest?.value)

        vm.setVisible(true)
        assertEquals(setOf("010C"), registry.interested)

        vm.setVisible(true)
        assertEquals(setOf("010C"), registry.interested)

        vm.setVisible(false)
        assertEquals(emptySet(), registry.interested)
    }
}

package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.DefaultPidStore
import com.rheosoft.obdii.core.GaugesDisplayMode
import com.rheosoft.obdii.core.MeasurementResult
import com.rheosoft.obdii.core.PIDStats
import com.rheosoft.obdii.core.PidInterestRegistry
import com.rheosoft.obdii.core.PidStatsProviding
import com.rheosoft.obdii.core.UnitsProviding
import com.rheosoft.obdii.core.MeasurementUnit
import com.rheosoft.obdii.models.ObdPidKind
import com.rheosoft.obdii.models.ObdiiPid
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

private class MockStats : PidStatsProviding {
    private val flow = MutableStateFlow<Map<String, PIDStats>>(emptyMap())
    override val pidStats: Map<String, PIDStats> get() = flow.value
    override fun statsFor(pidCommand: String): PIDStats? = flow.value[pidCommand]
    override val pidStatsStream: StateFlow<Map<String, PIDStats>> = flow
    fun send(value: Map<String, PIDStats>) { flow.value = value }
}

private class MockUnits : UnitsProviding {
    private val flow = MutableStateFlow(MeasurementUnit.Metric)
    private val modeFlow = MutableStateFlow(GaugesDisplayMode.gauges)
    override val units: MeasurementUnit get() = flow.value
    override var gaugesDisplayMode: GaugesDisplayMode
        get() = modeFlow.value
        set(value) { modeFlow.value = value }
    override val unitsStream: StateFlow<MeasurementUnit> = flow
    override val gaugesDisplayModeStream: StateFlow<GaugesDisplayMode> = modeFlow
}

class GaugesViewModelTest {
    @Test
    fun `tiles include only enabled gauges`() = runTest {
        DefaultPidStore.resetForTests()
        DefaultPidStore.seededPidsProvider = {
            listOf(
                ObdiiPid("rpm", true, "RPM", "Engine RPM", "010C", units = "RPM", kind = ObdPidKind.gauge),
                ObdiiPid("spd", false, "Speed", "Vehicle Speed", "010D", units = "km/h", kind = ObdPidKind.gauge),
            )
        }
        DefaultPidStore.load()
        val vm = GaugesViewModel(DefaultPidStore, MockStats(), MockUnits(), PidInterestRegistry())
        Thread.sleep(50)
        assertEquals(1, vm.tiles.size)
        assertEquals("rpm", vm.tiles.first().pid.id)
    }

    @Test
    fun `visible registers interests`() = runTest {
        DefaultPidStore.resetForTests()
        DefaultPidStore.seededPidsProvider = {
            listOf(ObdiiPid("rpm", true, "RPM", "Engine RPM", "010C", units = "RPM", kind = ObdPidKind.gauge))
        }
        DefaultPidStore.load()
        val registry = PidInterestRegistry()
        val vm = GaugesViewModel(DefaultPidStore, MockStats(), MockUnits(), registry)
        Thread.sleep(50)
        vm.setVisible(true)
        Thread.sleep(50)
        assertTrue(registry.interested.contains("010C"))
    }
}

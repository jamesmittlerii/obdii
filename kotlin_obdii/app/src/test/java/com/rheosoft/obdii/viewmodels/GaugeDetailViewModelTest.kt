package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.MeasurementResult
import com.rheosoft.obdii.core.PIDStats
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
    private val flow = MutableStateFlow(MeasurementUnit.metric)
    override val units: MeasurementUnit get() = flow.value
    override val unitsStream: StateFlow<MeasurementUnit> = flow
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
}

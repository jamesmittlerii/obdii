package com.rheosoft.obdii.android.ui.screens

import androidx.compose.ui.Modifier
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createComposeRule
import com.rheosoft.obdii.core.*
import com.rheosoft.obdii.models.ObdPidKind
import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.screenmodels.DashboardScreenModel
import com.rheosoft.obdii.viewmodels.GaugesViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.junit.Rule
import org.junit.Test

private class MockPidProvider : PidListProviding {
    private val flow = MutableStateFlow<List<ObdiiPid>>(emptyList())
    override var pids: List<ObdiiPid> = emptyList()
        private set
    override val pidsStream: StateFlow<List<ObdiiPid>> = flow
    fun send(newPids: List<ObdiiPid>) {
        pids = newPids
        flow.value = newPids
    }
}

private class MockStatsProvider : PidStatsProviding {
    private val flow = MutableStateFlow<Map<String, PIDStats>>(emptyMap())
    override var pidStats: Map<String, PIDStats> = emptyMap()
        private set
    override val pidStatsStream: StateFlow<Map<String, PIDStats>> = flow
    override fun statsFor(pidCommand: String): PIDStats? = pidStats[pidCommand]
    fun send(newStats: Map<String, PIDStats>) {
        pidStats = newStats
        flow.value = newStats
    }
}

private class MockUnitsProvider : UnitsProviding {
    private val _unitsFlow = MutableStateFlow(MeasurementUnit.Metric)
    private val _modeFlow = MutableStateFlow(GaugesDisplayMode.gauges)
    override var units: MeasurementUnit = MeasurementUnit.Metric
        set(value) {
            field = value
            _unitsFlow.value = value
        }
    override val unitsStream: StateFlow<MeasurementUnit> = _unitsFlow
    override var gaugesDisplayMode: GaugesDisplayMode = GaugesDisplayMode.gauges
        set(value) {
            field = value
            _modeFlow.value = value
        }
    override val gaugesDisplayModeStream: StateFlow<GaugesDisplayMode> = _modeFlow
}

class DashboardScreenUiTest {
    @get:Rule
    val composeRule = createComposeRule()

    private fun gaugePid(id: String, label: String, name: String, command: String) = ObdiiPid(
        id = id,
        enabled = true,
        label = label,
        name = name,
        pidCommand = command,
        units = "RPM",
        kind = ObdPidKind.gauge
    )

    private fun setupScreen(
        pidProvider: MockPidProvider = MockPidProvider(),
        statsProvider: MockStatsProvider = MockStatsProvider(),
        unitsProvider: MockUnitsProvider = MockUnitsProvider()
    ): Triple<GaugesViewModel, MockPidProvider, MockStatsProvider> {
        val vm = GaugesViewModel(
            pidProvider = pidProvider,
            statsProvider = statsProvider,
            unitsProvider = unitsProvider,
            interestRegistry = PidInterestRegistry()
        )
        val screenModel = DashboardScreenModel(vm)
        composeRule.setContent {
            val scope = androidx.compose.runtime.rememberCoroutineScope()
            DashboardScreen(
                view = screenModel,
                isMetric = unitsProvider.units == MeasurementUnit.Metric,
                modifier = Modifier,
                scope = scope,
                onGaugeTap = {}
            )
        }
        return Triple(vm, pidProvider, statsProvider)
    }

    @Test
    fun testShowsEmptyStateWhenNoEnabledGaugesExist() {
        setupScreen()
        
        composeRule.onNodeWithText("No gauges enabled.", substring = true).assertIsDisplayed()
    }

    @Test
    fun testShowsGaugeTileContentWhenEnabledGaugeExists() {
        val (_, pidProvider, statsProvider) = setupScreen()
        
        val pid = gaugePid("rpm", "RPM", "Engine RPM", "010C")
        pidProvider.send(listOf(pid))
        statsProvider.send(mapOf("010C" to PIDStats("010C", MeasurementResult(1200.0, "RPM"))))

        composeRule.onNodeWithText("RPM").assertIsDisplayed()
        composeRule.onNodeWithText("1200").assertIsDisplayed()
    }

    @Test
    fun testSwitchingSegmentedControlChangesToListMode() {
        val (_, pidProvider, _) = setupScreen()
        pidProvider.send(listOf(gaugePid("rpm", "RPM", "Engine RPM", "010C")))

        composeRule.onNodeWithText("List").performClick()

        composeRule.onNodeWithText("Engine RPM").assertIsDisplayed()
        composeRule.onNodeWithText("Gauges").assertIsDisplayed() // Section label or segmented picker option
    }

    @Test
    fun testListModeShowsRowWithFullGaugeName() {
        val (_, pidProvider, _) = setupScreen()
        pidProvider.send(listOf(gaugePid("rpm", "RPM", "Engine RPM", "010C")))

        composeRule.onNodeWithText("List").performClick()

        composeRule.onNodeWithText("Engine RPM").assertIsDisplayed()
    }

    @Test
    fun testSwitchingBackFromListReturnsGaugesMode() {
        val (_, pidProvider, _) = setupScreen()
        pidProvider.send(listOf(gaugePid("rpm", "RPM", "Engine RPM", "010C")))

        composeRule.onNodeWithText("List").performClick()
        composeRule.onNodeWithText("Gauges").performClick()

        composeRule.onNodeWithText("RPM").assertIsDisplayed()
        composeRule.onNodeWithText("Engine RPM").assertDoesNotExist()
    }

    @Test
    fun testSegmentedControlRendersBothOptions() {
        setupScreen()
        composeRule.onNodeWithText("Gauges").assertIsDisplayed()
        composeRule.onNodeWithText("List").assertIsDisplayed()
    }
}

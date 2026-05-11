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
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

private class MockPidProvider : PidStore {
    private val flow = MutableStateFlow<List<ObdiiPid>>(emptyList())
    override var pids: List<ObdiiPid> = emptyList()
    override val pidsStream: StateFlow<List<ObdiiPid>> = flow
    override val enabledGauges: List<ObdiiPid> get() = pids.filter { it.enabled }
    override suspend fun load() {}
    override suspend fun toggle(pid: ObdiiPid) {}
    override suspend fun moveEnabled(fromIndex: Int, toIndex: Int) {
        val mutable = pids.toMutableList()
        val item = mutable.removeAt(fromIndex)
        mutable.add(toIndex, item)
        pids = mutable
        flow.value = pids
    }
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

    private fun gaugePid(id: String, label: String, name: String, command: String, units: String = "RPM") = ObdiiPid(
        id = id,
        enabled = true,
        label = label,
        name = name,
        pidCommand = command,
        units = units,
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
                onGaugeTap = { p: ObdiiPid -> }
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
        
        val pid = gaugePid("rpm", "RPM", "Engine RPM", "010C", units = "rpm_units")
        pidProvider.send(listOf(pid))
        statsProvider.send(mapOf("010C" to PIDStats("010C", MeasurementResult(1200.0, "RPM"))))

        composeRule.waitForText("RPM")
        composeRule.onNodeWithText("RPM").assertIsDisplayed()
        composeRule.onNodeWithText("1200").assertIsDisplayed()
    }

    @Test
    fun testSwitchingSegmentedControlChangesToListMode() {
        val (_, pidProvider, _) = setupScreen()
        pidProvider.send(listOf(gaugePid("rpm", "RPM", "Engine RPM", "010C", units = "rpm_units")))

        composeRule.waitForText("List")
        composeRule.onNodeWithText("List").performClick()

        composeRule.onNodeWithText("Engine RPM").assertIsDisplayed()
        composeRule.onNodeWithText("Gauges").assertIsDisplayed() // Section label or segmented picker option
    }

    @Test
    fun testListModeShowsRowWithFullGaugeName() {
        val (_, pidProvider, _) = setupScreen()
        pidProvider.send(listOf(gaugePid("rpm", "RPM", "Engine RPM", "010C", units = "rpm_units")))

        composeRule.waitForText("List")
        composeRule.onNodeWithText("List").performClick()

        composeRule.onNodeWithText("Engine RPM").assertIsDisplayed()
    }

    @Test
    fun testSwitchingBackFromListReturnsGaugesMode() {
        val (_, pidProvider, _) = setupScreen()
        pidProvider.send(listOf(gaugePid("rpm", "RPM", "Engine RPM", "010C", units = "rpm_units")))

        composeRule.waitForText("List")
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

    @Test
    fun testGaugeColors() {
        val (_, pidProvider, statsProvider) = setupScreen()

        val pid = ObdiiPid(
            id = "temp",
            enabled = true,
            label = "Temp",
            name = "Coolant Temp",
            pidCommand = "0105",
            units = "°C",
            typicalRange = com.rheosoft.obdii.models.ValueRange(0.0, 100.0),
            warningRange = com.rheosoft.obdii.models.ValueRange(100.1, 150.0),
            dangerRange = com.rheosoft.obdii.models.ValueRange(150.1, 200.0),
            kind = ObdPidKind.gauge
        )
        pidProvider.send(listOf(pid))

        // Green
        statsProvider.send(mapOf("0105" to PIDStats("0105", MeasurementResult(50.0, "°C"))))
        composeRule.waitForText("50")
        composeRule.onNodeWithText("50").assertIsDisplayed()

        // Orange
        statsProvider.send(mapOf("0105" to PIDStats("0105", MeasurementResult(120.0, "°C"))))
        composeRule.waitForText("120")
        composeRule.onNodeWithText("120").assertIsDisplayed()

        // Red
        statsProvider.send(mapOf("0105" to PIDStats("0105", MeasurementResult(180.0, "°C"))))
        composeRule.waitForText("180")
        composeRule.onNodeWithText("180").assertIsDisplayed()

        // Blue grey (out of range)
        statsProvider.send(mapOf("0105" to PIDStats("0105", MeasurementResult(250.0, "°C"))))
        composeRule.waitForText("250")
        composeRule.onNodeWithText("250").assertIsDisplayed()
    }

    @Test
    fun testDragAndDropInListMode() {
        val (_, pidProvider, _) = setupScreen()
        val pid1 = gaugePid("rpm", "RPM", "Engine RPM", "010C", units = "rpm")
        val pid2 = gaugePid("speed", "Speed", "Vehicle Speed", "010D", units = "km/h")
        pidProvider.send(listOf(pid1, pid2))

        composeRule.onNodeWithText("List").performClick()
        composeRule.onNodeWithText("Engine RPM").assertIsDisplayed()

        // Drag Engine RPM down to trigger reorder
        composeRule.onNodeWithText("Engine RPM").performTouchInput {
            down(center)
            moveBy(androidx.compose.ui.geometry.Offset(0f, 500f))
            up()
        }
        
        // Drag with cancel
        composeRule.onNodeWithText("Engine RPM").performTouchInput {
            down(center)
            moveBy(androidx.compose.ui.geometry.Offset(0f, 100f))
            cancel()
        }
    }

    @Test
    fun testDragAndDropInGridMode() {
        val (_, pidProvider, _) = setupScreen()
        val pid1 = gaugePid("rpm", "RPM", "Engine RPM", "010C", units = "rpm")
        val pid2 = gaugePid("speed", "Speed", "Vehicle Speed", "010D", units = "km/h")
        pidProvider.send(listOf(pid1, pid2))

        composeRule.onNodeWithText("RPM").assertIsDisplayed()

        // Drag RPM in grid
        composeRule.onNodeWithText("RPM").performTouchInput {
            down(center)
            moveBy(androidx.compose.ui.geometry.Offset(500f, 0f))
            up()
        }

        // Drag with cancel
        composeRule.onNodeWithText("RPM").performTouchInput {
            down(center)
            moveBy(androidx.compose.ui.geometry.Offset(100f, 0f))
            cancel()
        }
    }

    @Test
    fun testGaugeTapInGridAndList() {
        var tappedPid: ObdiiPid? = null
        val pid = gaugePid("rpm", "RPM", "Engine RPM", "010C", units = "rpm_units")
        val pidProvider = MockPidProvider().apply { send(listOf(pid)) }

        val vm = GaugesViewModel(
            pidProvider = pidProvider,
            statsProvider = MockStatsProvider(),
            unitsProvider = MockUnitsProvider(),
            interestRegistry = PidInterestRegistry()
        )
        val screenModel = DashboardScreenModel(vm)
        composeRule.setContent {
            DashboardScreen(
                view = screenModel,
                isMetric = true,
                modifier = Modifier,
                scope = androidx.compose.runtime.rememberCoroutineScope(),
                onGaugeTap = { p: ObdiiPid -> tappedPid = p }
            )
        }

        // Grid tap
        composeRule.onNodeWithText("RPM").performClick()
        assertEquals(pid, tappedPid)

        tappedPid = null

        // List tap
        composeRule.onNodeWithText("List").performClick()
        composeRule.onNodeWithText("Engine RPM").performClick()
        assertEquals(pid, tappedPid)
    }

    @Test
    fun testGaugeWithBlankIdUsesPidCommandKeyAndRendersInList() {
        val (_, pidProvider, _) = setupScreen()
        val pid = ObdiiPid(
            id = "",
            enabled = true,
            label = "Coolant",
            name = "Coolant Temp",
            pidCommand = "0105",
            units = "°C",
            kind = ObdPidKind.gauge,
        )
        pidProvider.send(listOf(pid))

        composeRule.onNodeWithText("List").performClick()
        composeRule.onNodeWithText("Coolant Temp").assertIsDisplayed()
    }
}

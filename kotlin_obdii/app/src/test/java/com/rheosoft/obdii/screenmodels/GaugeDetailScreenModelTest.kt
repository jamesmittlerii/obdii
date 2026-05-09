package com.rheosoft.obdii.screenmodels

import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.core.PIDStats
import com.rheosoft.obdii.core.PidStatsProviding
import com.rheosoft.obdii.core.MeasurementResult
import com.rheosoft.obdii.core.MeasurementUnit
import com.rheosoft.obdii.core.ConfigData
import com.rheosoft.obdii.viewmodels.GaugeDetailViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import kotlin.test.assertFalse

class GaugeDetailViewTest {
    @Test
    fun `gauge detail view contains matching pid id and section headers`() {
        val pid = ObdiiPid(id = "rpm", enabled = true, label = "RPM", name = "Engine RPM", pidCommand = "010C", units = "RPM")
        val provider = object : PidStatsProviding {
            override val pidStats: Map<String, PIDStats> = emptyMap()
            private val flow = MutableStateFlow<Map<String, PIDStats>>(emptyMap())
            override val pidStatsStream: StateFlow<Map<String, PIDStats>> = flow.asStateFlow()
            override fun statsFor(pidCommand: String): PIDStats? = pidStats[pidCommand]
        }
        val vm = GaugeDetailViewModel(pid, provider, ConfigData)
        val view = GaugeDetailScreenModel(vm)
        assertEquals("rpm", view.viewModel.pid.id)
        assertEquals("Engine RPM", view.appBarTitle)
        assertEquals(listOf("CURRENT", "STATISTICS", "MAXIMUM RANGE"), view.sectionHeaders)
        assertTrue(view.currentValueText.startsWith("—"))
        assertFalse(view.hasStats)
    }

    @Test
    fun `currentValueText and hasStats with data`() {
        val pid = ObdiiPid(id = "rpm", enabled = true, label = "RPM", name = "Engine RPM", pidCommand = "010C", units = "RPM")
        val stats = PIDStats("010C", MeasurementResult(1500.0, "rpm"))
        val provider = object : PidStatsProviding {
            override val pidStats: Map<String, PIDStats> = mapOf("010C" to stats)
            override val pidStatsStream: StateFlow<Map<String, PIDStats>> = MutableStateFlow(pidStats)
            override fun statsFor(pidCommand: String): PIDStats? = pidStats[pidCommand]
        }
        
        val view = GaugeDetailScreenModel(
            GaugeDetailViewModel(pid, provider, ConfigData),
            unitProvider = { MeasurementUnit.Metric }
        )
        
        assertTrue(view.hasStats)
        assertTrue(view.currentValueText.contains("1500"))
    }
}

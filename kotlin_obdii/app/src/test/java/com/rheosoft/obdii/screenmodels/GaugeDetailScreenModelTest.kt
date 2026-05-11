package com.rheosoft.obdii.screenmodels

import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.core.PIDStats
import com.rheosoft.obdii.core.PidStatsProviding
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import com.rheosoft.obdii.viewmodels.GaugeDetailViewModel
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class GaugeDetailViewTest {
    @Test
    fun `gauge detail view contains matching pid id and section headers`() {
        val pid = ObdiiPid("rpm", true, "RPM", "Engine RPM", "010C", units = "RPM")
        val provider = object : PidStatsProviding {
            override val pidStats: Map<String, PIDStats> = emptyMap()
            private val flow = MutableStateFlow<Map<String, PIDStats>>(emptyMap())
            override val pidStatsStream: StateFlow<Map<String, PIDStats>> = flow.asStateFlow()
            override fun statsFor(pidCommand: String): PIDStats? = pidStats[pidCommand]
        }
        val vm = GaugeDetailViewModel(pid, provider, com.rheosoft.obdii.core.ConfigData)
        val view = GaugeDetailScreenModel(vm)
        assertEquals("rpm", view.viewModel.pid.id)
        assertEquals("Engine RPM", view.appBarTitle)
        assertEquals(listOf("CURRENT", "STATISTICS", "MAXIMUM RANGE"), view.sectionHeaders)
        assertTrue(view.currentValueText.startsWith("—"))
    }
}

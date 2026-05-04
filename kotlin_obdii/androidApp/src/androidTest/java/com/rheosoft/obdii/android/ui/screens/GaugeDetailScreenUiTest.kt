package com.rheosoft.obdii.android.ui.screens

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.rheosoft.obdii.models.ObdPidKind
import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.models.ValueRange
import com.rheosoft.obdii.screenmodels.GaugeDetailScreenModel
import com.rheosoft.obdii.viewmodels.GaugeDetailViewModel
import org.junit.Rule
import org.junit.Test

class GaugeDetailScreenUiTest {
    @get:Rule
    val composeRule = createComposeRule()

    private fun testPid() = ObdiiPid(
        id = "rpm",
        enabled = true,
        label = "RPM",
        name = "Engine RPM",
        pidCommand = "010C",
        units = "RPM",
        kind = ObdPidKind.gauge,
        typicalRange = ValueRange(0.0, 8000.0)
    )

    @Test
    fun testRendersGaugeDetailSectionHeaders() {
        val pid = testPid()
        val vm = GaugeDetailViewModel(pid)
        val detail = GaugeDetailScreenModel(vm)
        
        composeRule.setContent {
            GaugeDetailScreen(detail = detail, isMetric = true, onClose = {})
        }

        composeRule.onNodeWithText("Current").assertIsDisplayed()
        composeRule.onNodeWithText("Statistics").assertIsDisplayed()
        composeRule.onNodeWithText("Maximum range").assertIsDisplayed()
    }

    @Test
    fun testShowsNoDataStateBeforeStatsArrive() {
        val pid = testPid()
        val vm = GaugeDetailViewModel(pid)
        val detail = GaugeDetailScreenModel(vm)
        
        composeRule.setContent {
            GaugeDetailScreen(detail = detail, isMetric = true, onClose = {})
        }

        composeRule.onNodeWithText("No data yet").assertIsDisplayed()
    }

    @Test
    fun testAppBarTitleShowsPIDName() {
        val pid = testPid()
        val vm = GaugeDetailViewModel(pid)
        val detail = GaugeDetailScreenModel(vm)
        
        composeRule.setContent {
            GaugeDetailScreen(detail = detail, isMetric = true, onClose = {})
        }

        composeRule.onNodeWithText("Engine RPM").assertIsDisplayed()
    }
}

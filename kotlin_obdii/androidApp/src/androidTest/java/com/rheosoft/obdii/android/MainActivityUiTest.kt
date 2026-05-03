package com.rheosoft.obdii.android

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class MainActivityUiTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun settings_screen_shows_core_sections() {
        composeRule.onNodeWithText("Units").assertIsDisplayed()
        composeRule.onNodeWithText("Connection").assertIsDisplayed()
        composeRule.onNodeWithText("Diagnostics").assertIsDisplayed()
        composeRule.onNodeWithText("About").assertIsDisplayed()
    }

    @Test
    fun gauge_picker_open_path_is_visible() {
        composeRule.onAllNodesWithText("Gauges")[0].performClick()
        composeRule.onNodeWithText("Enabled").assertIsDisplayed()
        composeRule.onNodeWithText("Share Logs").assertIsDisplayed()
    }

    @Test
    fun settings_shows_units_and_connection_rows() {
        composeRule.onNodeWithText("Metric").assertIsDisplayed()
        composeRule.onNodeWithText("Imperial").assertIsDisplayed()
        composeRule.onNodeWithText("Status").assertIsDisplayed()
        composeRule.onNodeWithText("Type").assertIsDisplayed()
        composeRule.onNodeWithText("Automatically Connect").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("Connection type menu").assertIsDisplayed()
    }

    @Test
    fun gauge_picker_search_is_not_permanent() {
        composeRule.onAllNodesWithText("Gauges")[0].performClick()
        composeRule.onAllNodesWithText("Search PIDs…").assertCountEquals(0)
    }

    @Test
    fun gauge_picker_search_opens_and_closes() {
        composeRule.onAllNodesWithText("Gauges")[0].performClick()
        composeRule.onNodeWithContentDescription("Search PIDs").performClick()
        composeRule.onNodeWithText("Search PIDs…").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("Cancel search").performClick()
        composeRule.onAllNodesWithText("Search PIDs…").assertCountEquals(0)
    }

    @Test
    fun gauge_picker_does_not_show_up_down_labels() {
        composeRule.onAllNodesWithText("Gauges")[0].performClick()
        composeRule.onAllNodesWithText("Up").assertCountEquals(0)
        composeRule.onAllNodesWithText("Down").assertCountEquals(0)
    }

    @Test
    fun settings_does_not_show_share_opened_helper_text() {
        composeRule.onAllNodesWithText("Share Logs opened.").assertCountEquals(0)
    }

    @Test
    fun demo_connect_button_transitions_to_disconnect() {
        composeRule.onNodeWithText("Connect").performClick()
        composeRule.waitUntil(3000) {
            composeRule.onAllNodesWithText("Disconnect").fetchSemanticsNodes().isNotEmpty()
        }
        composeRule.onNodeWithText("Disconnect").assertIsDisplayed()
    }

    @Test
    fun gauges_tab_can_switch_to_list_mode() {
        composeRule.onAllNodesWithText("Gauges")[1].performClick()
        composeRule.onNodeWithText("List").performClick()
        composeRule.onNodeWithText("Gauges").assertIsDisplayed()
    }

    @Test
    fun gauge_picker_shows_reorder_handle_not_buttons() {
        composeRule.onAllNodesWithText("Gauges")[0].performClick()
        assertTrue(composeRule.onAllNodesWithContentDescription("Reorder").fetchSemanticsNodes().isNotEmpty())
        composeRule.onAllNodesWithText("Up").assertCountEquals(0)
        composeRule.onAllNodesWithText("Down").assertCountEquals(0)
    }

    @Test
    fun bottom_nav_switches_major_tabs() {
        composeRule.onAllNodesWithText("Fuel")[0].performClick()
        composeRule.onAllNodesWithText("MIL")[0].performClick()
        composeRule.onAllNodesWithText("DTCs")[0].performClick()
        composeRule.onAllNodesWithText("Settings")[0].performClick()
        composeRule.onNodeWithText("Units").assertIsDisplayed()
    }
}

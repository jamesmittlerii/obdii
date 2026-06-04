package com.rheosoft.obdii.android

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.rheosoft.obdii.android.ui.screens.assertTextVisible
import com.rheosoft.obdii.android.ui.screens.assertTextVisibleAfterScroll
import com.rheosoft.obdii.android.ui.screens.clickFirstText
import com.rheosoft.obdii.android.ui.screens.clickLastText
import com.rheosoft.obdii.android.ui.screens.KotlinObdiiApp
import com.rheosoft.obdii.android.ui.screens.prepareObdiiUiTestConfig
import com.rheosoft.obdii.android.ui.screens.tearDownObdiiUiTestConfig
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class MainActivityUiTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Before
    fun setUp() {
        prepareObdiiUiTestConfig()
        composeRule.setContent {
            KotlinObdiiApp(permissionsReady = true)
        }
    }

    @After
    fun tearDown() {
        tearDownObdiiUiTestConfig()
    }

    @Test
    fun settings_screen_shows_core_sections() {
        composeRule.clickFirstText("Settings")
        composeRule.assertTextVisible("Units")
        composeRule.assertTextVisible("Connection")
        composeRule.assertTextVisibleAfterScroll("Diagnostics")
        composeRule.assertTextVisibleAfterScroll("About")
    }

    @Test
    fun gauge_picker_open_path_is_visible() {
        composeRule.clickFirstText("Settings")
        composeRule.onAllNodesWithText("Gauges", ignoreCase = true)[0].performClick()
        composeRule.assertTextVisible("Enabled")
        composeRule.assertTextVisibleAfterScroll("Disabled")
    }

    @Test
    fun settings_shows_units_and_connection_rows() {
        composeRule.clickFirstText("Settings")
        composeRule.onNodeWithText("Metric").assertIsDisplayed()
        composeRule.onNodeWithText("Imperial").assertIsDisplayed()
        composeRule.onNodeWithText("Status").assertIsDisplayed()
        composeRule.onNodeWithText("Type").assertIsDisplayed()
        composeRule.onNodeWithText("Automatically Connect").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("Connection type menu").assertIsDisplayed()
    }

    @Test
    fun gauge_picker_search_is_not_permanent() {
        composeRule.clickFirstText("Settings")
        composeRule.onAllNodesWithText("Gauges", ignoreCase = true)[0].performClick()
        composeRule.onAllNodesWithText("Search PIDs…").assertCountEquals(0)
    }

    @Test
    fun gauge_picker_search_opens_and_closes() {
        composeRule.clickFirstText("Settings")
        composeRule.onAllNodesWithText("Gauges", ignoreCase = true)[0].performClick()
        composeRule.onNodeWithContentDescription("Search PIDs").performClick()
        composeRule.onNodeWithText("Search PIDs…").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("Cancel search").performClick()
        composeRule.onAllNodesWithText("Search PIDs…").assertCountEquals(0)
    }

    @Test
    fun gauge_picker_does_not_show_up_down_labels() {
        composeRule.clickFirstText("Settings")
        composeRule.onAllNodesWithText("Gauges", ignoreCase = true)[0].performClick()
        composeRule.onAllNodesWithText("Up").assertCountEquals(0)
        composeRule.onAllNodesWithText("Down").assertCountEquals(0)
    }

    @Test
    fun settings_does_not_show_share_opened_helper_text() {
        composeRule.clickFirstText("Settings")
        composeRule.onAllNodesWithText("Share Logs opened.").assertCountEquals(0)
    }

    @Test
    fun connect_button_is_visible() {
        composeRule.clickFirstText("Settings")
        composeRule.onNodeWithText("Connect").assertIsDisplayed()
    }

    @Test
    fun gauges_tab_can_switch_to_list_mode() {
        composeRule.clickLastText("Gauges")
        composeRule.onNodeWithText("List").performClick()
        composeRule.assertTextVisible("Gauges")
    }

    @Test
    fun gauge_picker_shows_reorder_handle_not_buttons() {
        composeRule.clickFirstText("Settings")
        composeRule.onAllNodesWithText("Gauges", ignoreCase = true)[0].performClick()
        composeRule.assertTextVisible("Enabled")
        composeRule.onAllNodesWithText("Up").assertCountEquals(0)
        composeRule.onAllNodesWithText("Down").assertCountEquals(0)
    }

    @Test
    fun bottom_nav_switches_major_tabs() {
        composeRule.clickLastText("Fuel")
        composeRule.clickLastText("MIL")
        composeRule.clickLastText("DTCs")
        composeRule.clickLastText("Settings")
        composeRule.assertTextVisible("Units")
    }
}

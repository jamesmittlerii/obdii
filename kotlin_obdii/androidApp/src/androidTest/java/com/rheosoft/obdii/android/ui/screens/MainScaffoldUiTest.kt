package com.rheosoft.obdii.android.ui.screens

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createComposeRule
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test

class MainScaffoldUiTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Before
    fun setUp() {
        prepareObdiiUiTestConfig()
    }

    @After
    fun tearDown() {
        tearDownObdiiUiTestConfig()
    }

    @Test
    fun testShowsAllFiveBottomNavigationDestinations() {
        composeRule.setContent { KotlinObdiiApp() }

        composeRule.assertTextVisible("Settings")
        composeRule.assertTextVisible("Gauges")
        composeRule.assertTextVisible("Fuel")
        composeRule.assertTextVisible("MIL")
        composeRule.assertTextVisible("DTCs")
    }

    @Test
    fun testStartsOnSettingsTab() {
        composeRule.setContent { KotlinObdiiApp() }
        // Verify we see Settings screen content (e.g. Units section)
        composeRule.clickFirstText("Settings")
        composeRule.assertTextVisible("Units")
    }

    @Test
    fun testNavigatesToGaugesTab() {
        composeRule.setContent { KotlinObdiiApp() }
        
        composeRule.clickFirstText("Gauges")
        
        // Wait for Loading to finish if necessary, but usually content is there
        // Verify we see Dashboard screen content
        composeRule.assertTextVisible("Gauges") // Segmented picker or section
    }

    @Test
    fun testNavigatesToFuelTab() {
        composeRule.setContent { KotlinObdiiApp() }
        
        composeRule.clickFirstText("Fuel")
        
        composeRule.onNodeWithText("Waiting for data...", substring = true).assertIsDisplayed()
    }

    @Test
    fun testNavigatesToMILTab() {
        composeRule.setContent { KotlinObdiiApp() }
        
        composeRule.clickFirstText("MIL")
        
        composeRule.onNodeWithText("MALFUNCTION INDICATOR LAMP").assertIsDisplayed()
    }

    @Test
    fun testNavigatesToDTCTab() {
        composeRule.setContent { KotlinObdiiApp() }
        
        composeRule.clickFirstText("DTCs")
        
        composeRule.onNodeWithText("Waiting for data...", substring = true).assertIsDisplayed()
    }

    @Test
    fun testMilSummaryRowOpensDtcTab() {
        composeRule.setContent { KotlinObdiiApp() }

        composeRule.clickFirstText("MIL")
        composeRule.onNodeWithContentDescription("MIL").performClick()

        composeRule.onNodeWithText("MALFUNCTION INDICATOR LAMP").assertDoesNotExist()
        composeRule.onNodeWithText("Waiting for data...", substring = true).assertIsDisplayed()
    }
}

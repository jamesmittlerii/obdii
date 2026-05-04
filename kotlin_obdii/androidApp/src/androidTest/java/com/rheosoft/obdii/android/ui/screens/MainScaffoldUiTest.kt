package com.rheosoft.obdii.android.ui.screens

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import org.junit.Rule
import org.junit.Test

class MainScaffoldUiTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun testShowsAllFiveBottomNavigationDestinations() {
        composeRule.setContent { KotlinObdiiApp() }
        
        composeRule.onNodeWithContentDescription("Settings").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("Gauges").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("Fuel").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("MIL").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("DTCs").assertIsDisplayed()
    }

    @Test
    fun testStartsOnSettingsTab() {
        composeRule.setContent { KotlinObdiiApp() }
        // Verify we see Settings screen content (e.g. Units section)
        composeRule.onNodeWithText("Units").assertIsDisplayed()
    }

    @Test
    fun testNavigatesToGaugesTab() {
        composeRule.setContent { KotlinObdiiApp() }
        
        composeRule.onNodeWithContentDescription("Gauges").performClick()
        
        // Wait for Loading to finish if necessary, but usually content is there
        // Verify we see Dashboard screen content
        composeRule.onNodeWithText("Gauges").assertIsDisplayed() // Segmented picker or section
    }

    @Test
    fun testNavigatesToFuelTab() {
        composeRule.setContent { KotlinObdiiApp() }
        
        composeRule.onNodeWithContentDescription("Fuel").performClick()
        
        composeRule.onNodeWithText("Waiting for data...", substring = true).assertIsDisplayed()
    }

    @Test
    fun testNavigatesToMILTab() {
        composeRule.setContent { KotlinObdiiApp() }
        
        composeRule.onNodeWithContentDescription("MIL").performClick()
        
        composeRule.onNodeWithText("MALFUNCTION INDICATOR LAMP").assertIsDisplayed()
    }

    @Test
    fun testNavigatesToDTCTab() {
        composeRule.setContent { KotlinObdiiApp() }
        
        composeRule.onNodeWithContentDescription("DTCs").performClick()
        
        composeRule.onNodeWithText("Waiting for data...", substring = true).assertIsDisplayed()
    }
}

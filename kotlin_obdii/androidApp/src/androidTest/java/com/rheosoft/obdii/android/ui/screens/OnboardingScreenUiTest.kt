package com.rheosoft.obdii.android.ui.screens

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createComposeRule
import com.rheosoft.obdii.core.ConfigData
import com.rheosoft.obdii.screenmodels.OnboardingScreenModel
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test

class OnboardingScreenUiTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Before
    fun setUp() {
        prepareOnboardingUiTestConfig()
    }

    @After
    fun tearDown() {
        ConfigData.hasCompletedOnboarding = true
        tearDownObdiiUiTestConfig()
    }

    @Test
    fun showsWelcomeIntroOnFirstLaunch() {
        composeRule.setContent { KotlinObdiiApp() }

        composeRule.waitForText("Welcome to Rheosoft OBDII")
        composeRule.assertTextVisible("Welcome to Rheosoft OBDII")
        composeRule.onNodeWithText("Try Demo").assertDoesNotExist()
        composeRule.assertTextVisible("Next")
    }

    @Test
    fun skipCompletesOnboarding() {
        composeRule.setContent { KotlinObdiiApp() }

        composeRule.waitForText("Skip")
        composeRule.clickFirstText("Skip")

        composeRule.onNodeWithText("Welcome to Rheosoft OBDII").assertDoesNotExist()
        assertTrue(ConfigData.hasCompletedOnboarding)
    }

    @Test
    fun welcomePageShowsSummaryAndNext() {
        composeRule.setContent {
            OnboardingContentScrim(
                pageIndex = 0,
                onPageIndexChange = {},
                onComplete = {},
            )
        }

        composeRule.assertTextVisible("Welcome to Rheosoft OBDII")
        composeRule.assertTextVisible("What you can do")
        composeRule.assertTextVisible("Next")
    }

    @Test
    fun nextAdvancesToSettingsTourPage() {
        composeRule.setContent {
            var pageIndex by remember { mutableIntStateOf(0) }
            OnboardingContentScrim(
                pageIndex = pageIndex,
                onPageIndexChange = { pageIndex = it },
                onComplete = {},
            )
        }

        composeRule.clickFirstText("Next")
        composeRule.waitForText("Settings")
        composeRule.assertTextVisible("Settings")
    }

    @Test
    fun gaugesDashboardPageShowsLayoutHint() {
        val pageIndex = OnboardingScreenModel.pages.indexOfFirst { it.title == "Gauges dashboard" }
        composeRule.setContent {
            OnboardingContentScrim(
                pageIndex = pageIndex,
                onPageIndexChange = {},
                onComplete = {},
            )
        }

        composeRule.assertTextVisible("Ring vs list")
        composeRule.assertTextVisible("Gauges shows circular ring tiles; List shows compact rows.")
    }

    @Test
    fun gaugePickerPageShowsEnabledHints() {
        composeRule.setContent {
            OnboardingContentScrim(
                pageIndex = OnboardingScreenModel.GAUGE_PICKER_PAGE_INDEX,
                onPageIndexChange = {},
                onComplete = {},
            )
        }

        composeRule.assertTextVisible("On this screen")
        composeRule.assertTextVisible("Use switches to enable or disable gauges.")
    }

    @Test
    fun demoPageShowsTryDemoActions() {
        composeRule.setContent {
            OnboardingContentScrim(
                pageIndex = OnboardingScreenModel.DEMO_PAGE_INDEX,
                onPageIndexChange = {},
                onComplete = {},
            )
        }

        composeRule.assertTextVisible("Try Demo mode")
        composeRule.assertTextVisible("Try Demo")
        composeRule.assertTextVisible("Get started without Demo")
    }

    @Test
    fun skipInvokesOnCompleteWithoutDemo() {
        var completedWithDemo: Boolean? = null
        composeRule.setContent {
            OnboardingContentScrim(
                pageIndex = 0,
                onPageIndexChange = {},
                onComplete = { completedWithDemo = it },
            )
        }

        composeRule.clickFirstText("Skip")
        composeRule.runOnIdle { assertEquals(false, completedWithDemo) }
    }

    @Test
    fun navHighlightRendersForGaugesTab() {
        composeRule.setContent {
            OnboardingNavHighlight(highlightedIndex = OnboardingScreenModel.GAUGES_TAB_INDEX)
        }

        composeRule.waitForIdle()
    }
}

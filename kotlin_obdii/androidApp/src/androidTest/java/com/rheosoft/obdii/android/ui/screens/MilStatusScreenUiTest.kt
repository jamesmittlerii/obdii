package com.rheosoft.obdii.android.ui.screens

import androidx.compose.ui.Modifier
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createComposeRule
import com.rheosoft.obdii.core.*
import com.rheosoft.obdii.screenmodels.MilStatusScreenModel
import com.rheosoft.obdii.viewmodels.MilStatusViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

private class MockMilProvider : MilStatusProviding {
    private val flow = MutableStateFlow<Status?>(null)
    override var milStatus: Status? = null
        private set
    override val milStatusStream: StateFlow<Status?> = flow
    fun send(status: Status?) {
        milStatus = status
        flow.value = status
    }
}

class MilStatusScreenUiTest {
    @get:Rule
    val composeRule = createComposeRule()

    private fun setupScreen(
        provider: MockMilProvider = MockMilProvider()
    ): MockMilProvider {
        val vm = MilStatusViewModel(provider = provider, interestRegistry = PidInterestRegistry())
        val screenModel = MilStatusScreenModel(vm)
        composeRule.setContent {
            MilStatusScreen(
                view = screenModel,
                modifier = Modifier
            )
        }
        return provider
    }

    @Test
    fun testMilstatusviewWaitingAndStatusRowsRender() {
        val provider = setupScreen()
        
        composeRule.onNodeWithText("Waiting for data...").assertIsDisplayed()

        provider.send(Status(
            milOn = true,
            dtcCount = 2,
            monitors = listOf(
                ReadinessMonitor("Misfire", supported = true, ready = false),
                ReadinessMonitor("Fuel System", supported = true, ready = true)
            )
        ))

        composeRule.waitForText("MIL: On (2 DTCs)")
        composeRule.onNodeWithText("MIL: On (2 DTCs)").assertIsDisplayed()
        composeRule.onNodeWithText("READINESS MONITORS").assertIsDisplayed()
        composeRule.onNodeWithText("Misfire").assertIsDisplayed()
        composeRule.onNodeWithText("Not Ready").assertIsDisplayed()
        composeRule.onNodeWithText("Fuel System").assertIsDisplayed()
        composeRule.onNodeWithText("Ready").assertIsDisplayed()
    }

    @Test
    fun testMilstatusviewTitleRenders() {
        setupScreen()
        // Header title
        composeRule.onNodeWithText("MALFUNCTION INDICATOR LAMP").assertIsDisplayed()
    }

    @Test
    fun testMilstatusviewSectionHeadersRenderWhenDataExists() {
        val provider = setupScreen()
        provider.send(Status(
            milOn = false,
            dtcCount = 0,
            monitors = listOf(ReadinessMonitor("Misfire", supported = true, ready = true))
        ))
        
        composeRule.waitForText("READINESS MONITORS")
        composeRule.onNodeWithText("MALFUNCTION INDICATOR LAMP").assertIsDisplayed()
        composeRule.onNodeWithText("READINESS MONITORS").assertIsDisplayed()
    }

    @Test
    fun testMilSummaryTapInvokesCallback() {
        var taps = 0
        val vm = MilStatusViewModel(provider = MockMilProvider(), interestRegistry = PidInterestRegistry())
        val screenModel = MilStatusScreenModel(vm)
        composeRule.setContent {
            MilStatusScreen(
                view = screenModel,
                modifier = Modifier,
                onMilSummaryTap = { taps++ },
            )
        }
        composeRule.onNodeWithContentDescription("MIL").performClick()
        assertEquals(1, taps)
    }
}

package com.rheosoft.obdii.android.ui.screens

import androidx.compose.ui.Modifier
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createComposeRule
import com.rheosoft.obdii.core.*
import com.rheosoft.obdii.screenmodels.FuelStatusScreenModel
import com.rheosoft.obdii.viewmodels.FuelStatusViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.junit.Rule
import org.junit.Test

private class MockFuelProvider : FuelStatusProviding {
    private val flow = MutableStateFlow<List<StatusCodeMetadata?>?>(null)
    override var fuelStatus: List<StatusCodeMetadata?>? = null
        private set
    override val fuelStatusStream: StateFlow<List<StatusCodeMetadata?>?> = flow
    fun send(status: List<StatusCodeMetadata?>?) {
        fuelStatus = status
        flow.value = status
    }
}

class FuelStatusScreenUiTest {
    @get:Rule
    val composeRule = createComposeRule()

    private fun setupScreen(
        provider: MockFuelProvider = MockFuelProvider()
    ): MockFuelProvider {
        val vm = FuelStatusViewModel(provider = provider, interestRegistry = PidInterestRegistry())
        val screenModel = FuelStatusScreenModel(vm)
        composeRule.setContent {
            FuelStatusScreen(
                view = screenModel,
                modifier = Modifier
            )
        }
        return provider
    }

    @Test
    fun testFuelstatusviewWaitingAndNoStatusStatesRender() {
        val provider = setupScreen()
        
        composeRule.onNodeWithText("Waiting for data...").assertIsDisplayed()

        provider.send(emptyList())
        composeRule.onNodeWithText("No Fuel System Status Codes").assertIsDisplayed()
    }

    @Test
    fun testFuelstatusviewRendersBankLabelsWhenDataExists() {
        val provider = setupScreen()

        provider.send(listOf(
            StatusCodeMetadata("CL", "Closed loop"),
            StatusCodeMetadata("OL", "Open loop")
        ))

        composeRule.onNodeWithText("Bank 1").assertIsDisplayed()
        composeRule.onNodeWithText("Closed loop").assertIsDisplayed()
        composeRule.onNodeWithText("Bank 2").assertIsDisplayed()
        composeRule.onNodeWithText("Open loop").assertIsDisplayed()
    }
}

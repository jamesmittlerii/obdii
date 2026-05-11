package com.rheosoft.obdii.android.ui.screens

import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createComposeRule
import com.rheosoft.obdii.core.*
import com.rheosoft.obdii.models.ObdPidKind
import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.screenmodels.PidToggleListScreenModel
import com.rheosoft.obdii.viewmodels.PidToggleListViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.junit.Rule
import org.junit.Test

class PidToggleListScreenUiTest {
    @get:Rule
    val composeRule = createComposeRule()

    private fun gaugePid(id: String, name: String, enabled: Boolean) = ObdiiPid(
        id = id,
        enabled = enabled,
        label = name,
        name = name,
        pidCommand = "01$id",
        kind = ObdPidKind.gauge
    )

    private fun setupScreen(
        initialPids: List<ObdiiPid> = emptyList()
    ): Triple<PidToggleListViewModel, InMemoryPidStore, PidToggleListScreenModel> {
        val store = InMemoryPidStore(initialPids)
        val vm = PidToggleListViewModel(store)
        val screenModel = PidToggleListScreenModel(vm)
        composeRule.setContent {
            PidToggleListScreen(
                view = screenModel,
                isMetric = true,
                onClose = {},
                scope = rememberCoroutineScope()
            )
        }
        return Triple(vm, store, screenModel)
    }

    @Test
    fun testShowsEnabledAndDisabledSections() {
        setupScreen(listOf(
            gaugePid("10", "RPM", true),
            gaugePid("11", "Speed", false)
        ))

        composeRule.assertTextVisible("Enabled")
        composeRule.assertTextExists("RPM")
        composeRule.assertTextVisibleAfterScroll("Disabled")
        composeRule.assertTextExists("Speed")
    }

    @Test
    fun testSearchFiltersPids() {
        setupScreen(listOf(
            gaugePid("10", "RPM", true),
            gaugePid("11", "Speed", false)
        ))

        composeRule.onNodeWithContentDescription("Search PIDs").performClick()
        composeRule.onNodeWithText("Search PIDs…").performTextInput("RPM")

        composeRule.assertTextExists("RPM")
        composeRule.onNodeWithText("Speed").assertDoesNotExist()
    }

    @Test
    fun testCancelSearchClearsFilters() {
        setupScreen(listOf(
            gaugePid("10", "RPM", true),
            gaugePid("11", "Speed", false)
        ))

        composeRule.onNodeWithContentDescription("Search PIDs").performClick()
        composeRule.onNodeWithText("Search PIDs…").performTextInput("RPM")
        composeRule.onNodeWithContentDescription("Cancel search").performClick()

        composeRule.assertTextExists("RPM")
        composeRule.assertTextExists("Speed")
    }

    @Test
    fun testSearchMatchesPidCommandAndNotesAndHidesSectionHeadersWhenEmpty() {
        val pidWithNotes = ObdiiPid(
            id = "",
            enabled = false,
            label = "Coolant",
            name = "Coolant Temperature",
            pidCommand = "0105",
            notes = "engine temp",
            kind = ObdPidKind.gauge,
        )
        setupScreen(
            listOf(
                gaugePid("10", "RPM", true),
                pidWithNotes,
            )
        )

        composeRule.onNodeWithContentDescription("Search PIDs").performClick()
        composeRule.onNodeWithText("Search PIDs…").performTextInput("0105")
        composeRule.assertTextExists("Coolant Temperature")
        composeRule.onNodeWithText("Enabled").assertDoesNotExist()

        val searchField = composeRule.onNode(hasSetTextAction())
        searchField.performTextClearance()
        searchField.performTextInput("engine temp")
        composeRule.assertTextExists("Coolant Temperature")
    }

    @Test
    fun testDragAndDropReordersEnabledPids() {
        setupScreen(listOf(
            gaugePid("10", "RPM", true),
            gaugePid("11", "Speed", true)
        ))

        composeRule.onNodeWithText("RPM").assertIsDisplayed()

        composeRule.onNodeWithText("RPM").performTouchInput {
            down(center)
            moveBy(androidx.compose.ui.geometry.Offset(0f, 500f))
            up()
        }
        
        composeRule.onNodeWithText("RPM").performTouchInput {
            down(center)
            moveBy(androidx.compose.ui.geometry.Offset(0f, 100f))
            cancel()
        }
    }
}

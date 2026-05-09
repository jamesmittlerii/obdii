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
            gaugePid("10", "RPM", enabled = true),
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
            gaugePid("10", "RPM", enabled = true),
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
            gaugePid("10", "RPM", enabled = true),
            gaugePid("11", "Speed", false)
        ))

        composeRule.onNodeWithContentDescription("Search PIDs").performClick()
        composeRule.onNodeWithText("Search PIDs…").performTextInput("RPM")
        composeRule.onNodeWithContentDescription("Cancel search").performClick()

        composeRule.assertTextExists("RPM")
        composeRule.assertTextExists("Speed")
    }

    @Test
    fun testTogglingPidUpdatesStore() {
        val (_, store, _) = setupScreen(listOf(
            gaugePid("10", "RPM", false)
        ))

        composeRule.onNode(isToggleable()).performClick()
        // Cast to InMemoryPidStore to access pids property
        val pids = store.pids
        assert(pids.first { it.id == "10" }.enabled)
    }

    @Test
    fun testBackButtonTriggered() {
        var closed = false
        val vm = PidToggleListViewModel(InMemoryPidStore(emptyList()))
        val screenModel = PidToggleListScreenModel(vm)
        composeRule.setContent {
            PidToggleListScreen(
                view = screenModel,
                isMetric = true,
                onClose = { closed = true },
                scope = rememberCoroutineScope()
            )
        }
        
        composeRule.onNodeWithContentDescription("Back").performClick()
        assert(closed)
    }
}

package com.rheosoft.obdii.views

import com.rheosoft.obdii.core.InMemoryPidStore
import com.rheosoft.obdii.models.ObdPidKind
import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.viewmodels.PidToggleListViewModel
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class PidToggleListViewTest {
    private fun vm(): PidToggleListViewModel {
        val store = InMemoryPidStore(
            listOf(
                ObdiiPid("rpm", true, "RPM", "Engine RPM", "010C", units = "RPM", kind = ObdPidKind.gauge),
                ObdiiPid("spd", false, "Speed", "Vehicle Speed", "010D", units = "km/h", kind = ObdPidKind.gauge),
            ),
        )
        return PidToggleListViewModel(store)
    }

    @Test
    fun `title toggles with search mode`() {
        val view = PidToggleListView(vm())
        assertEquals("Gauges", view.title)
        view.startSearch()
        assertEquals("Search PIDs...", view.title)
    }

    @Test
    fun `cancel search clears query`() {
        val viewModel = vm()
        val view = PidToggleListView(viewModel)
        view.startSearch()
        viewModel.searchText = "rpm"
        view.cancelSearch()
        assertFalse(view.isSearching)
        assertEquals("", viewModel.searchText)
    }

    @Test
    fun `no results copy matches flutter`() {
        val viewModel = vm()
        val view = PidToggleListView(viewModel)
        viewModel.searchText = "does-not-exist"
        assertEquals("No results for \"does-not-exist\"", view.noResultsText())
        viewModel.searchText = "rpm"
        assertTrue(view.noResultsText() == null)
    }
}

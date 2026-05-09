package com.rheosoft.obdii.screenmodels

import com.rheosoft.obdii.viewmodels.PidToggleListViewModel
import com.rheosoft.obdii.core.InMemoryPidStore
import com.rheosoft.obdii.models.ObdiiPid
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlin.test.*



class PidToggleListScreenModelTest {
    private lateinit var viewModel: PidToggleListViewModel
    private lateinit var screenModel: PidToggleListScreenModel

    @BeforeTest
    fun setup() {
        viewModel = PidToggleListViewModel(InMemoryPidStore(emptyList()))
        screenModel = PidToggleListScreenModel(viewModel)
    }

    @Test
    fun `testTitle`() {
        assertEquals("Gauges", screenModel.title)
        screenModel.startSearch()
        assertEquals("Search PIDs...", screenModel.title)
    }

    @Test
    fun `testCancelSearch`() {
        screenModel.startSearch()
        viewModel.searchText = "rpm"
        screenModel.cancelSearch()
        assertFalse(screenModel.isSearching)
        assertEquals("", viewModel.searchText)
    }

    @Test
    fun `testNoResultsText`() {
        assertNull(screenModel.noResultsText())
        
        screenModel.startSearch()
        viewModel.searchText = "unknown"
        // filteredEnabled and filteredDisabled will be empty because MockPidProvider is empty
        assertEquals("No results for \"unknown\"", screenModel.noResultsText())
        
        viewModel.searchText = ""
        assertNull(screenModel.noResultsText())
    }
}

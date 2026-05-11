package com.rheosoft.obdii.screenmodels

import com.rheosoft.obdii.viewmodels.PidToggleListViewModel

class PidToggleListScreenModel(
    val viewModel: PidToggleListViewModel,
) {
    val title: String
        get() = if (isSearching) "Search PIDs..." else "Gauges"

    var isSearching: Boolean = false
        private set

    fun startSearch() {
        isSearching = true
    }

    fun cancelSearch() {
        isSearching = false
        viewModel.searchText = ""
    }

    fun noResultsText(): String? {
        val enabled = viewModel.filteredEnabled
        val disabled = viewModel.filteredDisabled
        val hasQuery = viewModel.searchText.isNotBlank()
        return if (enabled.isEmpty() && disabled.isEmpty() && hasQuery) {
            "No results for \"${viewModel.searchText}\""
        } else {
            null
        }
    }
}

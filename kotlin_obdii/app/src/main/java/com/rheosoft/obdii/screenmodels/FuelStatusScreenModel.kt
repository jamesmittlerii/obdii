package com.rheosoft.obdii.screenmodels

import com.rheosoft.obdii.viewmodels.FuelStatusViewModel

class FuelStatusScreenModel(
    val viewModel: FuelStatusViewModel,
    isActive: Boolean = true,
) {
    var isActive: Boolean = isActive
        private set

    val title: String = "Fuel Control Status"

    init {
        viewModel.setVisible(isActive)
    }

    fun setActive(active: Boolean) {
        if (isActive == active) return
        isActive = active
        viewModel.setVisible(active)
    }

    fun contentState(): FuelContentState {
        if (viewModel.status == null) {
            return FuelContentState.Waiting("Waiting for data...")
        }

        val rows = buildList {
            viewModel.bank1?.let { add("Bank 1" to it.description) }
            viewModel.bank2?.let { add("Bank 2" to it.description) }
        }

        if (rows.isEmpty()) {
            return FuelContentState.Empty("No Fuel System Status Codes")
        }
        return FuelContentState.Data(rows)
    }
}

sealed class FuelContentState {
    data class Waiting(val message: String) : FuelContentState()
    data class Empty(val message: String) : FuelContentState()
    data class Data(val banks: List<Pair<String, String>>) : FuelContentState()
}

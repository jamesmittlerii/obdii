package com.rheosoft.obdii.screenmodels

import com.rheosoft.obdii.viewmodels.MilStatusViewModel

class MilStatusScreenModel(
    val viewModel: MilStatusViewModel,
    isActive: Boolean = true,
) {
    var isActive: Boolean = isActive
        private set

    val title: String = "MIL Status"
    val milHeader: String = "Malfunction indicator lamp"
    val readinessHeader: String = "Readiness monitors"

    init {
        viewModel.setVisible(isActive)
    }

    fun setActive(active: Boolean) {
        if (isActive == active) return
        isActive = active
        viewModel.setVisible(active)
    }

    fun milContentState(): MilLampState = when {
        viewModel.status == null -> MilLampState.Waiting("Waiting for data...")
        viewModel.hasStatus -> MilLampState.Value(viewModel.headerText, "build")
        else -> MilLampState.Empty("No MIL Status")
    }

    fun monitorRows(): List<MonitorRowModel> = viewModel.sortedSupportedMonitors.map { monitor ->
        MonitorRowModel(
            name = monitor.name,
            status = if (monitor.ready) "Ready" else "Not Ready",
            icon = "speed",
            color = if (monitor.ready) "blue" else "orange",
        )
    }
}

sealed class MilLampState {
    data class Waiting(val message: String) : MilLampState()
    data class Value(val text: String, val icon: String) : MilLampState()
    data class Empty(val message: String) : MilLampState()
}

data class MonitorRowModel(
    val name: String,
    val status: String,
    val icon: String,
    val color: String,
)

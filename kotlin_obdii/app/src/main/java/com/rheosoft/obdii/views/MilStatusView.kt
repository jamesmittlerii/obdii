package com.rheosoft.obdii.views

import com.rheosoft.obdii.viewmodels.MilStatusViewModel

class MilStatusView(
    val viewModel: MilStatusViewModel,
    isActive: Boolean = true,
) {
    var isActive: Boolean = isActive
        private set

    val title: String = "MIL Status"
    val milHeader: String = "MALFUNCTION INDICATOR LAMP"
    val readinessHeader: String = "READINESS MONITORS"

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

    fun monitorRows(): List<MonitorRowView> = viewModel.sortedSupportedMonitors.map { monitor ->
        MonitorRowView(
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

data class MonitorRowView(
    val name: String,
    val status: String,
    val icon: String,
    val color: String,
)

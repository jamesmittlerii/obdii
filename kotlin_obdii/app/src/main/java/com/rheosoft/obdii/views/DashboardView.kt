package com.rheosoft.obdii.views

import com.rheosoft.obdii.viewmodels.GaugesViewModel

enum class GaugesDisplayMode { gauges, list }

class DashboardView(
    val viewModel: GaugesViewModel,
    initialMode: GaugesDisplayMode = GaugesDisplayMode.gauges,
) {
    var mode: GaugesDisplayMode = initialMode
        private set

    val title: String
        get() = if (mode == GaugesDisplayMode.gauges) "Gauges" else "List"

    val isEmptyState: Boolean
        get() = viewModel.isEmpty

    fun setMode(next: GaugesDisplayMode) {
        mode = next
    }
}

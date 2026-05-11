package com.rheosoft.obdii.screenmodels

import com.rheosoft.obdii.core.GaugesDisplayMode
import com.rheosoft.obdii.viewmodels.GaugesViewModel


class DashboardScreenModel(
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

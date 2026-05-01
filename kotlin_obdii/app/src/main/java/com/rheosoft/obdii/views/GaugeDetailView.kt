package com.rheosoft.obdii.views

import com.rheosoft.obdii.core.ConfigData
import com.rheosoft.obdii.core.MeasurementUnit
import com.rheosoft.obdii.viewmodels.GaugeDetailViewModel

class GaugeDetailView(
    val viewModel: GaugeDetailViewModel,
    private val unitProvider: () -> MeasurementUnit = { ConfigData.units },
) {
    val appBarTitle: String
        get() = viewModel.pid.name

    val sectionHeaders: List<String>
        get() = listOf("CURRENT", "STATISTICS", "MAXIMUM RANGE")

    val currentValueText: String
        get() {
            val isMetric = unitProvider() == MeasurementUnit.metric
            val stats = viewModel.stats
            return if (stats != null) {
                viewModel.pid.formattedValue(stats.latest.value, isMetric, includeUnits = true)
            } else {
                "— ${viewModel.pid.unitLabel(isMetric)}"
            }
        }

    val hasStats: Boolean
        get() = viewModel.stats != null
}

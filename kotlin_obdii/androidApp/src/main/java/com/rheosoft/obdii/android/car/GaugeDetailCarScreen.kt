package com.rheosoft.obdii.android.car

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.*
import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.viewmodels.GaugeDetailViewModel
import com.rheosoft.obdii.core.ConfigData
import com.rheosoft.obdii.core.MeasurementUnit
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner

class GaugeDetailCarScreen(carContext: CarContext, private val pid: ObdiiPid) : Screen(carContext) {
    private val viewModel by lazy { GaugeDetailViewModel(pid) }

    init {
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) {
                viewModel.setVisible(true)
                viewModel.onChanged = { invalidate() }
            }
            override fun onStop(owner: LifecycleOwner) {
                viewModel.setVisible(false)
                viewModel.onChanged = null
            }
        })
    }

    override fun onGetTemplate(): Template {
        val stats = viewModel.stats
        val isMetric = ConfigData.units == MeasurementUnit.Metric
        val paneBuilder = Pane.Builder()

        // Current Value
        val currentValue = if (stats != null) {
            pid.formattedValue(stats.latest.value, isMetric)
        } else {
            "— ${pid.unitLabel(isMetric)}"
        }
        paneBuilder.addRow(Row.Builder()
            .setTitle("Current")
            .addText(currentValue)
            .build())

        // Statistics
        if (stats != null) {
            paneBuilder.addRow(Row.Builder()
                .setTitle("Min / Max")
                .addText("${pid.formattedValue(stats.min, isMetric)} / ${pid.formattedValue(stats.max, isMetric)}")
                .build())
            paneBuilder.addRow(Row.Builder()
                .setTitle("Samples")
                .addText("${stats.sampleCount}")
                .build())
        }

        // Range
        if (pid.units != null) {
            paneBuilder.addRow(Row.Builder()
                .setTitle("Typical Range")
                .addText(pid.displayRange(isMetric))
                .build())
        }

        return PaneTemplate.Builder(paneBuilder.build())
            .setHeader(Header.Builder()
                .setTitle(pid.name)
                .setStartHeaderAction(Action.BACK)
                .build())
            .build()
    }
}

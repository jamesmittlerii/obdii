package com.rheosoft.obdii.android.car

import android.util.Log
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.*
import androidx.core.graphics.drawable.IconCompat
import com.rheosoft.obdii.viewmodels.*
import com.rheosoft.obdii.screenmodels.RingGaugeModel
import com.rheosoft.obdii.core.ConfigData
import com.rheosoft.obdii.core.MeasurementUnit
import com.rheosoft.obdii.models.UnitConversion
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner

class MainCarScreen(carContext: CarContext) : Screen(carContext) {
    private var selectedTab = "gauges"
    private var lastInvalidateTime = 0L
    private val refreshThrottleMs = 500L // Max 2 updates per second
    
    private fun throttledInvalidate() {
        val now = System.currentTimeMillis()
        if (now - lastInvalidateTime >= refreshThrottleMs) {
            lastInvalidateTime = now
            invalidate()
        }
    }

    private val gaugesVm by lazy { GaugesViewModel() }
    private val diagnosticsVm by lazy { DiagnosticsViewModel() }
    private val fuelVm by lazy { FuelStatusViewModel() }
    private val milVm by lazy { MilStatusViewModel() }
    private val settingsVm by lazy { SettingsViewModel() }

    init {
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) {
                gaugesVm.onChanged = { throttledInvalidate() }
                diagnosticsVm.onChanged = { invalidate() }
                fuelVm.onChanged = { invalidate() }
                milVm.onChanged = { invalidate() }
                settingsVm.onChanged = { invalidate() }
                updateViewModelVisibility()
                invalidate()
            }
            override fun onStop(owner: LifecycleOwner) {
                clearAllVisibility()
                gaugesVm.onChanged = null
                diagnosticsVm.onChanged = null
                fuelVm.onChanged = null
                milVm.onChanged = null
                settingsVm.onChanged = null
            }
        })
    }

    private fun updateViewModelVisibility() {
        try {
            gaugesVm.setVisible(selectedTab == "gauges")
            diagnosticsVm.setVisible(selectedTab == "diagnostics")
            fuelVm.setVisible(selectedTab == "system")
            milVm.setVisible(selectedTab == "diagnostics" || selectedTab == "system")
        } catch (e: Exception) {
            Log.e("MainCarScreen", "Error updating VM visibility", e)
        }
    }

    private fun clearAllVisibility() {
        gaugesVm.setVisible(false)
        diagnosticsVm.setVisible(false)
        fuelVm.setVisible(false)
        milVm.setVisible(false)
    }

    override fun onGetTemplate(): Template {
        try {
            val gaugesTab = Tab.Builder()
                .setTitle("Gauges")
                .setIcon(CarIcon.Builder(IconCompat.createWithResource(carContext, android.R.drawable.ic_menu_compass)).build())
                .setContentId("gauges")
                .build()

            val diagnosticsTab = Tab.Builder()
                .setTitle("Health")
                .setIcon(CarIcon.Builder(IconCompat.createWithResource(carContext, android.R.drawable.ic_dialog_info)).build())
                .setContentId("diagnostics")
                .build()

            val systemTab = Tab.Builder()
                .setTitle("System")
                .setIcon(CarIcon.Builder(IconCompat.createWithResource(carContext, android.R.drawable.ic_menu_agenda)).build())
                .setContentId("system")
                .build()

            val settingsTab = Tab.Builder()
                .setTitle("Settings")
                .setIcon(CarIcon.Builder(IconCompat.createWithResource(carContext, android.R.drawable.ic_menu_preferences)).build())
                .setContentId("settings")
                .build()

            return TabTemplate.Builder(object : TabTemplate.TabCallback {
                override fun onTabSelected(tabContentId: String) {
                    selectedTab = tabContentId
                    updateViewModelVisibility()
                    invalidate()
                }
            })
                .setHeaderAction(Action.APP_ICON)
                .addTab(gaugesTab)
                .addTab(diagnosticsTab)
                .addTab(systemTab)
                .addTab(settingsTab)
                .setActiveTabContentId(selectedTab)
                .setTabContents(createTabContents())
                .build()
        } catch (e: Exception) {
            Log.e("MainCarScreen", "Fatal error in onGetTemplate", e)
            return MessageTemplate.Builder("Display Error: ${e.message}")
                .setHeader(Header.Builder().setStartHeaderAction(Action.APP_ICON).build())
                .build()
        }
    }

    private fun createTabContents(): TabContents {
        val template = when (selectedTab) {
            "gauges" -> createGaugesTemplate()
            "diagnostics" -> createDiagnosticsTemplate()
            "system" -> createSystemTemplate()
            "settings" -> createSettingsTemplate()
            else -> createGaugesTemplate()
        }
        return TabContents.Builder(template).build()
    }

    private fun createGaugesTemplate(): Template {
        val gridBuilder = ItemList.Builder()
        val tiles = gaugesVm.tiles
        val isMetric = ConfigData.units == MeasurementUnit.Metric
        
        if (tiles.isEmpty()) {
            gridBuilder.setNoItemsMessage("No gauges enabled")
        } else {
            tiles.forEach { tile ->
                val gaugeModel = RingGaugeModel(tile.pid, tile.stats?.latest?.value, isMetric)
                val gaugeIcon = GaugeRenderer.render(gaugeModel, 256)
                
                gridBuilder.addItem(GridItem.Builder()
                    .setTitle(tile.pid.label)
                    .setText(gaugeModel.valueLine)
                    .setImage(gaugeIcon, GridItem.IMAGE_TYPE_LARGE)
                    .setOnClickListener { 
                        // Visual feedback on tap
                        invalidate() 
                    }
                    .build())
            }
        }

        return GridTemplate.Builder()
            .setSingleList(gridBuilder.build())
            .setHeader(Header.Builder()
                .setTitle("Live Gauges")
                .setStartHeaderAction(Action.APP_ICON)
                .build())
            .build()
    }

    private fun createDiagnosticsTemplate(): ListTemplate {
        val listBuilder = ItemList.Builder()
        val milStatus = milVm.status
        
        // Add MIL Status at the top
        listBuilder.addItem(Row.Builder()
            .setTitle("MIL Status")
            .addText(if (milStatus?.milOn == true) "ON (Check Engine)" else "OFF")
            .build())
        
        val codes = diagnosticsVm.codes
        if (codes.isNullOrEmpty()) {
            listBuilder.addItem(Row.Builder()
                .setTitle("DTC Codes")
                .addText("No error codes found")
                .build())
        } else {
            codes.forEach { dtc ->
                listBuilder.addItem(Row.Builder()
                    .setTitle(dtc.code)
                    .addText(dtc.description.ifEmpty { dtc.title })
                    .build())
            }
        }

        return ListTemplate.Builder()
            .setSingleList(listBuilder.build())
            .setHeader(Header.Builder()
                .setTitle("Vehicle Health")
                .setStartHeaderAction(Action.APP_ICON)
                .build())
            .build()
    }

    private fun createSystemTemplate(): ListTemplate {
        val listBuilder = ItemList.Builder()
        
        // 1. Fuel Status
        val fuelStatus = fuelVm.status
        if (fuelStatus != null) {
            fuelStatus.forEachIndexed { index, meta ->
                if (meta != null) {
                    listBuilder.addItem(Row.Builder()
                        .setTitle("Fuel Bank ${index + 1}")
                        .addText(meta.description)
                        .build())
                }
            }
        }

        // 2. Monitors
        val milStatus = milVm.status
        if (milStatus != null) {
            milStatus.monitors.filter { it.supported }.forEach { monitor ->
                listBuilder.addItem(Row.Builder()
                    .setTitle(monitor.name)
                    .addText(if (monitor.ready) "Ready" else "Not Ready")
                    .build())
            }
        }

        if (listBuilder.build().items.isEmpty()) {
            listBuilder.setNoItemsMessage("Waiting for system data...")
        }

        return ListTemplate.Builder()
            .setSingleList(listBuilder.build())
            .setHeader(Header.Builder()
                .setTitle("System Status")
                .setStartHeaderAction(Action.APP_ICON)
                .build())
            .build()
    }

    private fun createSettingsTemplate(): ListTemplate {
        val listBuilder = ItemList.Builder()
            .addItem(Row.Builder()
                .setTitle("Units")
                .addText(if (settingsVm.units == MeasurementUnit.Metric) "Metric" else "Imperial")
                .setOnClickListener {
                    val next = if (settingsVm.units == MeasurementUnit.Metric) MeasurementUnit.Imperial else MeasurementUnit.Metric
                    settingsVm.onUnitsChanged(next)
                    invalidate()
                }
                .build())
            .addItem(Row.Builder()
                .setTitle("Connection")
                .addText("${settingsVm.connectionType}")
                .build())

        return ListTemplate.Builder()
            .setSingleList(listBuilder.build())
            .setHeader(Header.Builder()
                .setTitle("Settings")
                .setStartHeaderAction(Action.APP_ICON)
                .build())
            .build()
    }
}

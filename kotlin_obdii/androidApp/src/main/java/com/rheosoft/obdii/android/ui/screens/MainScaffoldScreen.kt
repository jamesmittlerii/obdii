package com.rheosoft.obdii.android.ui.screens

import com.rheosoft.obdii.bootstrap.AppBootstrap
import android.content.Context
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.Engineering
import androidx.compose.material.icons.outlined.LocalGasStation
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Speed
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarDefaults
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.padding
import com.rheosoft.obdii.core.DefaultPidStore
import com.rheosoft.obdii.core.MeasurementUnit
import com.rheosoft.obdii.core.ConfigData
import com.rheosoft.obdii.core.OBDConnectionManager
import com.rheosoft.obdii.viewmodels.DiagnosticsViewModel
import com.rheosoft.obdii.viewmodels.FuelStatusViewModel
import com.rheosoft.obdii.viewmodels.GaugeDetailViewModel
import com.rheosoft.obdii.viewmodels.GaugesViewModel
import com.rheosoft.obdii.viewmodels.MilStatusViewModel
import com.rheosoft.obdii.viewmodels.PidToggleListViewModel
import com.rheosoft.obdii.viewmodels.SettingsViewModel
import com.rheosoft.obdii.screenmodels.DashboardScreenModel
import com.rheosoft.obdii.screenmodels.DiagnosticsScreenModel
import com.rheosoft.obdii.screenmodels.DtcDetailScreenModel
import com.rheosoft.obdii.screenmodels.FuelStatusScreenModel
import com.rheosoft.obdii.screenmodels.GaugeDetailScreenModel
import com.rheosoft.obdii.screenmodels.GaugesDisplayMode
import com.rheosoft.obdii.screenmodels.MainScaffoldScreenModel
import com.rheosoft.obdii.screenmodels.MilStatusScreenModel
import com.rheosoft.obdii.screenmodels.PidToggleListScreenModel
import com.rheosoft.obdii.screenmodels.SettingsScreenModel
import kotlinx.coroutines.launch

@Composable
@OptIn(ExperimentalMaterial3Api::class)
fun KotlinObdiiApp() {
    val context = LocalContext.current
    val uiPrefs = remember(context) { context.getSharedPreferences("kotlin_obdii_prefs", Context.MODE_PRIVATE) }
    var selected by remember { mutableIntStateOf(uiPrefs.getInt("ui.selectedTab", 0)) }
    var ready by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    var showGaugePicker by remember { mutableStateOf(false) }
    var gaugesModeList by remember { mutableStateOf(uiPrefs.getBoolean("ui.gaugesModeList", false)) }
    val settingsVm = remember { SettingsViewModel() }
    val settingsView = remember { SettingsScreenModel(settingsVm) }
    val gaugePickerVm = remember { PidToggleListViewModel(DefaultPidStore) }
    val gaugePickerView = remember { PidToggleListScreenModel(gaugePickerVm) }
    val gaugesVm = remember { GaugesViewModel() }
    val dashboardView = remember {
        DashboardScreenModel(
            gaugesVm,
            if (gaugesModeList) GaugesDisplayMode.list else GaugesDisplayMode.gauges,
        )
    }
    val fuelView = remember { FuelStatusScreenModel(FuelStatusViewModel(), isActive = false) }
    val milView = remember { MilStatusScreenModel(MilStatusViewModel(), isActive = false) }
    val dtcView = remember { DiagnosticsScreenModel(DiagnosticsViewModel(), isActive = false) }
    var selectedGaugeDetail by remember { mutableStateOf<GaugeDetailScreenModel?>(null) }
    var selectedDtcDetail by remember { mutableStateOf<DtcDetailScreenModel?>(null) }

    LaunchedEffect(Unit) {
        if (DefaultPidStore.pids.isEmpty()) {
            val pidsFromJson = loadPidsFromJson(context)
            DefaultPidStore.seededPidsProvider = { if (pidsFromJson.isNotEmpty()) pidsFromJson else defaultGaugeSeedPids() }
        }
        runCatching { AppBootstrap.initialize() }
        fuelView.setActive(selected == 2)
        milView.setActive(selected == 3)
        dtcView.setActive(selected == 4)
        gaugesVm.setVisible(selected == 1)
        ready = true
        // Keep first paint responsive: auto-connect runs in background.
        if (ConfigData.autoConnectToOBD) {
            scope.launch {
                runCatching {
                    OBDConnectionManager.connect()
                }
            }
        }
    }
    LaunchedEffect(selected) {
        uiPrefs.edit().putInt("ui.selectedTab", selected).apply()
    }
    LaunchedEffect(selected, ready) {
        if (ready) {
            fuelView.setActive(selected == 2)
            milView.setActive(selected == 3)
            dtcView.setActive(selected == 4)
            gaugesVm.setVisible(selected == 1)
        }
    }
    LaunchedEffect(gaugesModeList) {
        dashboardView.setMode(if (gaugesModeList) GaugesDisplayMode.list else GaugesDisplayMode.gauges)
        uiPrefs.edit().putBoolean("ui.gaugesModeList", gaugesModeList).apply()
    }

    ObserveChanges(settingsVm)
    ObservePidChanges(gaugePickerVm)

    Scaffold(
        topBar = {
            val title = if (selected == 1) dashboardView.title else MainScaffoldScreenModel.destinations[selected]
            TopAppBar(
                title = { Text(title) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = AppBackground,
                    titleContentColor = Color(0xFF1D2433),
                ),
            )
        },
        bottomBar = {
            NavigationBar(
                containerColor = Color(0xFFF1F3F8),
                tonalElevation = 8.dp,
                windowInsets = NavigationBarDefaults.windowInsets,
            ) {
                MainScaffoldScreenModel.destinations.forEachIndexed { idx, label ->
                    NavigationBarItem(
                        selected = selected == idx,
                        onClick = { selected = idx },
                        icon = {
                            Icon(
                                imageVector = when (idx) {
                                    0 -> Icons.Outlined.Settings
                                    1 -> Icons.Outlined.Speed
                                    2 -> Icons.Outlined.LocalGasStation
                                    3 -> Icons.Outlined.Engineering
                                    else -> Icons.Outlined.Build
                                },
                                contentDescription = label,
                            )
                        },
                        label = { Text(label) },
                    )
                }
            }
        },
        containerColor = AppBackground,
    ) { pad ->
        if (!ready) {
            CenterText("Loading...", Modifier.padding(pad))
            return@Scaffold
        }
        when (selected) {
            0 -> SettingsScreen(
                view = settingsView,
                modifier = Modifier.padding(pad),
                onOpenGaugePicker = { showGaugePicker = true },
            )
            1 -> DashboardScreen(
                view = dashboardView,
                isMetric = settingsVm.units == MeasurementUnit.Metric,
                modifier = Modifier.padding(pad),
                listMode = gaugesModeList,
                onModeChanged = { gaugesModeList = it },
                onGaugeTap = { pid -> selectedGaugeDetail = GaugeDetailScreenModel(GaugeDetailViewModel(pid)) },
            )
            2 -> FuelStatusScreen(fuelView, Modifier.padding(pad))
            3 -> MilStatusScreen(milView, Modifier.padding(pad))
            else -> DiagnosticsScreen(
                view = dtcView,
                modifier = Modifier.padding(pad),
                onDtcTap = { selectedDtcDetail = it },
            )
        }
    }

    if (showGaugePicker) {
        PidToggleListScreen(
            view = gaugePickerView,
            isMetric = settingsVm.units == MeasurementUnit.Metric,
            onClose = { showGaugePicker = false },
            scope = scope,
        )
    }
    selectedGaugeDetail?.let { detail ->
        GaugeDetailScreen(
            detail = detail,
            isMetric = settingsVm.units == MeasurementUnit.Metric,
            onClose = { selectedGaugeDetail = null },
        )
    }
    selectedDtcDetail?.let { detail ->
        DtcDetailScreen(detail = detail, onClose = { selectedDtcDetail = null })
    }
}

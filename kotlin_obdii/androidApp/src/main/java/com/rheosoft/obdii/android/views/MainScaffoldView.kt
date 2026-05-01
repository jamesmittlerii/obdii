package com.rheosoft.obdii.android.views

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
import com.rheosoft.obdii.views.DiagnosticsView
import com.rheosoft.obdii.views.DtcDetailView
import com.rheosoft.obdii.views.FuelStatusView
import com.rheosoft.obdii.views.GaugeDetailView
import com.rheosoft.obdii.views.MainScaffold
import com.rheosoft.obdii.views.MilStatusView
import com.rheosoft.obdii.views.SettingsView
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

@Composable
@OptIn(ExperimentalMaterial3Api::class)
fun KotlinObdiiApp() {
    val context = LocalContext.current
    val uiPrefs = remember(context) { context.getSharedPreferences("kotlin_obdii_prefs", Context.MODE_PRIVATE) }
    var selected by remember { mutableIntStateOf(uiPrefs.getInt("ui.selectedTab", 0)) }
    var ready by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val settingsVm = remember { SettingsViewModel() }
    val settingsView = remember { SettingsView(settingsVm) }
    val gaugePickerVm = remember { PidToggleListViewModel(DefaultPidStore) }
    val gaugesVm = remember { GaugesViewModel() }
    val fuelView = remember { FuelStatusView(FuelStatusViewModel(), isActive = false) }
    val milView = remember { MilStatusView(MilStatusViewModel(), isActive = false) }
    val dtcView = remember { DiagnosticsView(DiagnosticsViewModel(), isActive = false) }
    var showGaugePicker by remember { mutableStateOf(false) }
    var gaugesModeList by remember { mutableStateOf(uiPrefs.getBoolean("ui.gaugesModeList", false)) }
    var selectedGaugeDetail by remember { mutableStateOf<GaugeDetailView?>(null) }
    var selectedDtcDetail by remember { mutableStateOf<DtcDetailView?>(null) }

    LaunchedEffect(Unit) {
        if (DefaultPidStore.pids.isEmpty()) {
            val pidsFromJson = loadPidsFromJson(context)
            DefaultPidStore.seededPidsProvider = { if (pidsFromJson.isNotEmpty()) pidsFromJson else defaultGaugeSeedPids() }
        }
        runCatching { AppBootstrap.initialize() }
        ready = true
        // Keep first paint responsive: auto-connect runs in background.
        if (ConfigData.autoConnectToOBD) {
            scope.launch {
                runCatching {
                    withTimeoutOrNull(3_000) {
                        OBDConnectionManager.connect()
                    }
                }
            }
        }
    }
    LaunchedEffect(selected) {
        uiPrefs.edit().putInt("ui.selectedTab", selected).apply()
    }
    LaunchedEffect(gaugesModeList) {
        uiPrefs.edit().putBoolean("ui.gaugesModeList", gaugesModeList).apply()
    }

    fuelView.setActive(selected == 2)
    milView.setActive(selected == 3)
    dtcView.setActive(selected == 4)
    gaugesVm.setVisible(selected == 1)
    ObserveChanges(settingsVm)
    ObservePidChanges(gaugePickerVm)

    Scaffold(
        topBar = {
            val title = if (selected == 1 && gaugesModeList) "List" else MainScaffold.destinations[selected]
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
                MainScaffold.destinations.forEachIndexed { idx, label ->
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
                vm = settingsVm,
                modifier = Modifier.padding(pad),
                onOpenGaugePicker = { showGaugePicker = true },
            )
            1 -> DashboardScreen(
                vm = gaugesVm,
                isMetric = settingsVm.units == MeasurementUnit.metric,
                modifier = Modifier.padding(pad),
                listMode = gaugesModeList,
                onModeChanged = { gaugesModeList = it },
                onGaugeTap = { pid -> selectedGaugeDetail = GaugeDetailView(GaugeDetailViewModel(pid)) },
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
            vm = gaugePickerVm,
            isMetric = settingsVm.units == MeasurementUnit.metric,
            onClose = { showGaugePicker = false },
            scope = scope,
        )
    }
    selectedGaugeDetail?.let { detail ->
        GaugeDetailScreen(
            detail = detail,
            isMetric = settingsVm.units == MeasurementUnit.metric,
            onClose = { selectedGaugeDetail = null },
        )
    }
    selectedDtcDetail?.let { detail ->
        DtcDetailScreen(detail = detail, onClose = { selectedDtcDetail = null })
    }
}

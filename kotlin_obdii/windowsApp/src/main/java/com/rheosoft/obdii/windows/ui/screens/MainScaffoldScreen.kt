package com.rheosoft.obdii.windows.ui.screens


import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.LocalGasStation
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Speed
import androidx.compose.material.icons.outlined.Warning
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarDefaults
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rheosoft.obdii.bootstrap.AppBootstrap
import com.rheosoft.obdii.core.ConfigData
import com.rheosoft.obdii.core.DefaultPidStore
import com.rheosoft.obdii.core.MeasurementUnit
import com.rheosoft.obdii.core.OBDConnectionManager
import com.rheosoft.obdii.screenmodels.DashboardScreenModel
import com.rheosoft.obdii.screenmodels.DiagnosticsScreenModel
import com.rheosoft.obdii.screenmodels.DtcDetailScreenModel
import com.rheosoft.obdii.screenmodels.FuelStatusScreenModel
import com.rheosoft.obdii.screenmodels.GaugeDetailScreenModel
import com.rheosoft.obdii.screenmodels.MainScaffoldScreenModel
import com.rheosoft.obdii.screenmodels.MilStatusScreenModel
import com.rheosoft.obdii.screenmodels.PidToggleListScreenModel
import com.rheosoft.obdii.screenmodels.SettingsScreenModel
import com.rheosoft.obdii.viewmodels.DiagnosticsViewModel
import com.rheosoft.obdii.viewmodels.FuelStatusViewModel
import com.rheosoft.obdii.viewmodels.GaugeDetailViewModel
import com.rheosoft.obdii.viewmodels.GaugesViewModel
import com.rheosoft.obdii.viewmodels.MilStatusViewModel
import com.rheosoft.obdii.viewmodels.PidToggleListViewModel
import com.rheosoft.obdii.viewmodels.SettingsViewModel
import com.rheosoft.obdii.windows.bootstrap.WindowsAppInitializer
import com.rheosoft.obdii.windows.generated.resources.Res
import com.rheosoft.obdii.windows.generated.resources.ic_check_engine
import kotlinx.coroutines.launch
import org.jetbrains.compose.resources.painterResource

@Composable
@OptIn(ExperimentalMaterial3Api::class)
fun KotlinObdiiApp(permissionsReady: Boolean = true) {
    val uiPrefs = remember {
        DesktopPreferencesKeyValueStore().also { persistentStore ->
            ConfigData.store = persistentStore
            ConfigData.load()
            DefaultPidStore.store = persistentStore
        }
    }
    var selected by remember { mutableIntStateOf(uiPrefs.getInt("ui.selectedTab") ?: 0) }
    var ready by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val showGaugePicker = remember { mutableStateOf(false) }
    var attemptedAutoConnect by remember { mutableStateOf(false) }
    val settingsVm = remember { SettingsViewModel() }
    val settingsView = remember { SettingsScreenModel(settingsVm) }
    val gaugePickerVm = remember { PidToggleListViewModel(DefaultPidStore) }
    val gaugePickerView = remember { PidToggleListScreenModel(gaugePickerVm) }
    val gaugesVm = remember { GaugesViewModel() }
    val dashboardView = remember {
        DashboardScreenModel(
            gaugesVm,
            ConfigData.gaugesDisplayMode,
        )
    }
    val fuelView = remember { FuelStatusScreenModel(FuelStatusViewModel(), isActive = false) }
    val milView = remember { MilStatusScreenModel(MilStatusViewModel(), isActive = false) }
    val dtcView = remember { DiagnosticsScreenModel(DiagnosticsViewModel(), isActive = false) }
    val selectedGaugeDetail = remember { mutableStateOf<GaugeDetailScreenModel?>(null) }
    val selectedDtcDetail = remember { mutableStateOf<DtcDetailScreenModel?>(null) }

    LaunchedEffect(Unit) {
        if (DefaultPidStore.pids.isEmpty()) {
            val pidsFromJson = loadPidsFromJson()
            DefaultPidStore.seededPidsProvider = { pidsFromJson.ifEmpty { defaultGaugeSeedPids() } }
        }
        runCatching { WindowsAppInitializer.initialize() }
        runCatching { AppBootstrap.initialize() }
        fuelView.setActive(selected == 2)
        milView.setActive(selected == 3)
        dtcView.setActive(selected == 4)
        gaugesVm.setVisible(selected == 1)
        ready = true
    }

    LaunchedEffect(ready, permissionsReady) {
        // Keep first paint responsive: auto-connect runs in background once Android BLE permissions are ready.
        if (ready && permissionsReady && ConfigData.autoConnectToOBD && !attemptedAutoConnect) {
            attemptedAutoConnect = true
            scope.launch {
                runCatching {
                    OBDConnectionManager.connect()
                }
            }
        }
    }

    LaunchedEffect(selected) {
        uiPrefs.putInt("ui.selectedTab", selected)
    }
    LaunchedEffect(selected, ready) {
        if (ready) {
            fuelView.setActive(selected == 2)
            milView.setActive(selected == 3)
            dtcView.setActive(selected == 4)
            gaugesVm.setVisible(selected == 1)
        }
    }

    ObserveChanges(settingsVm)
    ObservePidChanges(gaugePickerVm)

    Scaffold(
        bottomBar = { ObdiiBottomNavigation(selected) { selected = it } },
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
                onOpenGaugePicker = { showGaugePicker.value = true },
            )
            1 -> DashboardScreen(
                view = dashboardView,
                isMetric = settingsVm.units == MeasurementUnit.Metric,
                modifier = Modifier.padding(pad),
                scope = scope,
                onGaugeTap = { pid -> selectedGaugeDetail.value = GaugeDetailScreenModel(GaugeDetailViewModel(pid)) },
            )
            2 -> FuelStatusScreen(fuelView, Modifier.padding(pad))
            3 -> MilStatusScreen(
                milView,
                Modifier.padding(pad),
                onMilSummaryTap = { selected = 4 },
            )
            else -> DiagnosticsScreen(
                view = dtcView,
                modifier = Modifier.padding(pad),
                onDtcTap = { selectedDtcDetail.value = it },
            )
        }
    }

    if (showGaugePicker.value) {
        PidToggleListScreen(
            view = gaugePickerView,
            isMetric = settingsVm.units == MeasurementUnit.Metric,
            onClose = { showGaugePicker.value = false },
            scope = scope,
        )
    }
    selectedGaugeDetail.value?.let { detail ->
        GaugeDetailScreen(
            detail = detail,
            isMetric = settingsVm.units == MeasurementUnit.Metric,
            onClose = { selectedGaugeDetail.value = null },
        )
    }
    selectedDtcDetail.value?.let { detail ->
        DtcDetailScreen(detail = detail, onClose = { selectedDtcDetail.value = null })
    }
}

@Composable
private fun ObdiiBottomNavigation(selected: Int, onSelectedChange: (Int) -> Unit) {
    NavigationBar(
        modifier = Modifier
            .navigationBarsPadding()
            .height(56.dp),
        containerColor = Color(0xFFF1F3F8),
        tonalElevation = 8.dp,
        windowInsets = WindowInsets(0, 0, 0, 0),
    ) {
        MainScaffoldScreenModel.destinations.forEachIndexed { idx, label ->
            NavigationBarItem(
                selected = selected == idx,
                onClick = { onSelectedChange(idx) },
                icon = {
                    if (idx == 3) {
                        Icon(
                            painter = painterResource(Res.drawable.ic_check_engine),
                            contentDescription = label,
                            modifier = Modifier.padding(top = 2.dp).size(28.dp) // Optical alignment
                        )
                    } else {
                        Icon(
                            imageVector = when (idx) {
                                0 -> Icons.Outlined.Settings
                                1 -> Icons.Outlined.Speed
                                2 -> Icons.Outlined.LocalGasStation
                                else -> Icons.Outlined.Build
                            },
                            contentDescription = label,
                            modifier = Modifier.size(28.dp)
                        )
                    }
                },
                label = { Text(label, fontSize = 11.sp) },
            )
        }
    }
}

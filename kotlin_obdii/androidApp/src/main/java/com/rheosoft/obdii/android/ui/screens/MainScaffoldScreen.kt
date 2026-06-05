package com.rheosoft.obdii.android.ui.screens

import android.content.Context
import androidx.core.content.edit
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Build
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
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rheosoft.obdii.android.R
import com.rheosoft.obdii.bootstrap.AppBootstrap
import com.rheosoft.obdii.core.ConfigData
import com.rheosoft.obdii.core.ConnectionType
import com.rheosoft.obdii.core.DefaultPidStore
import com.rheosoft.obdii.core.MeasurementUnit
import com.rheosoft.obdii.core.OBDConnectionManager
import com.rheosoft.obdii.screenmodels.OnboardingScreenModel
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
import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.viewmodels.SettingsViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

@Composable
@OptIn(ExperimentalMaterial3Api::class)
fun KotlinObdiiApp(permissionsReady: Boolean = true) {
    val context = LocalContext.current
    val uiPrefs = remember(context) { context.getSharedPreferences("kotlin_obdii_prefs", Context.MODE_PRIVATE) }
    var selected by remember { mutableIntStateOf(uiPrefs.getInt("ui.selectedTab", 0)) }
    var ready by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val showGaugePicker = remember { mutableStateOf(false) }
    var attemptedAutoConnect by remember { mutableStateOf(false) }
    var showOnboarding by remember { mutableStateOf(!ConfigData.hasCompletedOnboarding) }
    var onboardingPageIndex by remember { mutableIntStateOf(0) }
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
            val pidsFromJson = loadPidsFromJson(context)
            DefaultPidStore.seededPidsProvider = { pidsFromJson.ifEmpty { defaultGaugeSeedPids() } }
        }
        runCatching { AppBootstrap.initialize() }
        fuelView.setActive(selected == 2)
        milView.setActive(selected == 3)
        dtcView.setActive(selected == 4)
        gaugesVm.setVisible(selected == 1)
        ready = true
    }

    LaunchedEffect(ready, permissionsReady) {
        // Keep first paint responsive: auto-connect runs in background once Android BLE permissions are ready.
        if (ready && permissionsReady && ConfigData.autoConnectToOBD &&
            ConfigData.hasCompletedOnboarding && !attemptedAutoConnect
        ) {
            attemptedAutoConnect = true
            scope.launch {
                runCatching {
                    OBDConnectionManager.connect()
                }
            }
        }
    }

    LaunchedEffect(selected) {
        uiPrefs.edit { putInt("ui.selectedTab", selected) }
    }
    LaunchedEffect(selected, ready) {
        if (ready) {
            fuelView.setActive(selected == 2)
            milView.setActive(selected == 3)
            dtcView.setActive(selected == 4)
            gaugesVm.setVisible(selected == 1)
        }
    }

    LaunchedEffect(showOnboarding, onboardingPageIndex) {
        if (!showOnboarding) {
            showGaugePicker.value = false
            return@LaunchedEffect
        }
        if (OnboardingScreenModel.showGaugePicker(onboardingPageIndex)) {
            selected = OnboardingScreenModel.SETTINGS_TAB_INDEX
            showGaugePicker.value = true
        } else {
            showGaugePicker.value = false
            OnboardingScreenModel.previewTabIndex(onboardingPageIndex)?.let { selected = it }
        }
    }

    ObserveChanges(settingsVm)
    ObservePidChanges(gaugePickerVm)

    val onboardingNavHighlight = if (showOnboarding) {
        OnboardingScreenModel.highlightedNavTab(onboardingPageIndex)
    } else {
        null
    }

    KotlinObdiiAppScaffold(
        ready = ready,
        selected = selected,
        showOnboarding = showOnboarding,
        onboardingNavHighlight = onboardingNavHighlight,
        onSelectedChange = { selected = it },
        settingsView = settingsView,
        dashboardView = dashboardView,
        fuelView = fuelView,
        milView = milView,
        dtcView = dtcView,
        settingsVm = settingsVm,
        scope = scope,
        onOpenGaugePicker = { showGaugePicker.value = true },
        onShowIntroAgain = {
            onboardingPageIndex = 0
            showOnboarding = true
        },
        onGaugeTap = { pid ->
            selectedGaugeDetail.value = GaugeDetailScreenModel(GaugeDetailViewModel(pid))
        },
        onMilSummaryTap = { selected = 4 },
        onDtcTap = { selectedDtcDetail.value = it },
    )

    KotlinObdiiAppOverlays(
        ready = ready,
        showOnboarding = showOnboarding,
        showGaugePicker = showGaugePicker.value,
        onboardingPageIndex = onboardingPageIndex,
        gaugePickerView = gaugePickerView,
        settingsVm = settingsVm,
        scope = scope,
        selectedGaugeDetail = selectedGaugeDetail.value,
        selectedDtcDetail = selectedDtcDetail.value,
        onOnboardingPageIndexChange = { onboardingPageIndex = it },
        onOnboardingComplete = { startDemo ->
            ConfigData.hasCompletedOnboarding = true
            showOnboarding = false
            showGaugePicker.value = false
            if (startDemo) {
                settingsVm.onConnectionTypeChanged(ConnectionType.demo)
                selected = OnboardingScreenModel.GAUGES_TAB_INDEX
                scope.launch { runCatching { OBDConnectionManager.connect() } }
            }
        },
        onGaugePickerClose = { showGaugePicker.value = false },
        onGaugeDetailClose = { selectedGaugeDetail.value = null },
        onDtcDetailClose = { selectedDtcDetail.value = null },
    )
}

@Composable
private fun KotlinObdiiAppScaffold(
    ready: Boolean,
    selected: Int,
    showOnboarding: Boolean,
    onboardingNavHighlight: Int?,
    onSelectedChange: (Int) -> Unit,
    settingsView: SettingsScreenModel,
    dashboardView: DashboardScreenModel,
    fuelView: FuelStatusScreenModel,
    milView: MilStatusScreenModel,
    dtcView: DiagnosticsScreenModel,
    settingsVm: SettingsViewModel,
    scope: CoroutineScope,
    onOpenGaugePicker: () -> Unit,
    onShowIntroAgain: () -> Unit,
    onGaugeTap: (ObdiiPid) -> Unit,
    onMilSummaryTap: () -> Unit,
    onDtcTap: (DtcDetailScreenModel) -> Unit,
) {
    Scaffold(
        bottomBar = {
            Box {
                ObdiiBottomNavigation(
                    selected = selected,
                    onSelectedChange = { if (!showOnboarding) onSelectedChange(it) },
                )
                if (showOnboarding) {
                    OnboardingNavHighlight(onboardingNavHighlight)
                }
            }
        },
        containerColor = AppBackground,
    ) { pad ->
        if (!ready) {
            CenterText("Loading...", Modifier.padding(pad))
            return@Scaffold
        }
        Box(Modifier.padding(pad).fillMaxSize()) {
            MainScaffoldTabContent(
                selected = selected,
                showOnboarding = showOnboarding,
                settingsView = settingsView,
                dashboardView = dashboardView,
                fuelView = fuelView,
                milView = milView,
                dtcView = dtcView,
                settingsVm = settingsVm,
                scope = scope,
                onOpenGaugePicker = onOpenGaugePicker,
                onShowIntroAgain = onShowIntroAgain,
                onGaugeTap = onGaugeTap,
                onMilSummaryTap = onMilSummaryTap,
                onDtcTap = onDtcTap,
            )
        }
    }
}

@Composable
private fun MainScaffoldTabContent(
    selected: Int,
    showOnboarding: Boolean,
    settingsView: SettingsScreenModel,
    dashboardView: DashboardScreenModel,
    fuelView: FuelStatusScreenModel,
    milView: MilStatusScreenModel,
    dtcView: DiagnosticsScreenModel,
    settingsVm: SettingsViewModel,
    scope: CoroutineScope,
    onOpenGaugePicker: () -> Unit,
    onShowIntroAgain: () -> Unit,
    onGaugeTap: (ObdiiPid) -> Unit,
    onMilSummaryTap: () -> Unit,
    onDtcTap: (DtcDetailScreenModel) -> Unit,
) {
    when (selected) {
        0 -> SettingsScreen(
            view = settingsView,
            modifier = Modifier.fillMaxSize(),
            onOpenGaugePicker = { if (!showOnboarding) onOpenGaugePicker() },
            onShowIntroAgain = onShowIntroAgain,
        )
        1 -> DashboardScreen(
            view = dashboardView,
            isMetric = settingsVm.units == MeasurementUnit.Metric,
            modifier = Modifier.fillMaxSize(),
            scope = scope,
            onGaugeTap = { pid -> if (!showOnboarding) onGaugeTap(pid) },
        )
        2 -> FuelStatusScreen(fuelView, Modifier.fillMaxSize())
        3 -> MilStatusScreen(
            milView,
            Modifier.fillMaxSize(),
            onMilSummaryTap = { if (!showOnboarding) onMilSummaryTap() },
        )
        else -> DiagnosticsScreen(
            view = dtcView,
            modifier = Modifier.fillMaxSize(),
            onDtcTap = { if (!showOnboarding) onDtcTap(it) },
        )
    }
}

@Composable
private fun KotlinObdiiAppOverlays(
    ready: Boolean,
    showOnboarding: Boolean,
    showGaugePicker: Boolean,
    onboardingPageIndex: Int,
    gaugePickerView: PidToggleListScreenModel,
    settingsVm: SettingsViewModel,
    scope: CoroutineScope,
    selectedGaugeDetail: GaugeDetailScreenModel?,
    selectedDtcDetail: DtcDetailScreenModel?,
    onOnboardingPageIndexChange: (Int) -> Unit,
    onOnboardingComplete: (Boolean) -> Unit,
    onGaugePickerClose: () -> Unit,
    onGaugeDetailClose: () -> Unit,
    onDtcDetailClose: () -> Unit,
) {
    if (showGaugePicker) {
        PidToggleListScreen(
            view = gaugePickerView,
            isMetric = settingsVm.units == MeasurementUnit.Metric,
            onClose = { if (!showOnboarding) onGaugePickerClose() },
            scope = scope,
        )
    }

    if (ready && showOnboarding) {
        OnboardingContentScrim(
            pageIndex = onboardingPageIndex,
            onPageIndexChange = onOnboardingPageIndexChange,
            bottomInset = 80.dp,
            onComplete = onOnboardingComplete,
        )
    }

    selectedGaugeDetail?.let { detail ->
        GaugeDetailScreen(
            detail = detail,
            isMetric = settingsVm.units == MeasurementUnit.Metric,
            onClose = onGaugeDetailClose,
        )
    }
    selectedDtcDetail?.let { detail ->
        DtcDetailScreen(detail = detail, onClose = onDtcDetailClose)
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
                            painter = painterResource(id = R.drawable.ic_check_engine),
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

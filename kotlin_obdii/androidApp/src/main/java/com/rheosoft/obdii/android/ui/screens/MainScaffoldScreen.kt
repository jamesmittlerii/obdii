package com.rheosoft.obdii.android.ui.screens

import android.content.Context
import android.content.SharedPreferences
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

private data class KotlinObdiiTabViews(
    val settings: SettingsScreenModel,
    val dashboard: DashboardScreenModel,
    val fuel: FuelStatusScreenModel,
    val mil: MilStatusScreenModel,
    val dtc: DiagnosticsScreenModel,
    val settingsVm: SettingsViewModel,
    val scope: CoroutineScope,
)

private data class KotlinObdiiTabActions(
    val onOpenGaugePicker: () -> Unit,
    val onShowIntroAgain: () -> Unit,
    val onGaugeTap: (ObdiiPid) -> Unit,
    val onMilSummaryTap: () -> Unit,
    val onDtcTap: (DtcDetailScreenModel) -> Unit,
)

private data class KotlinObdiiScaffoldUiState(
    val ready: Boolean,
    val selected: Int,
    val showOnboarding: Boolean,
    val onboardingNavHighlight: Int?,
)

private data class KotlinObdiiOverlayUiState(
    val ready: Boolean,
    val showOnboarding: Boolean,
    val showGaugePicker: Boolean,
    val onboardingPageIndex: Int,
    val selectedGaugeDetail: GaugeDetailScreenModel?,
    val selectedDtcDetail: DtcDetailScreenModel?,
)

private data class KotlinObdiiOverlayActions(
    val onOnboardingPageIndexChange: (Int) -> Unit,
    val onOnboardingComplete: (Boolean) -> Unit,
    val onGaugePickerClose: () -> Unit,
    val onGaugeDetailClose: () -> Unit,
    val onDtcDetailClose: () -> Unit,
)

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

    val tabViews = KotlinObdiiTabViews(
        settings = settingsView,
        dashboard = dashboardView,
        fuel = fuelView,
        mil = milView,
        dtc = dtcView,
        settingsVm = settingsVm,
        scope = scope,
    )
    val tabActions = KotlinObdiiTabActions(
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

    KotlinObdiiBootstrapEffect(
        context = context,
        selected = selected,
        tabViews = tabViews,
        gaugesVm = gaugesVm,
        onReady = { ready = true },
    )
    KotlinObdiiAutoConnectEffect(
        ready = ready,
        permissionsReady = permissionsReady,
        attemptedAutoConnect = attemptedAutoConnect,
        onAttemptedAutoConnect = { attemptedAutoConnect = true },
        scope = scope,
    )
    KotlinObdiiSelectedTabEffects(
        uiPrefs = uiPrefs,
        selected = selected,
        ready = ready,
        tabViews = tabViews,
        gaugesVm = gaugesVm,
    )
    KotlinObdiiOnboardingTabEffect(
        showOnboarding = showOnboarding,
        onboardingPageIndex = onboardingPageIndex,
        onShowGaugePickerChange = { showGaugePicker.value = it },
        onSelectedChange = { selected = it },
    )

    ObserveChanges(settingsVm)
    ObservePidChanges(gaugePickerVm)

    KotlinObdiiAppScaffold(
        uiState = KotlinObdiiScaffoldUiState(
            ready = ready,
            selected = selected,
            showOnboarding = showOnboarding,
            onboardingNavHighlight = if (showOnboarding) {
                OnboardingScreenModel.highlightedNavTab(onboardingPageIndex)
            } else {
                null
            },
        ),
        tabViews = tabViews,
        tabActions = tabActions,
        onSelectedChange = { selected = it },
    )

    KotlinObdiiAppOverlays(
        uiState = KotlinObdiiOverlayUiState(
            ready = ready,
            showOnboarding = showOnboarding,
            showGaugePicker = showGaugePicker.value,
            onboardingPageIndex = onboardingPageIndex,
            selectedGaugeDetail = selectedGaugeDetail.value,
            selectedDtcDetail = selectedDtcDetail.value,
        ),
        gaugePickerView = gaugePickerView,
        settingsVm = settingsVm,
        scope = scope,
        actions = KotlinObdiiOverlayActions(
            onOnboardingPageIndexChange = { onboardingPageIndex = it },
            onOnboardingComplete = { startDemo ->
                completeKotlinObdiiOnboarding(
                    startDemo = startDemo,
                    settingsVm = settingsVm,
                    scope = scope,
                    onShowOnboardingChange = { showOnboarding = it },
                    onShowGaugePickerChange = { showGaugePicker.value = it },
                    onSelectedChange = { selected = it },
                )
            },
            onGaugePickerClose = { showGaugePicker.value = false },
            onGaugeDetailClose = { selectedGaugeDetail.value = null },
            onDtcDetailClose = { selectedDtcDetail.value = null },
        ),
    )
}

@Composable
private fun KotlinObdiiBootstrapEffect(
    context: Context,
    selected: Int,
    tabViews: KotlinObdiiTabViews,
    gaugesVm: GaugesViewModel,
    onReady: () -> Unit,
) {
    LaunchedEffect(Unit) {
        if (DefaultPidStore.pids.isEmpty()) {
            val pidsFromJson = loadPidsFromJson(context)
            DefaultPidStore.seededPidsProvider = { pidsFromJson.ifEmpty { defaultGaugeSeedPids() } }
        }
        runCatching { AppBootstrap.initialize() }
        syncKotlinObdiiTabVisibility(selected, tabViews, gaugesVm)
        onReady()
    }
}

@Composable
private fun KotlinObdiiAutoConnectEffect(
    ready: Boolean,
    permissionsReady: Boolean,
    attemptedAutoConnect: Boolean,
    onAttemptedAutoConnect: () -> Unit,
    scope: CoroutineScope,
) {
    LaunchedEffect(ready, permissionsReady) {
        // Keep first paint responsive: auto-connect runs in background once Android BLE permissions are ready.
        if (ready && permissionsReady && ConfigData.autoConnectToOBD &&
            ConfigData.hasCompletedOnboarding && !attemptedAutoConnect
        ) {
            onAttemptedAutoConnect()
            scope.launch {
                runCatching {
                    OBDConnectionManager.connect()
                }
            }
        }
    }
}

@Composable
private fun KotlinObdiiSelectedTabEffects(
    uiPrefs: SharedPreferences,
    selected: Int,
    ready: Boolean,
    tabViews: KotlinObdiiTabViews,
    gaugesVm: GaugesViewModel,
) {
    LaunchedEffect(selected) {
        uiPrefs.edit { putInt("ui.selectedTab", selected) }
    }
    LaunchedEffect(selected, ready) {
        if (ready) {
            syncKotlinObdiiTabVisibility(selected, tabViews, gaugesVm)
        }
    }
}

@Composable
private fun KotlinObdiiOnboardingTabEffect(
    showOnboarding: Boolean,
    onboardingPageIndex: Int,
    onShowGaugePickerChange: (Boolean) -> Unit,
    onSelectedChange: (Int) -> Unit,
) {
    LaunchedEffect(showOnboarding, onboardingPageIndex) {
        if (!showOnboarding) {
            onShowGaugePickerChange(false)
            return@LaunchedEffect
        }
        if (OnboardingScreenModel.showGaugePicker(onboardingPageIndex)) {
            onSelectedChange(OnboardingScreenModel.SETTINGS_TAB_INDEX)
            onShowGaugePickerChange(true)
        } else {
            onShowGaugePickerChange(false)
            OnboardingScreenModel.previewTabIndex(onboardingPageIndex)?.let { onSelectedChange(it) }
        }
    }
}

private fun syncKotlinObdiiTabVisibility(
    selected: Int,
    tabViews: KotlinObdiiTabViews,
    gaugesVm: GaugesViewModel,
) {
    tabViews.fuel.setActive(selected == 2)
    tabViews.mil.setActive(selected == 3)
    tabViews.dtc.setActive(selected == 4)
    gaugesVm.setVisible(selected == 1)
}

private fun completeKotlinObdiiOnboarding(
    startDemo: Boolean,
    settingsVm: SettingsViewModel,
    scope: CoroutineScope,
    onShowOnboardingChange: (Boolean) -> Unit,
    onShowGaugePickerChange: (Boolean) -> Unit,
    onSelectedChange: (Int) -> Unit,
) {
    ConfigData.hasCompletedOnboarding = true
    onShowOnboardingChange(false)
    onShowGaugePickerChange(false)
    if (!startDemo) return
    settingsVm.onConnectionTypeChanged(ConnectionType.demo)
    onSelectedChange(OnboardingScreenModel.GAUGES_TAB_INDEX)
    scope.launch { runCatching { OBDConnectionManager.connect() } }
}

@Composable
private fun KotlinObdiiAppScaffold(
    uiState: KotlinObdiiScaffoldUiState,
    tabViews: KotlinObdiiTabViews,
    tabActions: KotlinObdiiTabActions,
    onSelectedChange: (Int) -> Unit,
) {
    Scaffold(
        bottomBar = {
            Box {
                ObdiiBottomNavigation(
                    selected = uiState.selected,
                    onSelectedChange = { if (!uiState.showOnboarding) onSelectedChange(it) },
                )
                if (uiState.showOnboarding) {
                    OnboardingNavHighlight(uiState.onboardingNavHighlight)
                }
            }
        },
        containerColor = AppBackground,
    ) { pad ->
        if (!uiState.ready) {
            CenterText("Loading...", Modifier.padding(pad))
            return@Scaffold
        }
        Box(Modifier.padding(pad).fillMaxSize()) {
            MainScaffoldTabContent(
                selected = uiState.selected,
                showOnboarding = uiState.showOnboarding,
                tabViews = tabViews,
                tabActions = tabActions,
            )
        }
    }
}

@Composable
private fun MainScaffoldTabContent(
    selected: Int,
    showOnboarding: Boolean,
    tabViews: KotlinObdiiTabViews,
    tabActions: KotlinObdiiTabActions,
) {
    when (selected) {
        0 -> SettingsScreen(
            view = tabViews.settings,
            modifier = Modifier.fillMaxSize(),
            onOpenGaugePicker = { if (!showOnboarding) tabActions.onOpenGaugePicker() },
            onShowIntroAgain = tabActions.onShowIntroAgain,
        )
        1 -> DashboardScreen(
            view = tabViews.dashboard,
            isMetric = tabViews.settingsVm.units == MeasurementUnit.Metric,
            modifier = Modifier.fillMaxSize(),
            scope = tabViews.scope,
            onGaugeTap = { pid -> if (!showOnboarding) tabActions.onGaugeTap(pid) },
        )
        2 -> FuelStatusScreen(tabViews.fuel, Modifier.fillMaxSize())
        3 -> MilStatusScreen(
            tabViews.mil,
            Modifier.fillMaxSize(),
            onMilSummaryTap = { if (!showOnboarding) tabActions.onMilSummaryTap() },
        )
        else -> DiagnosticsScreen(
            view = tabViews.dtc,
            modifier = Modifier.fillMaxSize(),
            onDtcTap = { if (!showOnboarding) tabActions.onDtcTap(it) },
        )
    }
}

@Composable
private fun KotlinObdiiAppOverlays(
    uiState: KotlinObdiiOverlayUiState,
    gaugePickerView: PidToggleListScreenModel,
    settingsVm: SettingsViewModel,
    scope: CoroutineScope,
    actions: KotlinObdiiOverlayActions,
) {
    if (uiState.showGaugePicker) {
        PidToggleListScreen(
            view = gaugePickerView,
            isMetric = settingsVm.units == MeasurementUnit.Metric,
            onClose = { if (!uiState.showOnboarding) actions.onGaugePickerClose() },
            scope = scope,
        )
    }

    if (uiState.ready && uiState.showOnboarding) {
        OnboardingContentScrim(
            pageIndex = uiState.onboardingPageIndex,
            onPageIndexChange = actions.onOnboardingPageIndexChange,
            bottomInset = 80.dp,
            onComplete = actions.onOnboardingComplete,
        )
    }

    uiState.selectedGaugeDetail?.let { detail ->
        GaugeDetailScreen(
            detail = detail,
            isMetric = settingsVm.units == MeasurementUnit.Metric,
            onClose = actions.onGaugeDetailClose,
        )
    }
    uiState.selectedDtcDetail?.let { detail ->
        DtcDetailScreen(detail = detail, onClose = actions.onDtcDetailClose)
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

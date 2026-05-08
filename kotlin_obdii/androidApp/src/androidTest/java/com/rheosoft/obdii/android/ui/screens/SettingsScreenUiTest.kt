package com.rheosoft.obdii.android.ui.screens

import androidx.compose.ui.Modifier
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.rheosoft.obdii.core.*
import com.rheosoft.obdii.screenmodels.SettingsScreenModel
import com.rheosoft.obdii.viewmodels.SettingsViewModel
import com.rheosoft.obdii.core.DEFAULT_WIFI_HOST
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.junit.Rule
import org.junit.Test

private class MockSettingsConfig : SettingsConfigProviding {
    override var wifiHost: String = DEFAULT_WIFI_HOST
    override var wifiPort: Int = 35000
    override var autoConnectToOBD: Boolean = true
    
    private val _connFlow = MutableStateFlow(ConnectionType.bluetooth)
    override var connectionType: ConnectionType
        get() = _connFlow.value
        set(value) { _connFlow.value = value }
    override val connectionTypeStream: StateFlow<ConnectionType> = _connFlow

    override var gaugesDisplayMode: GaugesDisplayMode = GaugesDisplayMode.gauges
    private val _modeFlow = MutableStateFlow(GaugesDisplayMode.gauges)
    override val gaugesDisplayModeStream: StateFlow<GaugesDisplayMode> = _modeFlow
    
    private val _unitsFlow = MutableStateFlow(MeasurementUnit.Metric)
    override val units: MeasurementUnit get() = _unitsFlow.value
    override val unitsStream: StateFlow<MeasurementUnit> = _unitsFlow

    override fun setUnits(units: MeasurementUnit) { _unitsFlow.value = units }
    fun pushUnits(u: MeasurementUnit) { _unitsFlow.value = u }
    fun pushConnectionType(t: ConnectionType) { _connFlow.value = t }
}

private class MockConn : OBDConnectionControlling {
    private val flow = MutableStateFlow(OBDConnectionState.disconnected)
    override var connectionState: OBDConnectionState = OBDConnectionState.disconnected
        set(value) {
            field = value
            flow.value = value
        }
    override val connectionStateStream: StateFlow<OBDConnectionState> = flow
    override fun updateConnectionDetails() {}
    override suspend fun connect() {}
    override fun disconnect() {}
    fun pushState(s: OBDConnectionState) { connectionState = s }
}

class SettingsScreenUiTest {
    @get:Rule
    val composeRule = createComposeRule()

    private fun setupScreen(
        config: MockSettingsConfig = MockSettingsConfig(),
        conn: MockConn = MockConn()
    ): SettingsViewModel {
        val vm = SettingsViewModel(config, conn)
        val screenModel = SettingsScreenModel(vm)
        composeRule.setContent {
            SettingsScreen(
                view = screenModel,
                modifier = Modifier,
                onOpenGaugePicker = {}
            )
        }
        return vm
    }

    @Test
    fun testRendersPrimarySettingsSections() {
        setupScreen()
        
        composeRule.onNodeWithText("Units").assertIsDisplayed()
        composeRule.onNodeWithText("Connection").assertIsDisplayed()
        composeRule.onNodeWithText("Diagnostics").assertIsDisplayed()
        composeRule.onNodeWithText("About").assertIsDisplayed()
        composeRule.onNodeWithText("Gauges").assertIsDisplayed()
    }

    @Test
    fun testShowsWiFiConnectionDetailsWhenConnectionTypeIsWifi() {
        val config = MockSettingsConfig().apply { pushConnectionType(ConnectionType.wifi) }
        setupScreen(config = config)

        composeRule.onNodeWithText("Connection details").assertIsDisplayed()
        composeRule.onNodeWithText("Host").assertIsDisplayed()
        composeRule.onNodeWithText("Port").assertIsDisplayed()
    }

    @Test
    fun testHidesWiFiConnectionDetailsForBluetoothMode() {
        val config = MockSettingsConfig().apply { pushConnectionType(ConnectionType.bluetooth) }
        setupScreen(config = config)

        composeRule.onNodeWithText("Connection details").assertDoesNotExist()
    }

    @Test
    fun testConnectButtonLabelReflectsDisconnectedState() {
        val conn = MockConn().apply { pushState(OBDConnectionState.disconnected) }
        setupScreen(conn = conn)

        composeRule.onNodeWithText("Connect").assertIsDisplayed()
    }

    @Test
    fun testConnectButtonLabelReflectsConnectedState() {
        val conn = MockConn().apply { pushState(OBDConnectionState.connected) }
        setupScreen(conn = conn)

        composeRule.onNodeWithText("Disconnect").assertIsDisplayed()
    }

    @Test
    fun testAutoConnectSwitchIsRendered() {
        setupScreen()
        composeRule.onNodeWithText("Automatically Connect").assertIsDisplayed()
        composeRule.onNode(isToggleable()).assertExists()
    }

    @Test
    fun testUnitsSegmentLabelsRender() {
        setupScreen()
        composeRule.onNodeWithText("Metric").assertIsDisplayed()
        composeRule.onNodeWithText("Imperial").assertIsDisplayed()
    }

    @Test
    fun testConnectionTypeRowRenders() {
        setupScreen()
        composeRule.onNodeWithText("Type").assertIsDisplayed()
    }

    @Test
    fun testDiagnosticsSectionShowsShareLogsAction() {
        setupScreen()
        composeRule.onNodeWithText("Share Logs").assertIsDisplayed()
    }
}

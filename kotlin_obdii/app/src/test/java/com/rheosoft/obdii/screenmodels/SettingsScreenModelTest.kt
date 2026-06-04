package com.rheosoft.obdii.screenmodels

import com.rheosoft.obdii.core.ConnectionType
import com.rheosoft.obdii.core.GaugesDisplayMode
import com.rheosoft.obdii.core.MeasurementUnit
import com.rheosoft.obdii.core.OBDConnectionControlling
import com.rheosoft.obdii.core.OBDConnectionState
import com.rheosoft.obdii.core.SettingsConfigProviding
import com.rheosoft.obdii.core.DEFAULT_WIFI_HOST
import com.rheosoft.obdii.viewmodels.SettingsViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

private class MockSettingsConfig : SettingsConfigProviding {
    override var wifiHost: String = DEFAULT_WIFI_HOST
    override var wifiPort: Int = 35000
    override var autoConnectToOBD: Boolean = true

    private val connectionTypeFlowMutable = MutableStateFlow(ConnectionType.bluetooth)
    override var connectionType: ConnectionType
        get() = connectionTypeFlowMutable.value
        set(value) { connectionTypeFlowMutable.value = value }
    override val connectionTypeStream: StateFlow<ConnectionType> = connectionTypeFlowMutable

    override var gaugesDisplayMode: GaugesDisplayMode = GaugesDisplayMode.gauges
    override val gaugesDisplayModeStream: StateFlow<GaugesDisplayMode> = MutableStateFlow(GaugesDisplayMode.gauges)

    private val unitsFlowMutable = MutableStateFlow(MeasurementUnit.Metric)
    override val units: MeasurementUnit
        get() = unitsFlowMutable.value
    override val unitsStream: StateFlow<MeasurementUnit> = unitsFlowMutable

    override fun setUnits(units: MeasurementUnit) {
        unitsFlowMutable.value = units
    }
}

private class MockConn(private val initialState: OBDConnectionState) : OBDConnectionControlling {
    private val state = MutableStateFlow(initialState)
    override val connectionState: OBDConnectionState
        get() = state.value
    override val connectionStateStream: StateFlow<OBDConnectionState> = state
    override fun updateConnectionDetails() {}
    override suspend fun connect() {}
    override fun disconnect() {}
}

class SettingsViewTest {
    @Test
    fun `renders primary settings sections`() {
        val view = SettingsScreenModel(
            SettingsViewModel(
                config = MockSettingsConfig(),
                connection = MockConn(OBDConnectionState.disconnected),
            ),
        )
        assertEquals("Settings", view.title)
        assertTrue(view.sectionHeaders.contains("Units"))
        assertTrue(view.sectionHeaders.contains("Connection"))
        assertTrue(view.sectionHeaders.contains("Diagnostics"))
        assertTrue(view.hasGaugesNavigationRow)
    }

    @Test
    fun `shows wifi details only in wifi mode`() {
        val wifiConfig = MockSettingsConfig().apply { connectionType = ConnectionType.wifi }
        val wifiView = SettingsScreenModel(SettingsViewModel(wifiConfig, MockConn(OBDConnectionState.disconnected)))
        assertTrue(wifiView.showsWifiDetails)
        assertTrue(wifiView.sectionHeaders.contains("Connection details"))

        val btConfig = MockSettingsConfig().apply { connectionType = ConnectionType.bluetooth }
        val btView = SettingsScreenModel(SettingsViewModel(btConfig, MockConn(OBDConnectionState.disconnected)))
        assertFalse(btView.showsWifiDetails)
    }

    @Test
    fun `connect button labels reflect connection state`() {
        val disconnected = SettingsScreenModel(
            SettingsViewModel(MockSettingsConfig(), MockConn(OBDConnectionState.disconnected)),
        )
        assertEquals("Connect", disconnected.connectButtonLabel)

        val connected = SettingsScreenModel(
            SettingsViewModel(MockSettingsConfig(), MockConn(OBDConnectionState.connected)),
        )
        assertEquals("Disconnect", connected.connectButtonLabel)
    }

    @Test
    fun `connect button label treats failed as connect and in progress states as connecting`() {
        val failed = SettingsScreenModel(
            SettingsViewModel(MockSettingsConfig(), MockConn(OBDConnectionState.failed)),
        )
        val connecting = SettingsScreenModel(
            SettingsViewModel(MockSettingsConfig(), MockConn(OBDConnectionState.connecting)),
        )
        val adapter = SettingsScreenModel(
            SettingsViewModel(MockSettingsConfig(), MockConn(OBDConnectionState.connectedToAdapter)),
        )
        val setup = SettingsScreenModel(
            SettingsViewModel(MockSettingsConfig(), MockConn(OBDConnectionState.settingUpVehicle)),
        )

        assertEquals("Connect", failed.connectButtonLabel)
        assertEquals("Connecting...", connecting.connectButtonLabel)
        assertEquals("Connecting...", adapter.connectButtonLabel)
        assertEquals("Connecting...", setup.connectButtonLabel)
    }

    @Test
    fun `status labels reflect every connection state`() {
        val expectations = mapOf(
            OBDConnectionState.disconnected to "Disconnected",
            OBDConnectionState.connecting to "Connecting...",
            OBDConnectionState.connectedToAdapter to "Connected to Adapter...",
            OBDConnectionState.settingUpVehicle to "Setting up vehicle...",
            OBDConnectionState.connected to "Connected",
            OBDConnectionState.failed to "Failed",
        )

        expectations.forEach { (state, label) ->
            val view = SettingsScreenModel(
                SettingsViewModel(MockSettingsConfig(), MockConn(state)),
            )
            assertEquals(label, view.statusLabel)
        }
    }

    @Test
    fun `units and diagnostics labels are preserved`() {
        val view = SettingsScreenModel(
            SettingsViewModel(MockSettingsConfig(), MockConn(OBDConnectionState.disconnected)),
        )
        assertEquals(listOf("Metric", "Imperial"), view.unitsLabels)
        assertEquals("Share Logs", view.diagnosticsActionLabel)
        assertEquals("Show intro again", view.showIntroAgainLabel)
    }
}

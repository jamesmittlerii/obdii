package com.rheosoft.obdii.views

import com.rheosoft.obdii.core.ConnectionType
import com.rheosoft.obdii.core.MeasurementUnit
import com.rheosoft.obdii.core.OBDConnectionControlling
import com.rheosoft.obdii.core.OBDConnectionState
import com.rheosoft.obdii.core.SettingsConfigProviding
import com.rheosoft.obdii.viewmodels.SettingsViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

private class MockSettingsConfig : SettingsConfigProviding {
    override var wifiHost: String = "192.168.0.10"
    override var wifiPort: Int = 35000
    override var autoConnectToOBD: Boolean = true
    override var connectionType: ConnectionType = ConnectionType.bluetooth
    private val unitsFlowMutable = MutableStateFlow(MeasurementUnit.metric)
    override val units: MeasurementUnit
        get() = unitsFlowMutable.value
    override val unitsStream: StateFlow<MeasurementUnit> = unitsFlowMutable
    override val connectionTypeStream: StateFlow<ConnectionType> = MutableStateFlow(connectionType)
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
        val view = SettingsView(
            SettingsViewModel(
                config = MockSettingsConfig(),
                connection = MockConn(OBDConnectionState.disconnected),
            ),
        )
        assertEquals("Settings", view.title)
        assertTrue(view.sectionHeaders.contains("UNITS"))
        assertTrue(view.sectionHeaders.contains("CONNECTION"))
        assertTrue(view.sectionHeaders.contains("DIAGNOSTICS"))
        assertTrue(view.hasGaugesNavigationRow)
    }

    @Test
    fun `shows wifi details only in wifi mode`() {
        val wifiConfig = MockSettingsConfig().apply { connectionType = ConnectionType.wifi }
        val wifiView = SettingsView(SettingsViewModel(wifiConfig, MockConn(OBDConnectionState.disconnected)))
        assertTrue(wifiView.showsWifiDetails)
        assertTrue(wifiView.sectionHeaders.contains("CONNECTION DETAILS"))

        val btConfig = MockSettingsConfig().apply { connectionType = ConnectionType.bluetooth }
        val btView = SettingsView(SettingsViewModel(btConfig, MockConn(OBDConnectionState.disconnected)))
        assertFalse(btView.showsWifiDetails)
    }

    @Test
    fun `connect button labels reflect connection state`() {
        val disconnected = SettingsView(
            SettingsViewModel(MockSettingsConfig(), MockConn(OBDConnectionState.disconnected)),
        )
        assertEquals("Connect", disconnected.connectButtonLabel)

        val connected = SettingsView(
            SettingsViewModel(MockSettingsConfig(), MockConn(OBDConnectionState.connected)),
        )
        assertEquals("Disconnect", connected.connectButtonLabel)
    }

    @Test
    fun `units and diagnostics labels are preserved`() {
        val view = SettingsView(
            SettingsViewModel(MockSettingsConfig(), MockConn(OBDConnectionState.disconnected)),
        )
        assertEquals(listOf("Metric", "Imperial"), view.unitsLabels)
        assertEquals("Share Logs", view.diagnosticsActionLabel)
    }
}

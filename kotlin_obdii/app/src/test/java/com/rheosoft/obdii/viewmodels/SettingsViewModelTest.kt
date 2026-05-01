package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.ConnectionType
import com.rheosoft.obdii.core.MeasurementUnit
import com.rheosoft.obdii.core.OBDConnectionControlling
import com.rheosoft.obdii.core.OBDConnectionState
import com.rheosoft.obdii.core.SettingsConfigProviding
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

private class MockSettingsConfig : SettingsConfigProviding {
    override var wifiHost: String = "192.168.0.10"
    override var wifiPort: Int = 35000
    override var autoConnectToOBD: Boolean = false
    override var connectionType: ConnectionType = ConnectionType.bluetooth
    override val units: MeasurementUnit get() = unitsFlowMutable.value
    private val unitsFlowMutable = MutableStateFlow(MeasurementUnit.metric)
    private val connFlowMutable = MutableStateFlow(ConnectionType.bluetooth)
    override val unitsStream: StateFlow<MeasurementUnit> = unitsFlowMutable
    override val connectionTypeStream: StateFlow<ConnectionType> = connFlowMutable
    override fun setUnits(units: MeasurementUnit) { unitsFlowMutable.value = units }
}

private class MockConn : OBDConnectionControlling {
    private val flow = MutableStateFlow(OBDConnectionState.disconnected)
    override val connectionState: OBDConnectionState get() = flow.value
    override val connectionStateStream: StateFlow<OBDConnectionState> = flow
    var updateCount = 0
    var connectCount = 0
    var disconnectCount = 0
    override fun updateConnectionDetails() { updateCount++ }
    override suspend fun connect() { connectCount++ }
    override fun disconnect() { disconnectCount++ }
}

class SettingsViewModelTest {
    @Test
    fun `init mirrors config`() {
        val vm = SettingsViewModel(MockSettingsConfig(), MockConn())
        assertEquals("192.168.0.10", vm.wifiHost)
        assertEquals(35000, vm.wifiPort)
        assertEquals(ConnectionType.bluetooth, vm.connectionType)
    }

    @Test
    fun `connection type change calls update`() {
        val config = MockSettingsConfig()
        val conn = MockConn()
        val vm = SettingsViewModel(config, conn)
        vm.onConnectionTypeChanged(ConnectionType.wifi)
        assertEquals(ConnectionType.wifi, vm.connectionType)
        assertEquals(1, conn.updateCount)
    }

    @Test
    fun `connect button state`() = runTest {
        val vm = SettingsViewModel(MockSettingsConfig(), MockConn())
        assertFalse(vm.isConnectButtonDisabled)
    }

    @Test
    fun `units change updates config`() {
        val config = MockSettingsConfig()
        val vm = SettingsViewModel(config, MockConn())
        vm.onUnitsChanged(MeasurementUnit.imperial)
        assertEquals(MeasurementUnit.imperial, vm.units)
    }
}

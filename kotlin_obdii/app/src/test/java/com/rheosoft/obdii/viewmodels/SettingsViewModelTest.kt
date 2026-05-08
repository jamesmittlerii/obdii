package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.ConnectionType
import com.rheosoft.obdii.core.GaugesDisplayMode
import com.rheosoft.obdii.core.MeasurementUnit
import com.rheosoft.obdii.core.OBDConnectionControlling
import com.rheosoft.obdii.core.OBDConnectionState
import com.rheosoft.obdii.core.SettingsConfigProviding
import com.rheosoft.obdii.core.DEFAULT_WIFI_HOST
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.test.*
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import kotlin.test.*

@OptIn(ExperimentalCoroutinesApi::class)
private class MockSettingsConfig : SettingsConfigProviding {
    override var wifiHost: String = DEFAULT_WIFI_HOST
    override var wifiPort: Int = 35000
    override var autoConnectToOBD: Boolean = false
    
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

@OptIn(ExperimentalCoroutinesApi::class)
private class MockConn : OBDConnectionControlling {
    private val flow = MutableStateFlow(OBDConnectionState.disconnected)
    override var connectionState: OBDConnectionState = OBDConnectionState.disconnected
        set(value) {
            field = value
            flow.value = value
        }
    override val connectionStateStream: StateFlow<OBDConnectionState> = flow
    var updateCount = 0
    var connectCount = 0
    var disconnectCount = 0
    override fun updateConnectionDetails() { updateCount++ }
    override suspend fun connect() { connectCount++ }
    override fun disconnect() { disconnectCount++ }
    fun pushState(s: OBDConnectionState) { connectionState = s }
}

@OptIn(ExperimentalCoroutinesApi::class)
class SettingsViewModelTest {
    private lateinit var mockConfig: MockSettingsConfig
    private lateinit var mockConn: MockConn
    private lateinit var viewModel: SettingsViewModel
    private val testDispatcher = StandardTestDispatcher()
    private val testScope = TestScope(testDispatcher)

    @BeforeEach
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        mockConfig = MockSettingsConfig()
        mockConn = MockConn()
        viewModel = SettingsViewModel(mockConfig, mockConn, testScope)
        // Let init block's coroutines start
        testDispatcher.scheduler.runCurrent()
    }

    @AfterEach
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `testInitializationSeedsFromConfigAndConnection`() {
        assertNotNull(viewModel)
        assertEquals(DEFAULT_WIFI_HOST, viewModel.wifiHost)
        assertEquals(35000, viewModel.wifiPort)
        assertFalse(viewModel.autoConnectToOBD)
        assertEquals(ConnectionType.bluetooth, viewModel.connectionType)
        assertEquals(MeasurementUnit.Metric, viewModel.units)
        assertEquals(OBDConnectionState.disconnected, viewModel.connectionState)
    }

    @Test
    fun `testWifihostUpdatesAfter500msDebounce`() = runTest {
        viewModel.onWifiHostChanged("192.168.1.100")
        advanceTimeBy(600)
        runCurrent()
        assertEquals("192.168.1.100", viewModel.wifiHost)
        assertEquals("192.168.1.100", mockConfig.wifiHost)
    }

    @Test
    fun `testWifihostDebounceDoesNotCallUpdateConnectionDetailsForBluetooth`() = runTest {
        assertEquals(ConnectionType.bluetooth, viewModel.connectionType)
        mockConn.updateCount = 0
        viewModel.onWifiHostChanged("10.0.0.1")
        advanceTimeBy(600)
        runCurrent()
        assertEquals(0, mockConn.updateCount)
    }

    @Test
    fun `testWifihostDebounceCallsUpdateConnectionDetailsWhenWiFiActive`() = runTest {
        viewModel.onConnectionTypeChanged(ConnectionType.wifi)
        runCurrent()
        mockConn.updateCount = 0
        viewModel.onWifiHostChanged("10.0.0.1")
        advanceTimeBy(600)
        runCurrent()
        assertTrue(mockConn.updateCount >= 1)
    }

    @Test
    fun `testWifiportUpdatesAfter500msDebounce`() = runTest {
        viewModel.onWifiPortChanged(35001)
        advanceTimeBy(600)
        runCurrent()
        assertEquals(35001, viewModel.wifiPort)
        assertEquals(35001, mockConfig.wifiPort)
    }

    @Test
    fun `testOnconnectiontypechangedUpdatesConfigAndCallsUpdateConnectionDetails`() {
        viewModel.onConnectionTypeChanged(ConnectionType.wifi)
        testDispatcher.scheduler.runCurrent()
        assertEquals(ConnectionType.wifi, viewModel.connectionType)
        assertEquals(ConnectionType.wifi, mockConfig.connectionType)
        assertEquals(1, mockConn.updateCount)
    }

    @Test
    fun `testRedundantConnectionTypeChangeDoesNotCallUpdateConnectionDetails`() {
        mockConn.updateCount = 0
        viewModel.onConnectionTypeChanged(ConnectionType.bluetooth) // already bluetooth
        testDispatcher.scheduler.runCurrent()
        assertEquals(0, mockConn.updateCount)
    }

    @Test
    fun `testOnunitschangedUpdatesConfig`() {
        viewModel.onUnitsChanged(MeasurementUnit.Imperial)
        testDispatcher.scheduler.runCurrent()
        assertEquals(MeasurementUnit.Imperial, viewModel.units)
        assertEquals(MeasurementUnit.Imperial, mockConfig.units)
    }

    @Test
    fun `testOnautoconnectchangedUpdatesConfig`() {
        viewModel.onAutoConnectChanged(true)
        testDispatcher.scheduler.runCurrent()
        assertTrue(viewModel.autoConnectToOBD)
        assertTrue(mockConfig.autoConnectToOBD)
    }

    @Test
    fun `testConnectionstateUpdatesFromStream`() = runTest {
        mockConn.pushState(OBDConnectionState.connecting)
        runCurrent()
        assertEquals(OBDConnectionState.connecting, viewModel.connectionState)
    }

    @Test
    fun `testIsconnectbuttondisabledFalseWhenDisconnected`() {
        assertFalse(viewModel.isConnectButtonDisabled)
    }

    @Test
    fun `testIsconnectbuttondisabledTrueWhenConnecting`() {
        mockConn.pushState(OBDConnectionState.connecting)
        // Manual push since init collected once
        val vm2 = SettingsViewModel(MockSettingsConfig(), mockConn, testScope)
        testDispatcher.scheduler.runCurrent()
        assertTrue(vm2.isConnectButtonDisabled)
    }

    @Test
    fun `testUnitsstreamFromConfigUpdatesViewModel`() = runTest {
        mockConfig.pushUnits(MeasurementUnit.Imperial)
        runCurrent()
        assertEquals(MeasurementUnit.Imperial, viewModel.units)
    }

    @Test
    fun `testHandleconnectionbuttontapWhenDisconnectedCallsConnect`() = runTest {
        mockConn.pushState(OBDConnectionState.disconnected)
        runCurrent()
        viewModel.handleConnectionButtonTap()
        runCurrent()
        assertEquals(1, mockConn.connectCount)
    }

    @Test
    fun `testHandleconnectionbuttontapWhenConnectedCallsDisconnect`() {
        mockConn.pushState(OBDConnectionState.connected)
        testDispatcher.scheduler.runCurrent()
        viewModel.handleConnectionButtonTap()
        assertEquals(1, mockConn.disconnectCount)
    }
}

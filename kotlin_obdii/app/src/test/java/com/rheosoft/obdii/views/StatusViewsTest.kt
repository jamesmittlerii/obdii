package com.rheosoft.obdii.views

import com.rheosoft.obdii.core.FuelStatusProviding
import com.rheosoft.obdii.core.MilStatusProviding
import com.rheosoft.obdii.core.PidInterestRegistry
import com.rheosoft.obdii.core.ReadinessMonitor
import com.rheosoft.obdii.core.Status
import com.rheosoft.obdii.core.StatusCodeMetadata
import com.rheosoft.obdii.viewmodels.FuelStatusViewModel
import com.rheosoft.obdii.viewmodels.MilStatusViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

private class MockFuelProvider : FuelStatusProviding {
    private val flow = MutableStateFlow<List<StatusCodeMetadata?>?>(null)
    override val fuelStatus: List<StatusCodeMetadata?>?
        get() = flow.value
    override val fuelStatusStream: StateFlow<List<StatusCodeMetadata?>?> = flow
    fun send(status: List<StatusCodeMetadata?>?) {
        flow.value = status
    }
}

private class MockMilProvider : MilStatusProviding {
    private val flow = MutableStateFlow<Status?>(null)
    override val milStatus: Status?
        get() = flow.value
    override val milStatusStream: StateFlow<Status?> = flow
    fun send(status: Status?) {
        flow.value = status
    }
}

class StatusViewsTest {
    @Test
    fun `fuel waiting and empty states match flutter copy`() {
        val provider = MockFuelProvider()
        val view = FuelStatusView(FuelStatusViewModel(provider, PidInterestRegistry()))

        val waiting = view.contentState() as FuelContentState.Waiting
        assertEquals("Waiting for data...", waiting.message)

        provider.send(emptyList())
        Thread.sleep(50)
        val empty = view.contentState() as FuelContentState.Empty
        assertEquals("No Fuel System Status Codes", empty.message)
    }

    @Test
    fun `fuel data state includes bank labels`() {
        val provider = MockFuelProvider()
        val view = FuelStatusView(FuelStatusViewModel(provider, PidInterestRegistry()))

        provider.send(
            listOf(
                StatusCodeMetadata(code = "CL", description = "Closed loop"),
                StatusCodeMetadata(code = "OL", description = "Open loop"),
            ),
        )
        Thread.sleep(50)

        val data = view.contentState() as FuelContentState.Data
        assertEquals(listOf("Bank 1", "Bank 2"), data.banks.map { it.first })
    }

    @Test
    fun `mil waiting and status headers are available`() {
        val provider = MockMilProvider()
        val view = MilStatusView(MilStatusViewModel(provider, PidInterestRegistry()))
        val waiting = view.milContentState() as MilLampState.Waiting
        assertEquals("Waiting for data...", waiting.message)
        assertEquals("MALFUNCTION INDICATOR LAMP", view.milHeader)
    }

    @Test
    fun `mil value and monitors match expected text`() {
        val provider = MockMilProvider()
        val view = MilStatusView(MilStatusViewModel(provider, PidInterestRegistry()))
        provider.send(
            Status(
                milOn = true,
                dtcCount = 2,
                monitors = listOf(
                    ReadinessMonitor(name = "Fuel System", supported = true, ready = true),
                    ReadinessMonitor(name = "Misfire", supported = true, ready = false),
                ),
            ),
        )
        Thread.sleep(50)
        val value = view.milContentState() as MilLampState.Value
        assertEquals("MIL: On (2 DTCs)", value.text)
        assertEquals("build", value.icon)
        val rows = view.monitorRows()
        assertTrue(rows.any { it.name == "Misfire" && it.status == "Not Ready" })
        assertTrue(rows.any { it.name == "Fuel System" && it.status == "Ready" })
    }
}

package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.FuelStatusProviding
import com.rheosoft.obdii.core.PidInterestRegistry
import com.rheosoft.obdii.core.StatusCodeMetadata
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

private class MockFuelProvider : FuelStatusProviding {
    private val flow = MutableStateFlow<List<StatusCodeMetadata?>?>(null)
    override val fuelStatus: List<StatusCodeMetadata?>?
        get() = flow.value
    override val fuelStatusStream: StateFlow<List<StatusCodeMetadata?>?> = flow
    fun send(status: List<StatusCodeMetadata?>?) { flow.value = status }
}

class FuelStatusViewModelTest {
    @Test
    fun `bank extraction and has any`() {
        val p = MockFuelProvider()
        val vm = FuelStatusViewModel(p, PidInterestRegistry())
        p.send(listOf(StatusCodeMetadata("OK", "Closed"), null))
        Thread.sleep(50)
        assertEquals("OK", vm.bank1?.code)
        assertEquals(null, vm.bank2)
        assertTrue(vm.hasAnyStatus)
    }

    @Test
    fun `all null means no status`() {
        val p = MockFuelProvider()
        val vm = FuelStatusViewModel(p, PidInterestRegistry())
        p.send(listOf(null, null))
        Thread.sleep(50)
        assertFalse(vm.hasAnyStatus)
    }
}

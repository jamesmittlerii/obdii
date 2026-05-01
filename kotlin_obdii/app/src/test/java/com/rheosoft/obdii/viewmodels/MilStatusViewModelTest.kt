package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.MilStatusProviding
import com.rheosoft.obdii.core.PidInterestRegistry
import com.rheosoft.obdii.core.ReadinessMonitor
import com.rheosoft.obdii.core.Status
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

private class MockMilProvider : MilStatusProviding {
    private val flow = MutableStateFlow<Status?>(null)
    override val milStatus: Status? get() = flow.value
    override val milStatusStream: StateFlow<Status?> = flow
    fun send(status: Status?) { flow.value = status }
}

class MilStatusViewModelTest {
    @Test
    fun `header text formatting`() {
        val provider = MockMilProvider()
        val vm = MilStatusViewModel(provider, PidInterestRegistry())
        provider.send(Status(milOn = true, dtcCount = 1))
        Thread.sleep(50)
        assertEquals("MIL: On (1 DTC)", vm.headerText)
    }

    @Test
    fun `monitor sorting puts not ready first`() {
        val provider = MockMilProvider()
        val vm = MilStatusViewModel(provider, PidInterestRegistry())
        provider.send(Status(false, 0, listOf(
            ReadinessMonitor("B", supported = true, ready = true),
            ReadinessMonitor("A", supported = true, ready = false)
        )))
        Thread.sleep(50)
        assertEquals(listOf("A", "B"), vm.sortedSupportedMonitors.map { it.name })
    }
}

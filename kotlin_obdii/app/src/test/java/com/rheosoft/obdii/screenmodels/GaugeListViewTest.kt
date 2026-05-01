package com.rheosoft.obdii.screenmodels

import com.rheosoft.obdii.core.DefaultPidStore
import com.rheosoft.obdii.models.ObdPidKind
import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.viewmodels.GaugesViewModel
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals

class GaugeListViewTest {
    @Test
    fun `gauges viewmodel tile count matches enabled gauges`() = runTest {
        DefaultPidStore.resetForTests()
        DefaultPidStore.seededPidsProvider = {
            listOf(
                ObdiiPid("a", true, "A", "A", "010A", kind = ObdPidKind.gauge),
                ObdiiPid("b", false, "B", "B", "010B", kind = ObdPidKind.gauge),
            )
        }
        DefaultPidStore.load()
        val vm = GaugesViewModel(pidProvider = DefaultPidStore)
        Thread.sleep(50)
        assertEquals(1, vm.tiles.size)
    }
}

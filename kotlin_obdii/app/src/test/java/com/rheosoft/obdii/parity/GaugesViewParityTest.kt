package com.rheosoft.obdii.parity

import com.rheosoft.obdii.core.DefaultPidStore
import com.rheosoft.obdii.core.PidInterestRegistry
import com.rheosoft.obdii.models.ObdPidKind
import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.viewmodels.GaugesViewModel
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertTrue

class GaugesViewParityTest {
    @Test
    fun `visible gauges register pid command interest`() = runTest {
        DefaultPidStore.resetForTests()
        DefaultPidStore.seededPidsProvider = {
            listOf(ObdiiPid("rpm", true, "RPM", "Engine RPM", "010C", kind = ObdPidKind.gauge))
        }
        DefaultPidStore.load()
        val registry = PidInterestRegistry()
        val vm = GaugesViewModel(pidProvider = DefaultPidStore, interestRegistry = registry)
        Thread.sleep(50)
        vm.setVisible(true)
        Thread.sleep(50)
        assertTrue(registry.interested.contains("010C"))
    }
}

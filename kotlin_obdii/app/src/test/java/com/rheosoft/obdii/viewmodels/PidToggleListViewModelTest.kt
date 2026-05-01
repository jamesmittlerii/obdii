package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.InMemoryPidStore
import com.rheosoft.obdii.models.ObdPidKind
import com.rheosoft.obdii.models.ObdiiPid
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class PidToggleListViewModelTest {
    private fun pids() = listOf(
        ObdiiPid("rpm", true, "RPM", "Engine RPM", "010C", units = "RPM", kind = ObdPidKind.gauge),
        ObdiiPid("spd", false, "Speed", "Vehicle Speed", "010D", units = "km/h", kind = ObdPidKind.gauge),
        ObdiiPid("status", false, "Status", "Monitor", "0101", units = "NA", kind = ObdPidKind.status),
    )

    @Test
    fun `filters enabled and disabled gauge lists`() {
        val vm = PidToggleListViewModel(InMemoryPidStore(pids()))
        assertTrue(vm.filteredEnabled.all { it.enabled && it.kind == ObdPidKind.gauge })
        assertTrue(vm.filteredDisabled.all { !it.enabled && it.kind == ObdPidKind.gauge })
        vm.clear()
    }

    @Test
    fun `search by command finds pid`() = runTest {
        val vm = PidToggleListViewModel(InMemoryPidStore(pids()))
        vm.searchText = "010D"
        assertTrue((vm.filteredEnabled + vm.filteredDisabled).any { it.id == "spd" })
        vm.clear()
    }

    @Test
    fun `toggle flips enabled`() = runTest {
        val store = InMemoryPidStore(pids())
        val vm = PidToggleListViewModel(store)
        vm.toggle(1, true)
        assertEquals(true, store.pids.first { it.id == "spd" }.enabled)
        vm.clear()
    }

    @Test
    fun `toggleById falls back to pidCommand when id is blank`() = runTest {
        val store = InMemoryPidStore(
            listOf(
                ObdiiPid("", true, "RPM", "Engine RPM", "010C", units = "RPM", kind = ObdPidKind.gauge),
                ObdiiPid("", false, "Speed", "Vehicle Speed", "010D", units = "km/h", kind = ObdPidKind.gauge),
            ),
        )
        val vm = PidToggleListViewModel(store)
        vm.toggleById("010D", true)
        assertEquals(true, store.pids.first { it.pidCommand == "010D" }.enabled)
        vm.clear()
    }
}

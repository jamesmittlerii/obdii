package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.InMemoryPidStore
import com.rheosoft.obdii.models.ObdPidKind
import com.rheosoft.obdii.models.ObdiiPid
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class PidToggleListViewModelTest {
    private fun pids() = listOf(
        ObdiiPid("rpm", true, "RPM", "Engine RPM", "010C", units = "RPM", kind = ObdPidKind.gauge),
        ObdiiPid("spd", false, "Speed", "Vehicle Speed", "010D", units = "km/h", kind = ObdPidKind.gauge),
        ObdiiPid("coolant", false, "Coolant", "Coolant Temperature", "0105", notes = "Engine temperature", units = "°C", kind = ObdPidKind.gauge),
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
    fun `search trims and matches label name notes and command case insensitively`() = runTest {
        val vm = PidToggleListViewModel(InMemoryPidStore(pids()))

        vm.searchText = " speed "
        assertEquals(listOf("spd"), (vm.filteredEnabled + vm.filteredDisabled).map { it.id })

        vm.searchText = "engine temperature"
        assertEquals(listOf("coolant"), (vm.filteredEnabled + vm.filteredDisabled).map { it.id })

        vm.searchText = "010c"
        assertEquals(listOf("rpm"), (vm.filteredEnabled + vm.filteredDisabled).map { it.id })

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
    fun `toggle ignores invalid indexes and unchanged values`() = runTest {
        val store = InMemoryPidStore(pids())
        val vm = PidToggleListViewModel(store)
        val before = store.pids.map { it.enabled }

        vm.toggle(-1, true)
        vm.toggle(store.pids.size, true)
        vm.toggle(0, true)

        assertEquals(before, store.pids.map { it.enabled })
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

    @Test
    fun `toggleById trims ids and ignores missing ids`() = runTest {
        val store = InMemoryPidStore(pids())
        val vm = PidToggleListViewModel(store)

        vm.toggleById(" spd ", true)
        assertTrue(store.pids.first { it.id == "spd" }.enabled)

        vm.toggleById("missing", true)
        assertFalse(store.pids.first { it.id == "status" }.enabled)
        vm.clear()
    }
}

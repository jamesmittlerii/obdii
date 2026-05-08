package com.rheosoft.obdii.core

import com.rheosoft.obdii.models.ObdPidKind
import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.models.ValueRange
import kotlinx.coroutines.test.runTest
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class PidStoreTest {
    @BeforeTest
    fun prepareDefaultStore() {
        DefaultPidStore.resetForTests()
    }

    @AfterTest
    fun resetDefaultStore() {
        DefaultPidStore.resetForTests()
    }

    private fun defaultTestPids() = listOf(
        ObdiiPid(
            id = "pid_rpm",
            enabled = true,
            label = "RPM",
            name = "Engine RPM",
            pidCommand = "010C",
            units = "RPM",
            kind = ObdPidKind.gauge,
            typicalRange = ValueRange(0.0, 8000.0)
        ),
        ObdiiPid(
            id = "pid_speed",
            enabled = false,
            label = "Speed",
            name = "Vehicle Speed",
            pidCommand = "010D",
            units = "km/h",
            kind = ObdPidKind.gauge,
            typicalRange = ValueRange(0.0, 200.0)
        ),
        ObdiiPid(
            id = "pid_coolant",
            enabled = false,
            label = "Coolant",
            name = "Engine Coolant Temp",
            pidCommand = "0105",
            units = "°C",
            kind = ObdPidKind.gauge,
            typicalRange = ValueRange(-20.0, 120.0)
        ),
        ObdiiPid(
            id = "pid_status",
            enabled = false,
            label = "Status",
            name = "Monitor Status",
            pidCommand = "0101",
            units = "NA",
            kind = ObdPidKind.status
        ),
    )

    @Test
    fun `enabled gauges contain only enabled gauge pids`() = runTest {
        val store = InMemoryPidStore(defaultTestPids())
        store.load()
        assertTrue(store.enabledGauges.all { it.enabled && it.kind == ObdPidKind.gauge })
    }

    @Test
    fun `toggle flips enabled`() = runTest {
        val store = InMemoryPidStore(defaultTestPids())
        store.load()
        val gauge = store.pids.first { it.kind == ObdPidKind.gauge }
        val initial = gauge.enabled
        store.toggle(gauge.copyWith(enabled = !initial))
        val updated = store.pids.first { it.id == gauge.id }
        assertEquals(!initial, updated.enabled)
    }

    @Test
    fun `in memory toggle ignores unknown pid`() = runTest {
        val store = InMemoryPidStore(defaultTestPids())
        val before = store.pids.map { it.enabled }

        store.toggle(
            ObdiiPid(
                id = "missing",
                enabled = true,
                label = "Missing",
                name = "Missing",
                pidCommand = "FFFF",
            )
        )

        assertEquals(before, store.pids.map { it.enabled })
    }

    @Test
    fun `in memory move enabled reorders enabled gauges and guards invalid moves`() = runTest {
        val store = InMemoryPidStore(
            defaultTestPids().map {
                if (it.id == "pid_speed") it.copyWith(enabled = true) else it
            }
        )
        val before = store.enabledGauges.map { it.id }

        store.moveEnabled(-1, 0)
        store.moveEnabled(0, store.enabledGauges.size)
        store.moveEnabled(0, 0)
        assertEquals(before, store.enabledGauges.map { it.id })

        store.moveEnabled(0, 1)
        assertEquals(listOf(before[1], before[0]), store.enabledGauges.take(2).map { it.id })
    }

    @Test
    fun `default store load seeds pids and persists enabled flags and gauge orders`() = runTest {
        val backingStore = InMemoryKeyValueStore()
        DefaultPidStore.store = backingStore
        DefaultPidStore.seededPidsProvider = { defaultTestPids() }

        DefaultPidStore.load()

        assertEquals(defaultTestPids().map { it.id }, DefaultPidStore.pids.map { it.id })
        assertTrue(backingStore.getString("PIDStore.enabledByCommand")!!.contains("010C"))
        assertEquals("""["010C"]""", backingStore.getString("PIDStore.enabledGaugesOrder"))
        assertEquals("""["010D","0105"]""", backingStore.getString("PIDStore.disabledGaugesOrder"))
    }

    @Test
    fun `default store load restores saved enabled flags by command`() = runTest {
        DefaultPidStore.store = InMemoryKeyValueStore().apply {
            putString("PIDStore.enabledByCommand", """{"010C":false,"010D":true}""")
        }
        DefaultPidStore.seededPidsProvider = { defaultTestPids() }

        DefaultPidStore.load()

        assertFalse(DefaultPidStore.pids.first { it.pidCommand == "010C" }.enabled)
        assertTrue(DefaultPidStore.pids.first { it.pidCommand == "010D" }.enabled)
    }

    @Test
    fun `default store load restores saved enabled and disabled gauge ordering`() = runTest {
        DefaultPidStore.store = InMemoryKeyValueStore().apply {
            putString("PIDStore.enabledByCommand", """{"010C":true,"010D":true,"0105":false}""")
            putString("PIDStore.enabledGaugesOrder", """["010D","010C"]""")
            putString("PIDStore.disabledGaugesOrder", """["0105"]""")
        }
        DefaultPidStore.seededPidsProvider = { defaultTestPids() }

        DefaultPidStore.load()

        assertEquals(
            listOf("010D", "010C"),
            DefaultPidStore.enabledGauges.map { it.pidCommand }
        )
        assertEquals(
            listOf("0105"),
            DefaultPidStore.pids
                .filter { it.kind == ObdPidKind.gauge && !it.enabled }
                .map { it.pidCommand }
        )
    }

    @Test
    fun `default store is idempotent after first load`() = runTest {
        DefaultPidStore.seededPidsProvider = { defaultTestPids() }
        DefaultPidStore.load()
        val first = DefaultPidStore.pids

        DefaultPidStore.seededPidsProvider = { emptyList() }
        DefaultPidStore.load()

        assertEquals(first, DefaultPidStore.pids)
    }

    @Test
    fun `default store toggle and move update persisted state`() = runTest {
        val backingStore = InMemoryKeyValueStore()
        DefaultPidStore.store = backingStore
        DefaultPidStore.seededPidsProvider = { defaultTestPids() }
        DefaultPidStore.load()

        val speed = DefaultPidStore.pids.first { it.id == "pid_speed" }
        DefaultPidStore.toggle(speed.copyWith(enabled = true))

        assertTrue(DefaultPidStore.pids.first { it.id == "pid_speed" }.enabled)
        assertTrue(backingStore.getString("PIDStore.enabledByCommand")!!.contains(""""010D":true"""))

        DefaultPidStore.moveEnabled(0, 1)
        assertEquals(
            """["010D","010C"]""",
            backingStore.getString("PIDStore.enabledGaugesOrder")
        )
    }

    @Test
    fun `default store ignores unknown toggles and invalid moves`() = runTest {
        DefaultPidStore.seededPidsProvider = { defaultTestPids() }
        DefaultPidStore.load()
        val before = DefaultPidStore.pids

        DefaultPidStore.toggle(
            ObdiiPid(
                id = "missing",
                enabled = true,
                label = "Missing",
                name = "Missing",
                pidCommand = "FFFF",
            )
        )
        DefaultPidStore.moveEnabled(-1, 0)
        DefaultPidStore.moveEnabled(0, 99)
        DefaultPidStore.moveEnabled(0, 0)

        assertEquals(before, DefaultPidStore.pids)
    }
}

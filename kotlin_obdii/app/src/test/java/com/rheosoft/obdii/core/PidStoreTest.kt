package com.rheosoft.obdii.core

import com.rheosoft.obdii.models.ObdPidKind
import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.models.ValueRange
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class PidStoreTest {
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
}

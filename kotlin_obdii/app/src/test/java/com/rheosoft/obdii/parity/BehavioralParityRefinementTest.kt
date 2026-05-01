package com.rheosoft.obdii.parity

import com.rheosoft.obdii.core.DefaultPidStore
import com.rheosoft.obdii.models.ObdPidKind
import com.rheosoft.obdii.models.ObdiiPid
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals

class BehavioralParityRefinementTest {
    @Test
    fun `pid store preserves deterministic gauge ordering on load`() = runTest {
        DefaultPidStore.resetForTests()
        DefaultPidStore.seededPidsProvider = {
            listOf(
                ObdiiPid("a", false, "A", "A", "010A", kind = ObdPidKind.gauge),
                ObdiiPid("b", true, "B", "B", "010B", kind = ObdPidKind.gauge),
            )
        }
        DefaultPidStore.load()
        assertEquals(listOf("010A", "010B"), DefaultPidStore.pids.map { it.pidCommand })
    }
}

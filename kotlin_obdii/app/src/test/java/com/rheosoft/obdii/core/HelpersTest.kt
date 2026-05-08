package com.rheosoft.obdii.core

import kotlin.test.Test
import kotlin.test.assertEquals

class HelpersTest {
    @Test
    fun `clamp returns bounds or original value`() {
        assertEquals(0.0, Helpers.clamp(-1.0, 0.0, 10.0))
        assertEquals(10.0, Helpers.clamp(11.0, 0.0, 10.0))
        assertEquals(4.5, Helpers.clamp(4.5, 0.0, 10.0))
    }

    @Test
    fun `connection type from raw falls back to bluetooth`() {
        assertEquals(ConnectionType.bluetooth, ConnectionType.fromRaw("unknown"))
        assertEquals(ConnectionType.wifi, ConnectionType.fromRaw("wifi"))
    }
}

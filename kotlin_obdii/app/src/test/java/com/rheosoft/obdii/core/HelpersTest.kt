package com.rheosoft.obdii.core

import kotlin.test.Test
import kotlin.test.assertEquals

class HelpersTest {
    @Test
    fun `connection type from raw falls back to bluetooth`() {
        assertEquals(ConnectionType.bluetooth, ConnectionType.fromRaw("unknown"))
        assertEquals(ConnectionType.wifi, ConnectionType.fromRaw("wifi"))
    }
}

package com.rheosoft.obdii.parity

import com.rheosoft.obdii.core.OBDConnectionManager
import com.rheosoft.obdii.core.OBDConnectionState
import com.rheosoft.obdii.core.ConfigData
import com.rheosoft.obdii.core.ConnectionType
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals

class ObdConnectionManagerDemoParityTest {
    @Test
    fun `demo connection transitions disconnected to connected`() = runTest {
        OBDConnectionManager.resetForTests()
        ConfigData.connectionType = ConnectionType.demo
        OBDConnectionManager.connect()
        assertEquals(OBDConnectionState.connected, OBDConnectionManager.connectionState)
    }
}

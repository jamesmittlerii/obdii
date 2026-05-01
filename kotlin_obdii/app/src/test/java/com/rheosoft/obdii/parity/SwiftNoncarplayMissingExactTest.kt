package com.rheosoft.obdii.parity

import com.rheosoft.obdii.core.CarplayBridge
import kotlin.test.Test
import kotlin.test.assertEquals

class SwiftNoncarplayMissingExactTest {
    @Test
    fun `gauge preferences change counter increments`() {
        CarplayBridge.resetForTests()
        CarplayBridge.gaugePreferencesChanged()
        CarplayBridge.gaugePreferencesChanged()
        assertEquals(2, CarplayBridge.gaugePreferencesChangeCount)
    }
}

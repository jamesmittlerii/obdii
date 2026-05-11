package com.rheosoft.obdii.parity

import com.rheosoft.obdii.core.PidInterestRegistry
import com.rheosoft.obdii.viewmodels.MilStatusViewModel
import kotlin.test.Test
import kotlin.test.assertTrue

class MilStatusViewParityTest {
    @Test
    fun `mil view visibility controls 0101 interest`() {
        val registry = PidInterestRegistry()
        val vm = MilStatusViewModel(interestRegistry = registry)
        vm.setVisible(true)
        assertTrue(registry.interested.contains("0101"))
    }
}

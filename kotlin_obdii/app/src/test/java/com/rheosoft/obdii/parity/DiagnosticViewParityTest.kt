package com.rheosoft.obdii.parity

import com.rheosoft.obdii.core.PidInterestRegistry
import com.rheosoft.obdii.viewmodels.DiagnosticsViewModel
import kotlin.test.Test
import kotlin.test.assertTrue

class DiagnosticViewParityTest {
    @Test
    fun `diagnostics visible toggles mode3 interest`() {
        val registry = PidInterestRegistry()
        val vm = DiagnosticsViewModel(interestRegistry = registry)
        vm.setVisible(true)
        assertTrue(registry.interested.contains("03"))
    }
}

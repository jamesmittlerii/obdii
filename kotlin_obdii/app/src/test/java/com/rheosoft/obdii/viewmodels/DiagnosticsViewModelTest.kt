package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.DiagnosticsProviding
import com.rheosoft.obdii.core.PidInterestRegistry
import com.rheosoft.obdii.core.TroubleCodeMetadata
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

private class MockDiagnosticsProvider : DiagnosticsProviding {
    private val flow = MutableStateFlow<List<TroubleCodeMetadata>?>(null)
    override val troubleCodes: List<TroubleCodeMetadata>?
        get() = flow.value
    override val diagnosticsStream: StateFlow<List<TroubleCodeMetadata>?> = flow
    fun send(codes: List<TroubleCodeMetadata>?) { flow.value = codes }
}

class DiagnosticsViewModelTest {
    @Test
    fun `groups sections by severity order`() {
        val provider = MockDiagnosticsProvider()
        val registry = PidInterestRegistry()
        val vm = DiagnosticsViewModel(provider, registry)
        provider.send(
            listOf(
                TroubleCodeMetadata(code = "P1", severity = "Low"),
                TroubleCodeMetadata(code = "P2", severity = "Critical"),
                TroubleCodeMetadata(code = "P3", severity = "High"),
            )
        )
        Thread.sleep(50)
        assertEquals(listOf("Critical", "High", "Low"), vm.sections.map { it.severity })
    }

    @Test
    fun `visibility registers mode3 interest`() {
        val provider = MockDiagnosticsProvider()
        val registry = PidInterestRegistry()
        val vm = DiagnosticsViewModel(provider, registry)
        vm.setVisible(true)
        assertTrue(registry.interested.contains("03"))
    }
}

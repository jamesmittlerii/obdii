package com.rheosoft.obdii.screenmodels

import com.rheosoft.obdii.core.DiagnosticsProviding
import com.rheosoft.obdii.core.OBDConnectionState
import com.rheosoft.obdii.core.PidInterestRegistry
import com.rheosoft.obdii.core.TroubleCodeMetadata
import com.rheosoft.obdii.viewmodels.DiagnosticsViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

private class MockDiagnosticsProvider : DiagnosticsProviding {
    private val flow = MutableStateFlow<List<TroubleCodeMetadata>?>(null)
    override val troubleCodes: List<TroubleCodeMetadata>?
        get() = flow.value
    override val diagnosticsStream: StateFlow<List<TroubleCodeMetadata>?> = flow
    fun send(codes: List<TroubleCodeMetadata>?) {
        flow.value = codes
    }
}

class DiagnosticsViewTest {
    @Test
    fun `waiting state includes connect hint when disconnected`() {
        val view = DiagnosticsScreenModel(
            DiagnosticsViewModel(MockDiagnosticsProvider(), PidInterestRegistry()),
        )
        val state = view.contentState(OBDConnectionState.disconnected) as DiagnosticsContentState.Waiting
        assertEquals("Waiting for data...", state.waitingText)
        assertTrue(state.showConnectHint)
    }

    @Test
    fun `waiting state hides connect hint when connected`() {
        val view = DiagnosticsScreenModel(
            DiagnosticsViewModel(MockDiagnosticsProvider(), PidInterestRegistry()),
        )
        val state = view.contentState(OBDConnectionState.connected) as DiagnosticsContentState.Waiting
        assertFalse(state.showConnectHint)
    }

    @Test
    fun `empty state matches flutter copy`() {
        val provider = MockDiagnosticsProvider()
        val vm = DiagnosticsViewModel(provider, PidInterestRegistry())
        val view = DiagnosticsScreenModel(vm)
        provider.send(emptyList())
        Thread.sleep(50)
        val state = view.contentState(OBDConnectionState.connected) as DiagnosticsContentState.Empty
        assertEquals("No Trouble Codes Found", state.title)
        assertEquals("All systems normal.", state.subtitle)
    }

    @Test
    fun `sections render severity header and row shape`() {
        val provider = MockDiagnosticsProvider()
        val vm = DiagnosticsViewModel(provider, PidInterestRegistry())
        val view = DiagnosticsScreenModel(vm)
        provider.send(
            listOf(
                TroubleCodeMetadata(code = "P0001", title = "Test DTC P0001", severity = "High"),
                TroubleCodeMetadata(code = "P0002", title = "Test DTC P0002", severity = "Critical"),
            ),
        )
        Thread.sleep(50)

        val state = view.contentState(OBDConnectionState.connected) as DiagnosticsContentState.Sections
        assertEquals(listOf("CRITICAL", "HIGH"), state.sections.map { it.header })
        assertEquals("P0002 • Test DTC P0002", state.sections.first().rows.first().title)
    }

    @Test
    fun `detail view includes expected section headers`() {
        val detail = DtcDetailScreenModel(
            TroubleCodeMetadata(
                code = "P0012",
                title = "Camshaft Position Timing Over-Retarded",
                description = "Test",
                severity = "High",
                causes = listOf("Cause 1"),
                remedies = listOf("Remedy 1"),
            ),
        )
        assertEquals("P0012", detail.title)
        assertTrue(detail.sectionHeaders.contains("OVERVIEW"))
        assertTrue(detail.sectionHeaders.contains("DESCRIPTION"))
        assertTrue(detail.sectionHeaders.contains("POTENTIAL CAUSES"))
        assertTrue(detail.sectionHeaders.contains("POSSIBLE REMEDIES"))
    }
}

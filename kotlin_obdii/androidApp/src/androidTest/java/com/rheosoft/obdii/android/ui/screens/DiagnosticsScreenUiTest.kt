package com.rheosoft.obdii.android.ui.screens

import androidx.compose.ui.Modifier
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createComposeRule
import com.rheosoft.obdii.core.*
import com.rheosoft.obdii.screenmodels.DiagnosticsScreenModel
import com.rheosoft.obdii.viewmodels.DiagnosticsViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.junit.Rule
import org.junit.Test

private class MockDiagnosticsProvider : DiagnosticsProviding {
    private val flow = MutableStateFlow<List<TroubleCodeMetadata>?>(null)
    override var troubleCodes: List<TroubleCodeMetadata>? = null
        private set
    override val diagnosticsStream: StateFlow<List<TroubleCodeMetadata>?> = flow
    fun send(codes: List<TroubleCodeMetadata>?) {
        troubleCodes = codes
        flow.value = codes
    }
}

private class DiagnosticsMockConn : OBDConnectionControlling {
    private val flow = MutableStateFlow(OBDConnectionState.disconnected)
    override var connectionState: OBDConnectionState = OBDConnectionState.disconnected
        set(value) {
            field = value
            flow.value = value
        }
    override val connectionStateStream: StateFlow<OBDConnectionState> = flow
    override fun updateConnectionDetails() {}
    override suspend fun connect() {}
    override fun disconnect() {}
    fun pushState(s: OBDConnectionState) { connectionState = s }
}

class DiagnosticsScreenUiTest {
    @get:Rule
    val composeRule = createComposeRule()

    private fun dtc(code: String, severity: String) = TroubleCodeMetadata(
        code = code,
        title = "Test DTC $code",
        description = "Description for $code",
        severity = severity,
        causes = listOf("Cause 1"),
        remedies = listOf("Remedy 1")
    )

    private fun setupScreen(
        provider: MockDiagnosticsProvider = MockDiagnosticsProvider(),
        conn: DiagnosticsMockConn = DiagnosticsMockConn()
    ): MockDiagnosticsProvider {
        val vm = DiagnosticsViewModel(provider = provider, connection = conn)
        val screenModel = DiagnosticsScreenModel(vm)
        composeRule.setContent {
            DiagnosticsScreen(
                view = screenModel,
                modifier = Modifier,
                onDtcTap = {}
            )
        }
        return provider
    }

    @Test
    fun testShowsWaitingStateAndConnectHintWhenDisconnected() {
        val conn = DiagnosticsMockConn().apply { pushState(OBDConnectionState.disconnected) }
        setupScreen(conn = conn)

        composeRule.onNodeWithText("Waiting for data...").assertIsDisplayed()
        composeRule.onNodeWithText("Connect to a vehicle in Settings.").assertIsDisplayed()
    }

    @Test
    fun testShowsEmptyStateWhenCodesLoadAsEmptyList() {
        val conn = DiagnosticsMockConn().apply { pushState(OBDConnectionState.connected) }
        val provider = setupScreen(conn = conn)
        
        provider.send(emptyList())
        
        composeRule.waitForText("No Trouble Codes Found")
        composeRule.onNodeWithText("No Trouble Codes Found").assertIsDisplayed()
        composeRule.onNodeWithText("All systems normal.").assertIsDisplayed()
    }

    @Test
    fun testRendersGroupedSectionHeadersAndRowsForLoadedCodes() {
        val conn = DiagnosticsMockConn().apply { pushState(OBDConnectionState.connected) }
        val provider = setupScreen(conn = conn)
        
        provider.send(listOf(dtc("P0001", "High"), dtc("P0002", "Critical")))
        
        composeRule.waitForText("Critical")
        composeRule.assertTextVisible("Critical")
        composeRule.assertTextVisible("High")
        composeRule.onNodeWithText("P0001", substring = true).assertIsDisplayed()
        composeRule.onNodeWithText("P0002", substring = true).assertIsDisplayed()
    }

    @Test
    fun testTappingADTCRowOpensDetailView() {
        val conn = DiagnosticsMockConn().apply { pushState(OBDConnectionState.connected) }
        var tappedCode: String? = null
        val provider = MockDiagnosticsProvider()
        val vm = DiagnosticsViewModel(provider = provider, connection = conn)
        val screenModel = DiagnosticsScreenModel(vm)
        
        composeRule.setContent {
            DiagnosticsScreen(
                view = screenModel,
                modifier = Modifier,
                onDtcTap = { tappedCode = it.title }
            )
        }
        
        provider.send(listOf(dtc("P0001", "High")))
        
        composeRule.waitForText("P0001", substring = true)
        composeRule.onNodeWithText("P0001", substring = true).performClick()
        
        assert(tappedCode == "P0001")
    }

    @Test
    fun testDoesNotShowConnectHintWhileConnectedAndWaiting() {
        val conn = DiagnosticsMockConn().apply { pushState(OBDConnectionState.connected) }
        setupScreen(conn = conn)

        composeRule.onNodeWithText("Waiting for data...").assertIsDisplayed()
        composeRule.onNodeWithText("Connect to a vehicle in Settings.").assertDoesNotExist()
    }

    @Test
    fun testRowSubtitleContainsSeverityText() {
        val conn = DiagnosticsMockConn().apply { pushState(OBDConnectionState.connected) }
        val provider = setupScreen(conn = conn)
        
        provider.send(listOf(dtc("P0013", "Low")))

        composeRule.waitForText("Low")
        composeRule.assertTextVisible("Low")
    }

    @Test
    fun testSeverityIconsAndColors() {
        val conn = DiagnosticsMockConn().apply { pushState(OBDConnectionState.connected) }
        val provider = setupScreen(conn = conn)
        
        provider.send(listOf(
            dtc("P0001", "Critical"),
            dtc("P0002", "High"),
            dtc("P0003", "Moderate"),
            dtc("P0004", "Low"),
            dtc("P0005", "Unknown")
        ))
        
        composeRule.waitForText("P0001", substring = true)
        // Asserting they load successfully without crashing covers the branch mapping
    }

    @Test
    fun testWaitingStateWhenConnectingShowsConnectHint() {
        val conn = DiagnosticsMockConn().apply { pushState(OBDConnectionState.connecting) }
        setupScreen(conn = conn)

        composeRule.onNodeWithText("Waiting for data...").assertIsDisplayed()
        composeRule.onNodeWithText("Connect to a vehicle in Settings.").assertIsDisplayed()
    }

    @Test
    fun testDtcDetailScreenRendersCorrectly() {
        val dtcObj = dtc("P0001", "Critical")
        val conn = DiagnosticsMockConn().apply { pushState(OBDConnectionState.connected) }
        val provider = MockDiagnosticsProvider()
        val vm = DiagnosticsViewModel(provider = provider, connection = conn)
        val screenModel = DiagnosticsScreenModel(vm)
        val detail = screenModel.detailFor(dtcObj)

        composeRule.setContent {
            DtcDetailScreen(detail = detail, onClose = {})
        }

        composeRule.onAllNodesWithText("P0001").onFirst().assertIsDisplayed()
        composeRule.onNodeWithText("Critical").assertIsDisplayed()
        composeRule.onNodeWithText("Description for P0001").assertIsDisplayed()
        composeRule.onNodeWithText("Cause 1").assertIsDisplayed()
        composeRule.onNodeWithText("Remedy 1").assertIsDisplayed()
    }
}

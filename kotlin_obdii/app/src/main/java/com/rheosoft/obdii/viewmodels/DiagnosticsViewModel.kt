package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.DiagnosticsProviding
import com.rheosoft.obdii.core.OBDConnectionControlling
import com.rheosoft.obdii.core.OBDConnectionManager
import com.rheosoft.obdii.core.OBDConnectionState
import com.rheosoft.obdii.core.PidInterestRegistry
import com.rheosoft.obdii.core.TroubleCodeMetadata
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

data class DtcSection(val title: String, val severity: String, val items: List<TroubleCodeMetadata>)
data class DiagnosticsUiState(
    val codes: List<TroubleCodeMetadata>?,
    val sections: List<DtcSection>,
    val connectionState: OBDConnectionState,
)

class DiagnosticsViewModel(
    private val provider: DiagnosticsProviding = OBDConnectionManager,
    private val interestRegistry: PidInterestRegistry = PidInterestRegistry.instance,
    private val connection: OBDConnectionControlling = OBDConnectionManager,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Default + Job()),
) : BaseViewModel() {
    private val interestToken = interestRegistry.makeToken()
    private var isVisible = false

    var codes: List<TroubleCodeMetadata>? = null
        private set
    var sections: List<DtcSection> = emptyList()
        private set
    var connectionState: OBDConnectionState = connection.connectionState
        private set

    private val _uiStateStream = MutableStateFlow(DiagnosticsUiState(codes, sections, connectionState))
    val uiStateStream: StateFlow<DiagnosticsUiState> = _uiStateStream.asStateFlow()

    init {
        scope.launch {
            provider.diagnosticsStream.collectLatest { newCodes ->
                if (newCodes != codes) {
                    codes = newCodes
                    rebuildSections(newCodes)
                    emitUiState()
                    notifyChanged()
                }
            }
        }
        scope.launch {
            connection.connectionStateStream.collectLatest { newState ->
                if (newState != connectionState) {
                    connectionState = newState
                    emitUiState()
                    notifyChanged()
                }
            }
        }
    }

    fun setVisible(visible: Boolean) {
        if (isVisible == visible) return
        isVisible = visible
        if (visible) interestRegistry.replace(setOf("03"), interestToken) else scope.launch { interestRegistry.clear(interestToken) }
    }

    private fun rebuildSections(codes: List<TroubleCodeMetadata>?) {
        if (codes.isNullOrEmpty()) {
            sections = emptyList()
            return
        }
        val grouped = codes.groupBy { it.severity }
        val order = listOf("Critical", "High", "Moderate", "Low")
        sections = order.filter { grouped.containsKey(it) }.map { sev ->
            DtcSection(sev, sev, grouped[sev].orEmpty())
        }
    }

    private fun emitUiState() {
        _uiStateStream.value = DiagnosticsUiState(codes, sections, connectionState)
    }
}

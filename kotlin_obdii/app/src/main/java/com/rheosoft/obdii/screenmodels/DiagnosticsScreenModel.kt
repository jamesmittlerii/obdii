package com.rheosoft.obdii.screenmodels

import com.rheosoft.obdii.core.OBDConnectionState
import com.rheosoft.obdii.core.TroubleCodeMetadata
import com.rheosoft.obdii.viewmodels.DiagnosticsViewModel

class DiagnosticsScreenModel(
    val viewModel: DiagnosticsViewModel,
    isActive: Boolean = true,
) {
    var isActive: Boolean = isActive
        private set

    val title: String = "Diagnostic Codes"

    init {
        viewModel.setVisible(isActive)
    }

    fun setActive(active: Boolean) {
        if (isActive == active) return
        isActive = active
        viewModel.setVisible(active)
    }

    fun contentState(connectionState: OBDConnectionState): DiagnosticsContentState {
        val codes = viewModel.codes
        if (codes == null) {
            return DiagnosticsContentState.Waiting(
                showConnectHint = connectionState != OBDConnectionState.connected,
                waitingText = "Waiting for data...",
                connectHint = "Connect to a vehicle in Settings.",
            )
        }
        if (viewModel.sections.isEmpty()) {
            return DiagnosticsContentState.Empty(
                title = "No Trouble Codes Found",
                subtitle = "All systems normal.",
            )
        }
        return DiagnosticsContentState.Sections(viewModel.sections.map { section ->
            DiagnosticsSection(
                header = section.severity,
                rows = section.items.map { it.toRow() },
            )
        })
    }

    fun detailFor(code: TroubleCodeMetadata): DtcDetailScreenModel = DtcDetailScreenModel(code)
}

data class DiagnosticsSection(
    val header: String,
    val rows: List<DtcRowModel>,
)

data class DtcRowModel(
    val code: String,
    val title: String,
    val subtitle: String,
    val severityIcon: String,
)

class DtcDetailScreenModel(private val dtc: TroubleCodeMetadata) {
    val title: String = dtc.code
    val sectionHeaders: List<String> = buildList {
        add("Overview")
        add("Description")
        if (dtc.causes.isNotEmpty()) add("Potential causes")
        if (dtc.remedies.isNotEmpty()) add("Possible remedies")
    }
    val overviewRows: List<Pair<String, String>> = listOf(
        "Code" to dtc.code,
        "Title" to dtc.title,
        "Severity" to dtc.severity,
    )
    val description: String = dtc.description
    val causes: List<String> = dtc.causes
    val remedies: List<String> = dtc.remedies
}

sealed class DiagnosticsContentState {
    data class Waiting(
        val showConnectHint: Boolean,
        val waitingText: String,
        val connectHint: String,
    ) : DiagnosticsContentState()

    data class Empty(val title: String, val subtitle: String) : DiagnosticsContentState()
    data class Sections(val sections: List<DiagnosticsSection>) : DiagnosticsContentState()
}

private fun TroubleCodeMetadata.toRow(): DtcRowModel = DtcRowModel(
    code = code,
    title = "$code • ${title.ifBlank { code }}",
    subtitle = severity,
    severityIcon = severityIconName(severity),
)

private fun severityIconName(severity: String): String = when (severity.lowercase()) {
    "critical" -> "cancel_outlined"
    "high" -> "electric_bolt"
    "moderate" -> "warning_amber_outlined"
    else -> "info_outline"
}

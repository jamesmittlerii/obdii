package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.MilStatusProviding
import com.rheosoft.obdii.core.OBDConnectionManager
import com.rheosoft.obdii.core.PidInterestRegistry
import com.rheosoft.obdii.core.ReadinessMonitor
import com.rheosoft.obdii.core.Status
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

data class MilMonitorRow(
    val name: String,
    val status: String,
    val icon: String,
    val color: String,
)

data class MilStatusUiState(
    val status: Status?,
    val headerText: String,
    val monitorRows: List<MilMonitorRow>,
)

class MilStatusViewModel(
    private val provider: MilStatusProviding = OBDConnectionManager,
    private val interestRegistry: PidInterestRegistry = PidInterestRegistry.instance,
) : BaseViewModel() {
    private val scope = CoroutineScope(Dispatchers.Default + Job())
    private val interestToken = interestRegistry.makeToken()
    private var isVisible = false

    var status: Status? = null
        private set
    private val _statusStream = MutableStateFlow<Status?>(status)
    val statusStream: StateFlow<Status?> = _statusStream.asStateFlow()
    private val _uiStateStream = MutableStateFlow(buildUiState(status))
    val uiStateStream: StateFlow<MilStatusUiState> = _uiStateStream.asStateFlow()

    init {
        scope.launch {
            provider.milStatusStream.collectLatest { s ->
                if (s != status) {
                    status = s
                    _statusStream.value = s
                    _uiStateStream.value = buildUiState(s)
                    notifyChanged()
                }
            }
        }
    }

    fun setVisible(visible: Boolean) {
        if (isVisible == visible) return
        isVisible = visible
        if (visible) interestRegistry.replace(setOf("0101"), interestToken) else scope.launch { interestRegistry.clear(interestToken) }
    }

    val headerText: String
        get() {
            val s = status ?: return "No MIL Status"
            val dtcLabel = if (s.dtcCount == 1) "1 DTC" else "${s.dtcCount} DTCs"
            return "MIL: ${if (s.milOn) "On" else "Off"} ($dtcLabel)"
        }
    val hasStatus: Boolean
        get() = status != null
    val sortedSupportedMonitors: List<ReadinessMonitor>
        get() = status?.monitors
            ?.filter { it.supported }
            ?.sortedWith(compareBy<ReadinessMonitor>({ if (it.ready) 1 else 0 }, { it.name }))
            ?: emptyList()

    private fun buildUiState(status: Status?): MilStatusUiState {
        val header = if (status == null) {
            "Waiting for data..."
        } else {
            val dtcLabel = if (status.dtcCount == 1) "1 DTC" else "${status.dtcCount} DTCs"
            "MIL: ${if (status.milOn) "On" else "Off"} ($dtcLabel)"
        }
        val rows = status?.monitors
            ?.filter { it.supported }
            ?.sortedWith(compareBy<ReadinessMonitor>({ if (it.ready) 1 else 0 }, { it.name }))
            .orEmpty()
            .map { monitor ->
                MilMonitorRow(
                    name = monitor.name,
                    status = if (monitor.ready) "Ready" else "Not Ready",
                    icon = "speed",
                    color = if (monitor.ready) "blue" else "orange",
                )
            }
        return MilStatusUiState(status = status, headerText = header, monitorRows = rows)
    }
}

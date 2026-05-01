package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.MilStatusProviding
import com.rheosoft.obdii.core.OBDConnectionManager
import com.rheosoft.obdii.core.PidInterestRegistry
import com.rheosoft.obdii.core.ReadinessMonitor
import com.rheosoft.obdii.core.Status
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

class MilStatusViewModel(
    private val provider: MilStatusProviding = OBDConnectionManager,
    private val interestRegistry: PidInterestRegistry = PidInterestRegistry.instance,
) : BaseViewModel() {
    private val scope = CoroutineScope(Dispatchers.Default + Job())
    private val interestToken = interestRegistry.makeToken()
    private var isVisible = false

    var status: Status? = null
        private set

    init {
        scope.launch {
            provider.milStatusStream.collectLatest { s ->
                if (s != status) {
                    status = s
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
}

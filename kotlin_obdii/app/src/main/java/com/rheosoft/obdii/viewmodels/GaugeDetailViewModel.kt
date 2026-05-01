package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.ConfigData
import com.rheosoft.obdii.core.PIDStats
import com.rheosoft.obdii.core.PidStatsProviding
import com.rheosoft.obdii.core.UnitsProviding
import com.rheosoft.obdii.models.ObdiiPid
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

data class GaugeDetailUiState(val stats: PIDStats?)

class GaugeDetailViewModel(
    val pid: ObdiiPid,
    private val statsProvider: PidStatsProviding,
    private val unitsProvider: UnitsProviding,
) : BaseViewModel() {
    constructor(pid: ObdiiPid) : this(pid, com.rheosoft.obdii.core.OBDConnectionManager, ConfigData)

    private val scope = CoroutineScope(Dispatchers.Default + Job())
    var stats: PIDStats? = statsProvider.statsFor(pid.pidCommand)
        private set
    private val _uiStateStream = MutableStateFlow(GaugeDetailUiState(stats))
    val uiStateStream: StateFlow<GaugeDetailUiState> = _uiStateStream.asStateFlow()

    init {
        scope.launch {
            statsProvider.pidStatsStream.collectLatest { all ->
                val newStats = all[pid.pidCommand]
                if (!isSameStats(stats, newStats)) {
                    stats = newStats
                    _uiStateStream.value = GaugeDetailUiState(stats)
                    notifyChanged()
                }
            }
        }
        scope.launch {
            unitsProvider.unitsStream.collectLatest {
                stats = statsProvider.statsFor(pid.pidCommand)
                _uiStateStream.value = GaugeDetailUiState(stats)
                notifyChanged()
            }
        }
    }

    private fun isSameStats(lhs: PIDStats?, rhs: PIDStats?): Boolean {
        if (lhs == null && rhs == null) return true
        if (lhs == null || rhs == null) return false
        return lhs.sampleCount == rhs.sampleCount &&
            lhs.latest.value == rhs.latest.value &&
            lhs.min == rhs.min &&
            lhs.max == rhs.max
    }
}

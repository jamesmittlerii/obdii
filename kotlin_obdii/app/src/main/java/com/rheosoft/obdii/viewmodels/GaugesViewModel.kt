package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.ConfigData
import com.rheosoft.obdii.core.GaugesDisplayMode
import com.rheosoft.obdii.core.PIDStats
import com.rheosoft.obdii.core.PidInterestRegistry
import com.rheosoft.obdii.core.PidListProviding
import com.rheosoft.obdii.core.PidStatsProviding
import com.rheosoft.obdii.core.UnitsProviding
import com.rheosoft.obdii.core.DefaultPidStore
import com.rheosoft.obdii.core.PidStore
import com.rheosoft.obdii.core.OBDConnectionManager
import com.rheosoft.obdii.models.ObdPidKind
import com.rheosoft.obdii.models.ObdiiPid
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

data class GaugeTile(val id: String, val pid: ObdiiPid, val stats: PIDStats?)
data class GaugesUiState(val tiles: List<GaugeTile>, val displayMode: GaugesDisplayMode)

class GaugesViewModel(
    private val pidProvider: PidListProviding = DefaultPidStore,
    private val statsProvider: PidStatsProviding = OBDConnectionManager,
    private val unitsProvider: UnitsProviding = ConfigData,
    private val interestRegistry: PidInterestRegistry = PidInterestRegistry.instance,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Default + Job()),
) : BaseViewModel() {
    private val interestToken = interestRegistry.makeToken()
    private var isVisible = false
    var tiles: List<GaugeTile> = emptyList()
        private set
    private val _uiStateStream = MutableStateFlow(GaugesUiState(tiles, unitsProvider.gaugesDisplayMode))
    val uiStateStream: StateFlow<GaugesUiState> = _uiStateStream.asStateFlow()

    val isEmpty: Boolean
        get() = tiles.isEmpty()

    init {
        scope.launch { pidProvider.pidsStream.collectLatest { rebuildTiles() } }
        scope.launch { statsProvider.pidStatsStream.collectLatest { rebuildTiles() } }
        scope.launch { unitsProvider.unitsStream.collectLatest { rebuildTiles() } }
        scope.launch { unitsProvider.gaugesDisplayModeStream.collectLatest { rebuildTiles() } }
        rebuildTiles()
    }

    fun setVisible(visible: Boolean) {
        if (isVisible == visible) return
        isVisible = visible
        updateInterest()
    }

    fun setDisplayMode(mode: GaugesDisplayMode) {
        unitsProvider.gaugesDisplayMode = mode
    }

    suspend fun moveEnabled(from: Int, to: Int) {
        val store = pidProvider as? PidStore ?: return
        store.moveEnabled(from, to)
    }

    private fun rebuildTiles() {
        val newTiles = pidProvider.pids
            .filter { it.enabled && it.kind == ObdPidKind.gauge }
            .map { GaugeTile(it.id, it, statsProvider.statsFor(it.pidCommand)) }
        val mode = unitsProvider.gaugesDisplayMode
        if (newTiles == tiles && mode == _uiStateStream.value.displayMode) return
        tiles = newTiles
        _uiStateStream.value = GaugesUiState(tiles, mode)
        updateInterest()
        notifyChanged()
    }

    private fun updateInterest() {
        if (!isVisible) {
            scope.launch { interestRegistry.clear(interestToken) }
            return
        }
        interestRegistry.replace(tiles.map { it.pid.pidCommand }.toSet(), interestToken)
    }
}

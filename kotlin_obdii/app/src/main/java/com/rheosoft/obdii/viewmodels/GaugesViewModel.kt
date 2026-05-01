package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.ConfigData
import com.rheosoft.obdii.core.PIDStats
import com.rheosoft.obdii.core.PidInterestRegistry
import com.rheosoft.obdii.core.PidListProviding
import com.rheosoft.obdii.core.PidStatsProviding
import com.rheosoft.obdii.core.UnitsProviding
import com.rheosoft.obdii.core.DefaultPidStore
import com.rheosoft.obdii.core.OBDConnectionManager
import com.rheosoft.obdii.models.ObdPidKind
import com.rheosoft.obdii.models.ObdiiPid
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

data class GaugeTile(val id: String, val pid: ObdiiPid, val stats: PIDStats?)

class GaugesViewModel(
    private val pidProvider: PidListProviding = DefaultPidStore,
    private val statsProvider: PidStatsProviding = OBDConnectionManager,
    private val unitsProvider: UnitsProviding = ConfigData,
    private val interestRegistry: PidInterestRegistry = PidInterestRegistry.instance,
) : BaseViewModel() {
    private val scope = CoroutineScope(Dispatchers.Default + Job())
    private val interestToken = interestRegistry.makeToken()
    private var isVisible = false
    var tiles: List<GaugeTile> = emptyList()
        private set

    val isEmpty: Boolean
        get() = tiles.isEmpty()

    init {
        scope.launch { pidProvider.pidsStream.collectLatest { rebuildTiles() } }
        scope.launch { statsProvider.pidStatsStream.collectLatest { rebuildTiles() } }
        scope.launch { unitsProvider.unitsStream.collectLatest { rebuildTiles() } }
        rebuildTiles()
    }

    fun setVisible(visible: Boolean) {
        if (isVisible == visible) return
        isVisible = visible
        updateInterest()
    }

    private fun rebuildTiles() {
        val newTiles = pidProvider.pids
            .filter { it.enabled && it.kind == ObdPidKind.gauge }
            .map { GaugeTile(it.id, it, statsProvider.statsFor(it.pidCommand)) }
        if (newTiles == tiles) return
        tiles = newTiles
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

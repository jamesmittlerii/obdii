package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.DefaultPidStore
import com.rheosoft.obdii.core.PidStore
import com.rheosoft.obdii.models.ObdPidKind
import com.rheosoft.obdii.models.ObdiiPid
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

class PidToggleListViewModel(
    private val store: PidStore = DefaultPidStore,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Default + Job()),
    private val searchDebounceMs: Long = 250,
    private val ownsScope: Boolean = true,
) {
    private var searchDebounceJob: Job? = null
    private var appliedSearchText: String = ""
    var onChanged: (() -> Unit)? = null
    var pids: List<ObdiiPid> = store.pids
        private set
    var searchText: String = ""
        set(value) {
            field = value
            searchDebounceJob?.cancel()
            if (value.isBlank()) {
                appliedSearchText = ""
                onChanged?.invoke()
                return
            }
            if (searchDebounceMs <= 0) {
                appliedSearchText = value
                onChanged?.invoke()
                return
            }
            searchDebounceJob = scope.launch {
                delay(searchDebounceMs)
                appliedSearchText = value
                onChanged?.invoke()
            }
        }

    init {
        scope.launch {
            store.pidsStream.collectLatest {
                pids = it.toList()
                onChanged?.invoke()
            }
        }
    }

    val filteredEnabled: List<ObdiiPid>
        get() = applySearch(pids.filter { it.enabled && it.kind == ObdPidKind.gauge })
    val filteredDisabled: List<ObdiiPid>
        get() = applySearch(pids.filter { !it.enabled && it.kind == ObdPidKind.gauge })

    private fun applySearch(list: List<ObdiiPid>): List<ObdiiPid> {
        val q = appliedSearchText.trim().lowercase()
        if (q.isEmpty()) return list
        return list.filter { p ->
            p.label.lowercase().contains(q) ||
                p.name.lowercase().contains(q) ||
                (p.notes?.lowercase()?.contains(q) == true) ||
                p.pidCommand.lowercase().contains(q)
        }
    }

    suspend fun toggle(index: Int, isOn: Boolean) {
        if (index !in pids.indices) return
        val pid = pids[index]
        if (pid.enabled == isOn) return
        store.toggle(pid.copyWith(enabled = isOn))
    }

    suspend fun toggleById(id: String, isOn: Boolean) {
        val idx = pids.indexOfFirst { it.id == id }
            .takeIf { it >= 0 }
            ?: pids.indexOfFirst { it.pidCommand == id }
        if (idx < 0) return
        toggle(idx, isOn)
    }

    suspend fun moveEnabled(fromIndex: Int, toIndex: Int) {
        store.moveEnabled(fromIndex, toIndex)
    }

    fun clear() {
        searchDebounceJob?.cancel()
        if (ownsScope) {
            scope.cancel()
        }
    }
}

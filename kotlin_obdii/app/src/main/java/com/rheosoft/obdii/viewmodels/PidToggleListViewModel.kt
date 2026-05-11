package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.DefaultPidStore
import com.rheosoft.obdii.core.PidStore
import com.rheosoft.obdii.models.ObdPidKind
import com.rheosoft.obdii.models.ObdiiPid
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class PidToggleListViewModel(
    private val store: PidStore = DefaultPidStore,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Default + Job()),
    private val ownsScope: Boolean = true,
) {
    val pidsStream: StateFlow<List<ObdiiPid>> = store.pidsStream
    var onChanged: (() -> Unit)? = null
    var pids: List<ObdiiPid> = store.pids
        private set
    var searchText: String = ""
        set(value) {
            field = value
            // Swift-like behavior: filter updates immediately as user types.
            onChanged?.invoke()
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
        val q = searchText.trim().lowercase()
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
        val key = id.trim()
        val idx = pids.indexOfFirst { it.stableKey() == key }
            .takeIf { it >= 0 }
            ?: pids.indexOfFirst { it.pidCommand == key }
        if (idx < 0) return
        toggle(idx, isOn)
    }

    suspend fun moveEnabled(fromIndex: Int, toIndex: Int) {
        store.moveEnabled(fromIndex, toIndex)
    }

    fun clear() {
        if (ownsScope) {
            scope.cancel()
        }
    }
}

private fun ObdiiPid.stableKey(): String = if (id.isNotBlank()) id else pidCommand

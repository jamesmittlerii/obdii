package com.rheosoft.obdii.core

import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.rheosoft.obdii.models.ObdPidKind
import com.rheosoft.obdii.models.ObdiiPid
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

interface PidListProviding {
    val pids: List<ObdiiPid>
    val pidsStream: StateFlow<List<ObdiiPid>>
}

interface PidStore : PidListProviding {
    val enabledGauges: List<ObdiiPid>
    suspend fun load()
    suspend fun toggle(pid: ObdiiPid)
    suspend fun moveEnabled(fromIndex: Int, toIndex: Int)
}

class InMemoryPidStore(initial: List<ObdiiPid>) : PidStore {
    private val mutex = Mutex()
    override var pids: List<ObdiiPid> = initial
        private set

    private val flow = MutableStateFlow(pids)
    override val pidsStream: StateFlow<List<ObdiiPid>> = flow.asStateFlow()
    override val enabledGauges: List<ObdiiPid>
        get() = pids.filter { it.kind == ObdPidKind.gauge && it.enabled }

    override suspend fun load() {}

    override suspend fun toggle(pid: ObdiiPid) = mutex.withLock {
        val key = pid.stableKey()
        val idx = pids.indexOfFirst { it.stableKey() == key }
        if (idx == -1) return@withLock
        val mutable = pids.toMutableList()
        mutable[idx] = mutable[idx].copyWith(enabled = pid.enabled)
        pids = mutable
        flow.value = pids
    }

    override suspend fun moveEnabled(fromIndex: Int, toIndex: Int) = mutex.withLock {
        val enabledIdx = pids.withIndex()
            .filter { it.value.kind == ObdPidKind.gauge && it.value.enabled }
            .map { it.index }
        if (enabledIdx.isEmpty()) return@withLock
        if (fromIndex !in enabledIdx.indices || toIndex !in enabledIdx.indices || fromIndex == toIndex) return@withLock
        val subset = enabledIdx.map { pids[it] }.toMutableList()
        val item = subset.removeAt(fromIndex)
        subset.add(toIndex, item)
        val mutable = pids.toMutableList()
        enabledIdx.forEachIndexed { i, pIndex -> mutable[pIndex] = subset[i] }
        pids = mutable
        flow.value = pids
    }
}

object DefaultPidStore : PidStore {
    private const val K_ENABLED = "PIDStore.enabledByCommand"
    private const val K_ENABLED_ORDER = "PIDStore.enabledGaugesOrder"
    private const val K_DISABLED_ORDER = "PIDStore.disabledGaugesOrder"

    var store: KeyValueStore = InMemoryKeyValueStore()
    var seededPidsProvider: () -> List<ObdiiPid> = { emptyList() }

    private val mutex = Mutex()
    private val gson = Gson()
    private var loaded = false
    private var mutablePids: List<ObdiiPid> = emptyList()
    private val flow = MutableStateFlow<List<ObdiiPid>>(emptyList())

    override val pids: List<ObdiiPid>
        get() = mutablePids
    override val pidsStream: StateFlow<List<ObdiiPid>> = flow.asStateFlow()
    override val enabledGauges: List<ObdiiPid>
        get() = mutablePids.filter { it.kind == ObdPidKind.gauge && it.enabled }

    override suspend fun load() = mutex.withLock {
        if (loaded) return@withLock
        loaded = true
        var all = seededPidsProvider()
        store.getString(K_ENABLED)?.let { json ->
            val type = object : TypeToken<Map<String, Boolean>>() {}.type
            val saved: Map<String, Boolean> = gson.fromJson(json, type)
            all = all.map { pid ->
                saved[pid.pidCommand]?.let { pid.copyWith(enabled = it) } ?: pid
            }
        }
        val enabledOrder = store.getString(K_ENABLED_ORDER)?.let { parseStringList(it) }
        val disabledOrder = store.getString(K_DISABLED_ORDER)?.let { parseStringList(it) }
        if (enabledOrder != null || disabledOrder != null) {
            all = applySavedOrdering(all, enabledOrder, disabledOrder)
        }
        mutablePids = all
        persistEnabledFlags()
        persistGaugeOrders()
        flow.value = mutablePids
    }

    override suspend fun toggle(pid: ObdiiPid) = mutex.withLock {
        val key = pid.stableKey()
        val idx = mutablePids.indexOfFirst { it.stableKey() == key }
        if (idx == -1) return@withLock
        val mutable = mutablePids.toMutableList()
        mutable[idx] = mutable[idx].copyWith(enabled = pid.enabled)
        mutablePids = reordered(mutable)
        persistEnabledFlags()
        persistGaugeOrders()
        flow.value = mutablePids
    }

    override suspend fun moveEnabled(fromIndex: Int, toIndex: Int) = mutex.withLock {
        val enabledIndices = mutablePids.withIndex()
            .filter { it.value.kind == ObdPidKind.gauge && it.value.enabled }
            .map { it.index }
        if (enabledIndices.isEmpty()) return@withLock
        if (fromIndex !in enabledIndices.indices || toIndex !in enabledIndices.indices || fromIndex == toIndex) return@withLock
        val subset = enabledIndices.map { mutablePids[it] }.toMutableList()
        val item = subset.removeAt(fromIndex)
        subset.add(toIndex, item)
        val mutable = mutablePids.toMutableList()
        enabledIndices.forEachIndexed { i, idx -> mutable[idx] = subset[i] }
        mutablePids = mutable
        persistGaugeOrders()
        flow.value = mutablePids
    }

    private fun persistEnabledFlags() {
        val map = mutablePids.associate { it.pidCommand to it.enabled }
        store.putString(K_ENABLED, gson.toJson(map))
    }

    private fun persistGaugeOrders() {
        val enabled = mutablePids.filter { it.kind == ObdPidKind.gauge && it.enabled }.map { it.pidCommand }
        val disabled = mutablePids.filter { it.kind == ObdPidKind.gauge && !it.enabled }.map { it.pidCommand }
        store.putString(K_ENABLED_ORDER, gson.toJson(enabled))
        store.putString(K_DISABLED_ORDER, gson.toJson(disabled))
    }

    private fun parseStringList(json: String): List<String> {
        val type = object : TypeToken<List<String>>() {}.type
        return gson.fromJson(json, type)
    }

    private fun applySavedOrdering(
        pids: List<ObdiiPid>,
        enabledOrder: List<String>?,
        disabledOrder: List<String>?
    ): List<ObdiiPid> {
        val enabled = pids.filter { it.kind == ObdPidKind.gauge && it.enabled }.toMutableList()
        val disabled = pids.filter { it.kind == ObdPidKind.gauge && !it.enabled }.toMutableList()
        val others = pids.filter { it.kind != ObdPidKind.gauge }
        if (enabledOrder != null) reorderList(enabled, enabledOrder)
        if (disabledOrder != null) reorderList(disabled, disabledOrder)
        return enabled + disabled + others
    }

    private fun reorderList(list: MutableList<ObdiiPid>, order: List<String>) {
        val indexMap = order.withIndex().associate { it.value to it.index }
        list.sortWith { l, r ->
            val li = indexMap[l.pidCommand]
            val ri = indexMap[r.pidCommand]
            when {
                li != null && ri != null -> li.compareTo(ri)
                li != null -> -1
                ri != null -> 1
                else -> 0
            }
        }
    }

    private fun reordered(pids: List<ObdiiPid>): List<ObdiiPid> {
        val enabled = pids.filter { it.kind == ObdPidKind.gauge && it.enabled }
        val disabled = pids.filter { it.kind == ObdPidKind.gauge && !it.enabled }
        val others = pids.filter { it.kind != ObdPidKind.gauge }
        return enabled + disabled + others
    }

    fun resetForTests() {
        loaded = false
        mutablePids = emptyList()
        flow.value = emptyList()
        store = InMemoryKeyValueStore()
        seededPidsProvider = { emptyList() }
    }
}

private fun ObdiiPid.stableKey(): String = id.ifBlank { pidCommand }

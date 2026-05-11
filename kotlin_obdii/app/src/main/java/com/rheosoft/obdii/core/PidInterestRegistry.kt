package com.rheosoft.obdii.core

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.UUID

class PidInterestRegistry {
    companion object {
        val instance = PidInterestRegistry()
    }

    private val lock = Any()
    private val byToken: MutableMap<String, Set<String>> = mutableMapOf()
    private val _interestedFlow = MutableStateFlow<Set<String>>(emptySet())
    val interestedStream: StateFlow<Set<String>> = _interestedFlow.asStateFlow()
    val interested: Set<String>
        get() = _interestedFlow.value

    fun makeToken(): String {
        val token = UUID.randomUUID().toString()
        synchronized(lock) {
            byToken[token] = emptySet()
        }
        return token
    }

    fun replace(pids: Set<String>, token: String) {
        synchronized(lock) {
            byToken[token] = pids
            recomputeLocked()
        }
    }

    suspend fun clear(token: String) {
        synchronized(lock) {
            byToken.remove(token)
            recomputeLocked()
        }
    }

    private fun recomputeLocked() {
        val union = byToken.values.flatten().toSet()
        if (union != _interestedFlow.value) {
            _interestedFlow.value = union
        }
    }
}

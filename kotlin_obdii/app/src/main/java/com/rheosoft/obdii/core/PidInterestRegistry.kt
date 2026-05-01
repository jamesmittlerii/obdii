package com.rheosoft.obdii.core

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.UUID

class PidInterestRegistry {
    companion object {
        val instance = PidInterestRegistry()
    }

    private val byToken: MutableMap<String, Set<String>> = mutableMapOf()
    private val _interestedFlow = MutableStateFlow<Set<String>>(emptySet())
    val interestedStream: StateFlow<Set<String>> = _interestedFlow.asStateFlow()
    val interested: Set<String>
        get() = _interestedFlow.value

    fun makeToken(): String {
        val token = UUID.randomUUID().toString()
        byToken[token] = emptySet()
        return token
    }

    fun replace(pids: Set<String>, token: String) {
        byToken[token] = pids
        recompute()
    }

    suspend fun clear(token: String) {
        byToken.remove(token)
        recompute()
    }

    private fun recompute() {
        val union = byToken.values.flatten().toSet()
        if (union != _interestedFlow.value) {
            _interestedFlow.value = union
        }
    }
}

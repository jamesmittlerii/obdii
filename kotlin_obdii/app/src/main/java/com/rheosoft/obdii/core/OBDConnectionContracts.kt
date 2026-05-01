package com.rheosoft.obdii.core

import kotlinx.coroutines.flow.StateFlow

enum class OBDConnectionState { disconnected, connecting, connected, failed }

interface PidStatsProviding {
    val pidStats: Map<String, PIDStats>
    fun statsFor(pidCommand: String): PIDStats?
    val pidStatsStream: StateFlow<Map<String, PIDStats>>
}

interface DiagnosticsProviding {
    val troubleCodes: List<TroubleCodeMetadata>?
    val diagnosticsStream: StateFlow<List<TroubleCodeMetadata>?>
}

interface FuelStatusProviding {
    val fuelStatus: List<StatusCodeMetadata?>?
    val fuelStatusStream: StateFlow<List<StatusCodeMetadata?>?>
}

interface MilStatusProviding {
    val milStatus: Status?
    val milStatusStream: StateFlow<Status?>
}

interface OBDConnectionControlling {
    val connectionState: OBDConnectionState
    fun updateConnectionDetails()
    suspend fun connect()
    fun disconnect()
    val connectionStateStream: StateFlow<OBDConnectionState>
}

package com.rheosoft.obdii.bootstrap

import com.rheosoft.obdii.core.ConfigData
import com.rheosoft.obdii.core.DefaultPidStore
import com.rheosoft.obdii.core.OBDConnectionManager

interface AppConfigBootstrapper {
    val autoConnectToOBD: Boolean
    fun load()
}

interface PidStoreBootstrapper {
    suspend fun load()
}

interface ConnectionBootstrapper {
    fun initialize()
    suspend fun connect()
}

object AppBootstrap {
    private var isInitialized = false

    suspend fun initialize(
        config: AppConfigBootstrapper = object : AppConfigBootstrapper {
            override val autoConnectToOBD: Boolean
                get() = ConfigData.autoConnectToOBD
            override fun load() = ConfigData.load()
        },
        pidStore: PidStoreBootstrapper = object : PidStoreBootstrapper {
            override suspend fun load() = DefaultPidStore.load()
        },
        connection: ConnectionBootstrapper = object : ConnectionBootstrapper {
            override fun initialize() = OBDConnectionManager.initialize()
            override suspend fun connect() = OBDConnectionManager.connect()
        },
    ) {
        if (isInitialized) return
        isInitialized = true

        config.load()
        pidStore.load()
        connection.initialize()
    }
}

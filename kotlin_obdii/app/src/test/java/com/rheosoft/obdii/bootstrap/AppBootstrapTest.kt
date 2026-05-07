package com.rheosoft.obdii.bootstrap

import kotlinx.coroutines.test.runTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals

private class FakeConfig(private val autoConnect: Boolean) : AppConfigBootstrapper {
    var loadCount = 0
    override val autoConnectToOBD: Boolean
        get() = autoConnect

    override fun load() {
        loadCount++
    }
}

private class FakePidStore : PidStoreBootstrapper {
    var loadCount = 0
    override suspend fun load() {
        loadCount++
    }
}

private class FakeConnection : ConnectionBootstrapper {
    var initializeCount = 0
    var connectCount = 0
    override fun initialize() {
        initializeCount++
    }

    override suspend fun connect() {
        connectCount++
    }
}

class AppBootstrapTest {
    @BeforeTest
    fun resetBootstrap() {
        AppBootstrap.resetForTesting()
    }

    @Test
    fun `initialize loads config store and manager`() = runTest {
        val config = FakeConfig(autoConnect = false)
        val pidStore = FakePidStore()
        val connection = FakeConnection()

        AppBootstrap.initialize(config, pidStore, connection)

        assertEquals(1, config.loadCount)
        assertEquals(1, pidStore.loadCount)
        assertEquals(1, connection.initializeCount)
        assertEquals(0, connection.connectCount)
    }

    @Test
    fun `initialize does not block on connect`() = runTest {
        val config = FakeConfig(autoConnect = true)
        val pidStore = FakePidStore()
        val connection = FakeConnection()

        AppBootstrap.initialize(config, pidStore, connection)

        assertEquals(1, config.loadCount)
        assertEquals(1, pidStore.loadCount)
        assertEquals(1, connection.initializeCount)
        assertEquals(0, connection.connectCount)
    }
}

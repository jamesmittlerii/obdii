package com.rheosoft.obdii.bootstrap

import kotlinx.coroutines.test.runTest
import kotlin.test.BeforeTest
import kotlin.test.Test

class MainCupertinoTest {
    @BeforeTest
    fun resetBootstrap() {
        AppBootstrap.resetForTesting()
    }

    @Test
    fun `run initializes the shared bootstrap without crashing`() = runTest {
        MainCupertino.run()
    }
}

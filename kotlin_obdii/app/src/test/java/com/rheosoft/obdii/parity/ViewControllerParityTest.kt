package com.rheosoft.obdii.parity

import com.rheosoft.obdii.views.MainScaffold
import com.rheosoft.obdii.views.MainScaffoldCupertino
import kotlin.test.Test
import kotlin.test.assertNotNull

class ViewControllerParityTest {
    @Test
    fun `material and cupertino scaffolds exist`() {
        assertNotNull(MainScaffold())
        assertNotNull(MainScaffoldCupertino())
    }
}

package com.rheosoft.obdii.parity

import com.rheosoft.obdii.screenmodels.MainScaffoldScreenModel
import com.rheosoft.obdii.screenmodels.MainScaffoldCupertinoScreenModel
import kotlin.test.Test
import kotlin.test.assertNotNull

class ViewControllerParityTest {
    @Test
    fun `material and cupertino scaffolds exist`() {
        assertNotNull(MainScaffoldScreenModel())
        assertNotNull(MainScaffoldCupertinoScreenModel())
    }
}

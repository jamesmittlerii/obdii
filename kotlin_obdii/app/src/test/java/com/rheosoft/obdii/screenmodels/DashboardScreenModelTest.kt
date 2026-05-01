package com.rheosoft.obdii.screenmodels

import com.rheosoft.obdii.core.DefaultPidStore
import com.rheosoft.obdii.core.GaugesDisplayMode
import com.rheosoft.obdii.viewmodels.GaugesViewModel
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class GaugesViewTest {
    @Test
    fun `dashboard view composes with gauges viewmodel`() = runTest {
        DefaultPidStore.resetForTests()
        DefaultPidStore.load()
        val vm = GaugesViewModel(pidProvider = DefaultPidStore)
        val view = DashboardScreenModel(vm, GaugesDisplayMode.gauges)
        assertNotNull(view.viewModel)
        assertEquals("Gauges", view.title)
        view.setMode(GaugesDisplayMode.list)
        assertEquals("List", view.title)
        assertTrue(view.isEmptyState)
    }
}

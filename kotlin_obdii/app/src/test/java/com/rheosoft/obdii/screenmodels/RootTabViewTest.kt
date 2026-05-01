package com.rheosoft.obdii.screenmodels

import kotlin.test.Test
import kotlin.test.assertEquals

class RootTabViewTest {
    @Test
    fun `root tab has five destinations and starts on settings`() {
        val scaffold = MainScaffoldScreenModel()
        assertEquals(5, MainScaffoldScreenModel.destinations.size)
        assertEquals("Settings", scaffold.selectedDestination)
    }

    @Test
    fun `switching tabs updates destination and activity flags`() {
        val scaffold = MainScaffoldScreenModel()
        scaffold.onDestinationSelected(3)
        assertEquals("MIL", scaffold.selectedDestination)
        val flags = scaffold.pageActivityFlags()
        assertEquals(false, flags["Gauges"])
        assertEquals(false, flags["Fuel"])
        assertEquals(true, flags["MIL"])
        assertEquals(false, flags["DTCs"])
    }
}

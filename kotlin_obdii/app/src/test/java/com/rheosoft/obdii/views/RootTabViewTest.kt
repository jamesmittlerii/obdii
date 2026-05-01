package com.rheosoft.obdii.views

import kotlin.test.Test
import kotlin.test.assertEquals

class RootTabViewTest {
    @Test
    fun `root tab has five destinations and starts on settings`() {
        val scaffold = MainScaffold()
        assertEquals(5, MainScaffold.destinations.size)
        assertEquals("Settings", scaffold.selectedDestination)
    }

    @Test
    fun `switching tabs updates destination and activity flags`() {
        val scaffold = MainScaffold()
        scaffold.onDestinationSelected(3)
        assertEquals("MIL", scaffold.selectedDestination)
        val flags = scaffold.pageActivityFlags()
        assertEquals(false, flags["Gauges"])
        assertEquals(false, flags["Fuel"])
        assertEquals(true, flags["MIL"])
        assertEquals(false, flags["DTCs"])
    }
}

package com.rheosoft.obdii.views

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

class MainScaffoldTest {
    @Test
    fun `main scaffold has five destinations and starts on settings`() {
        val scaffold = MainScaffold()
        assertNotNull(scaffold)
        assertEquals(listOf("Settings", "Gauges", "Fuel", "MIL", "DTCs"), MainScaffold.destinations)
        assertEquals("Settings", scaffold.selectedDestination)
    }

    @Test
    fun `main scaffold can switch tabs`() {
        val scaffold = MainScaffold()
        scaffold.onDestinationSelected(1)
        assertEquals("Gauges", scaffold.selectedDestination)
        scaffold.onDestinationSelected(4)
        assertEquals("DTCs", scaffold.selectedDestination)
    }

    @Test
    fun `cupertino scaffold is instantiable`() {
        assertNotNull(MainScaffoldCupertino())
    }
}

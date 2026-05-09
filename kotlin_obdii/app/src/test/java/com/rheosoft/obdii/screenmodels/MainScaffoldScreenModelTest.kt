package com.rheosoft.obdii.screenmodels

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue
import kotlin.test.assertFalse

class MainScaffoldTest {
    @Test
    fun `main scaffold has five destinations and starts on settings`() {
        val scaffold = MainScaffoldScreenModel()
        assertNotNull(scaffold)
        assertEquals(listOf("Settings", "Gauges", "Fuel", "MIL", "DTCs"), MainScaffoldScreenModel.destinations)
        assertEquals("Settings", scaffold.selectedDestination)
    }

    @Test
    fun `main scaffold can switch tabs`() {
        val scaffold = MainScaffoldScreenModel()
        scaffold.onDestinationSelected(1)
        assertEquals("Gauges", scaffold.selectedDestination)
        scaffold.onDestinationSelected(4)
        assertEquals("DTCs", scaffold.selectedDestination)
        
        // Invalid index
        scaffold.onDestinationSelected(10)
        assertEquals("DTCs", scaffold.selectedDestination)
        scaffold.onDestinationSelected(-1)
        assertEquals("DTCs", scaffold.selectedDestination)
    }

    @Test
    fun `pageActivityFlags reflecting state`() {
        val scaffold = MainScaffoldScreenModel()
        
        scaffold.onDestinationSelected(1) // Gauges
        val flags1 = scaffold.pageActivityFlags()
        assertTrue(flags1["Gauges"] == true)
        assertFalse(flags1["Fuel"] == true)

        scaffold.onDestinationSelected(2) // Fuel
        val flags2 = scaffold.pageActivityFlags()
        assertTrue(flags2["Fuel"] == true)
        assertFalse(flags2["Gauges"] == true)
    }

    @Test
    fun `cupertino scaffold is instantiable`() {
        assertNotNull(MainScaffoldCupertinoScreenModel())
    }
}

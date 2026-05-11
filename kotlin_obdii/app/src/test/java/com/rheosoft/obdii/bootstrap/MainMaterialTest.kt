package com.rheosoft.obdii.bootstrap

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class MainMaterialTest {
    @Test
    fun `material app spec mirrors flutter material shell`() {
        val spec = MainMaterial.appSpec
        assertEquals("Rheosoft OBDII", spec.title)
        assertFalse(spec.debugShowCheckedModeBanner)
        assertTrue(spec.useMaterial3)
        assertEquals("#00C2FF", spec.seedColorHex)
        assertEquals(listOf("en_US"), spec.supportedLocales)
        assertEquals("system", spec.themeMode)
        assertEquals("MainScaffoldScreenModel", spec.home)
    }
}

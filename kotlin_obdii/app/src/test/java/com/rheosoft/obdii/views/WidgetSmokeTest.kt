package com.rheosoft.obdii.views

import com.rheosoft.obdii.bootstrap.MainMaterial
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse

class WidgetSmokeTest {
    @Test
    fun `material app spec matches flutter shell defaults`() {
        val spec = MainMaterial.appSpec
        assertEquals("Rheosoft OBDII", spec.title)
        assertFalse(spec.debugShowCheckedModeBanner)
        assertEquals(true, spec.useMaterial3)
        assertEquals("system", spec.themeMode)
        assertEquals("MainScaffold", spec.home)
    }
}

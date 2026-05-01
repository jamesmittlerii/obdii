package com.rheosoft.obdii.core

import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

class PidInterestRegistryTest {
    @Test
    fun `tokens are unique`() {
        val registry = PidInterestRegistry()
        val t1 = registry.makeToken()
        val t2 = registry.makeToken()
        assertNotEquals(t1, t2)
    }

    @Test
    fun `replace updates interested union`() {
        val registry = PidInterestRegistry()
        val token = registry.makeToken()
        registry.replace(setOf("010C", "010D"), token)
        assertTrue(registry.interested.contains("010C"))
        assertTrue(registry.interested.contains("010D"))
    }

    @Test
    fun `clear removes token pids`() = runTest {
        val registry = PidInterestRegistry()
        val t1 = registry.makeToken()
        val t2 = registry.makeToken()
        registry.replace(setOf("010C"), t1)
        registry.replace(setOf("010D"), t2)
        registry.clear(t1)
        assertFalse(registry.interested.contains("010C"))
        assertTrue(registry.interested.contains("010D"))
        assertEquals(1, registry.interested.size)
    }
}

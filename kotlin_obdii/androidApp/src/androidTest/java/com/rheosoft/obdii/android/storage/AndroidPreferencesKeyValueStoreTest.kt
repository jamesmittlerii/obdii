package com.rheosoft.obdii.android.storage

import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AndroidPreferencesKeyValueStoreTest {
    private lateinit var context: Context

    @Before
    fun setUp() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        context.getSharedPreferences(TEST_PREFS, Context.MODE_PRIVATE).edit().clear().commit()
        context.getSharedPreferences(APP_PREFS, Context.MODE_PRIVATE).edit().clear().commit()
    }

    @Test
    fun missingKeysReturnNull() {
        val store = testStore()

        assertNull(store.getString("missing_string"))
        assertNull(store.getInt("missing_int"))
        assertNull(store.getBoolean("missing_boolean"))
    }

    @Test
    fun storesAndReadsSupportedValueTypes() {
        val store = testStore()

        store.putString("host", "192.168.0.10")
        store.putInt("port", 35000)
        store.putBoolean("auto_connect", true)

        assertEquals("192.168.0.10", store.getString("host"))
        assertEquals(35000, store.getInt("port"))
        assertEquals(true, store.getBoolean("auto_connect"))
    }

    @Test
    fun overwritesExistingValues() {
        val store = testStore()

        store.putString("connection_type", "bluetooth")
        store.putString("connection_type", "demo")
        store.putInt("port", 35000)
        store.putInt("port", 35001)
        store.putBoolean("auto_connect", true)
        store.putBoolean("auto_connect", false)

        assertEquals("demo", store.getString("connection_type"))
        assertEquals(35001, store.getInt("port"))
        assertEquals(false, store.getBoolean("auto_connect"))
    }

    @Test
    fun factoryUsesAppPreferences() {
        val store = AndroidPreferencesKeyValueStore.from(context)

        store.putString("factory_key", "factory_value")

        val appPrefs = context.getSharedPreferences(APP_PREFS, Context.MODE_PRIVATE)
        assertEquals("factory_value", appPrefs.getString("factory_key", null))
    }

    private fun testStore(): AndroidPreferencesKeyValueStore {
        val prefs = context.getSharedPreferences(TEST_PREFS, Context.MODE_PRIVATE)
        return AndroidPreferencesKeyValueStore(prefs)
    }

    private companion object {
        const val TEST_PREFS = "android_preferences_key_value_store_test"
        const val APP_PREFS = "kotlin_obdii_prefs"
    }
}

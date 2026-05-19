package com.rheosoft.obdii.windows.ui.screens

import com.rheosoft.obdii.core.KeyValueStore
import java.io.File
import java.util.Properties

class DesktopPreferencesKeyValueStore : KeyValueStore {
    private val prefsFile = File(System.getProperty("user.home"), ".obdii_prefs.properties")
    private val properties = Properties()

    init {
        if (prefsFile.exists()) {
            runCatching {
                prefsFile.inputStream().use { properties.load(it) }
            }
        }
    }

    override fun putString(key: String, value: String) {
        properties.setProperty(key, value)
        save()
    }

    override fun putInt(key: String, value: Int) {
        properties.setProperty(key, value.toString())
        save()
    }

    override fun putBoolean(key: String, value: Boolean) {
        properties.setProperty(key, value.toString())
        save()
    }

    override fun getString(key: String): String? {
        return properties.getProperty(key)
    }

    override fun getInt(key: String): Int? {
        return properties.getProperty(key)?.toIntOrNull()
    }

    override fun getBoolean(key: String): Boolean? {
        return properties.getProperty(key)?.toBooleanStrictOrNull()
    }

    private fun save() {
        runCatching {
            prefsFile.outputStream().use { properties.store(it, "Kotlin OBDII Desktop Preferences") }
        }
    }
}

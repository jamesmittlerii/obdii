package com.rheosoft.obdii.android.storage

import android.content.Context
import android.content.SharedPreferences
import com.rheosoft.obdii.core.KeyValueStore

class AndroidPreferencesKeyValueStore(private val prefs: SharedPreferences) : KeyValueStore {
    override fun putString(key: String, value: String) {
        prefs.edit().putString(key, value).apply()
    }

    override fun putInt(key: String, value: Int) {
        prefs.edit().putInt(key, value).apply()
    }

    override fun putBoolean(key: String, value: Boolean) {
        prefs.edit().putBoolean(key, value).apply()
    }

    override fun getString(key: String): String? = prefs.getString(key, null)

    override fun getInt(key: String): Int? = if (prefs.contains(key)) prefs.getInt(key, 0) else null

    override fun getBoolean(key: String): Boolean? = if (prefs.contains(key)) prefs.getBoolean(key, false) else null

    companion object {
        private const val PREF_NAME = "kotlin_obdii_prefs"

        fun from(context: Context): AndroidPreferencesKeyValueStore {
            val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            return AndroidPreferencesKeyValueStore(prefs)
        }
    }
}

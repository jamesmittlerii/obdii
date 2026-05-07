package com.rheosoft.obdii.android.bootstrap

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.core.content.pm.PackageInfoCompat
import com.rheosoft.obdii.android.ble.AndroidBlePlatformAdapter
import com.rheosoft.obdii.android.ble.NordicBlePlatformAdapter
import com.rheosoft.obdii.android.storage.AndroidPreferencesKeyValueStore
import com.rheosoft.obdii.core.ConfigData
import com.rheosoft.obdii.core.DefaultPidStore
import com.rheosoft.obdii.core.OBDConnectionManager
import com.rheosoft.obdii.core.ObdLogger
import com.rheosoft.obdii.viewmodels.SettingsViewModel

object AndroidAppInitializer {
    private var initialized = false

    fun initialize(context: Context) {
        if (initialized) return
        initialized = true

        // Initialize logging to use Android Log instead of System.out
        ObdLogger.platformLogDelegate = { message, tag, level ->
            // Detect intermediate states that aren't explicit enums in the library
            if (message.contains("Initializing vehicle connection")) {
                OBDConnectionManager.setSettingUpVehicle()
            }

            val emoji = ObdLogger.getEmoji(level)
            val fullMessage = "[$emoji] $message"
            when (level.lowercase()) {
                "error" -> Log.e(tag, fullMessage)
                "warning" -> Log.w(tag, fullMessage)
                "info" -> Log.i(tag, fullMessage)
                else -> Log.d(tag, fullMessage)
            }
        }
        ObdLogger.mutesConsole = true // Stop System.out to avoid double logging

        val persistentStore = AndroidPreferencesKeyValueStore.from(context)
        ConfigData.store = persistentStore
        ConfigData.load()
        DefaultPidStore.store = persistentStore

        val bleAdapter = if (SettingsViewModel.USE_NORDIC_BLE) {
            NordicBlePlatformAdapter(context)
        } else {
            AndroidBlePlatformAdapter(context)
        }
        OBDConnectionManager.setBleAdapter(bleAdapter)
    }

    fun getAppVersion(context: Context): String {
        return try {
            val p = context.packageManager.getPackageInfo(context.packageName, 0)
            val appName = context.applicationInfo.loadLabel(context.packageManager).toString()
            "$appName v${p.versionName} build:${PackageInfoCompat.getLongVersionCode(p)}"
        } catch (e: Exception) {
            "Unknown version"
        }
    }

    fun hasBluetoothPermissions(context: Context): Boolean {
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
            )
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        return permissions.all {
            ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED
        }
    }
}

package com.rheosoft.obdii.android

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.rheosoft.obdii.android.ble.AndroidBlePlatformAdapter
import com.rheosoft.obdii.android.storage.AndroidPreferencesKeyValueStore
import com.rheosoft.obdii.android.views.KotlinObdiiApp
import com.rheosoft.obdii.core.ConfigData
import com.rheosoft.obdii.core.DefaultPidStore
import com.rheosoft.obdii.core.OBDConnectionManager

class MainActivity : ComponentActivity() {
    private val runtimePermissions: Array<String>
        get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.ACCESS_FINE_LOCATION,
            )
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val persistentStore = AndroidPreferencesKeyValueStore.from(this)
        ConfigData.store = persistentStore
        DefaultPidStore.store = persistentStore
        OBDConnectionManager.setBleAdapter(AndroidBlePlatformAdapter(this))
        requestBluetoothPermissionsIfNeeded()
        setContent { KotlinObdiiApp() }
    }

    private fun requestBluetoothPermissionsIfNeeded() {
        val missing = runtimePermissions.filter { perm ->
            ContextCompat.checkSelfPermission(this, perm) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, missing.toTypedArray(), 1001)
        }
    }
}

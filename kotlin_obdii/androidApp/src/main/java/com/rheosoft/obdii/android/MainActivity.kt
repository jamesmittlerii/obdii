package com.rheosoft.obdii.android

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.rheosoft.obdii.android.ble.AndroidBlePlatformAdapter
import com.rheosoft.obdii.android.storage.AndroidPreferencesKeyValueStore
import com.rheosoft.obdii.android.ui.screens.KotlinObdiiApp
import com.rheosoft.obdii.core.ConfigData
import com.rheosoft.obdii.core.DefaultPidStore
import com.rheosoft.obdii.core.OBDConnectionManager

class MainActivity : ComponentActivity() {
    private var permissionsReady by mutableStateOf(false)

    private val runtimePermissions: Array<String>
        get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
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
        permissionsReady = hasBluetoothPermissions()
        requestBluetoothPermissionsIfNeeded()
        setContent { KotlinObdiiApp(permissionsReady = permissionsReady) }
    }

    private fun requestBluetoothPermissionsIfNeeded() {
        val missing = missingBluetoothPermissions()
        if (missing.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, missing.toTypedArray(), 1001)
        }
    }

    private fun hasBluetoothPermissions(): Boolean = missingBluetoothPermissions().isEmpty()

    private fun missingBluetoothPermissions(): List<String> =
        runtimePermissions.filter { perm ->
            ContextCompat.checkSelfPermission(this, perm) != PackageManager.PERMISSION_GRANTED
        }

    @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1001) {
            permissionsReady = hasBluetoothPermissions()
        }
    }
}

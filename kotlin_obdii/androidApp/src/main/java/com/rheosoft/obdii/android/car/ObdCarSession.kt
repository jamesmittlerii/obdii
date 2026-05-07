package com.rheosoft.obdii.android.car

import android.content.Intent
import android.util.Log
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.lifecycle.lifecycleScope
import com.rheosoft.obdii.android.bootstrap.AndroidAppInitializer
import com.rheosoft.obdii.android.ui.screens.loadPidsFromJson
import com.rheosoft.obdii.android.ui.screens.defaultGaugeSeedPids
import com.rheosoft.obdii.core.DefaultPidStore
import com.rheosoft.obdii.bootstrap.AppBootstrap
import com.rheosoft.obdii.core.ConfigData
import com.rheosoft.obdii.core.OBDConnectionManager
import kotlinx.coroutines.launch

class ObdCarSession : Session() {
    override fun onCreateScreen(intent: Intent): Screen {
        Log.d("ObdCarSession", "onCreateScreen")
        AndroidAppInitializer.initialize(carContext)

        // 1. Core Data Initialization (Sync)
        // This ensures PID storage is available before ViewModels are created.
        if (DefaultPidStore.pids.isEmpty()) {
            val pidsFromJson = loadPidsFromJson(carContext)
            DefaultPidStore.seededPidsProvider = { if (pidsFromJson.isNotEmpty()) pidsFromJson else defaultGaugeSeedPids() }
        }
        
        // 2. Async Bootstrap
        lifecycleScope.launch {
            try {
                AppBootstrap.initialize()
                
                // Auto-connect if enabled and permissions are ready
                if (ConfigData.autoConnectToOBD && AndroidAppInitializer.hasBluetoothPermissions(carContext)) {
                    runCatching { OBDConnectionManager.connect() }
                }
            } catch (e: Exception) {
                Log.e("ObdCarSession", "Initialization failed", e)
            }
        }

        return MainCarScreen(carContext)
    }
}

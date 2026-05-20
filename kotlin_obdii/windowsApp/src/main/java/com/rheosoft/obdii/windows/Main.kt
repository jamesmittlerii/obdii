package com.rheosoft.obdii.windows

import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.rheosoft.obdii.core.OBDConnectionManager
import com.rheosoft.obdii.windows.ble.forceWindowsProcessExit
import com.rheosoft.obdii.windows.bootstrap.WindowsAppInitializer
import com.rheosoft.obdii.windows.ui.screens.KotlinObdiiApp

fun main() = application {
    val appIcon = painterResource("drawable/new-obd2-512.png")
    val windowState = rememberWindowState(width = 420.dp, height = 840.dp)
    Window(
        onCloseRequest = {
            runCatching { OBDConnectionManager.disconnect() }
            runCatching { WindowsAppInitializer.shutdown() }
            exitApplication()
            forceWindowsProcessExit()
        },
        title = "OBDII Windows",
        icon = appIcon,
        state = windowState
    ) {
        MaterialTheme {
            KotlinObdiiApp()
        }
    }
}

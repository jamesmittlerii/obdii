package com.rheosoft.obdii.windows

import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import com.rheosoft.obdii.core.OBDConnectionManager
import com.rheosoft.obdii.windows.ble.forceWindowsProcessExit
import com.rheosoft.obdii.windows.bootstrap.WindowsAppInitializer
import com.rheosoft.obdii.windows.generated.resources.Res
import com.rheosoft.obdii.windows.generated.resources.new_obd2_512
import com.rheosoft.obdii.windows.ui.screens.KotlinObdiiApp
import org.jetbrains.compose.resources.painterResource

fun main() = application {
    val appIcon = painterResource(Res.drawable.new_obd2_512)
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

package com.rheosoft.obdii.windows

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.Modifier
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.rheosoft.obdii.windows.ui.screens.KotlinObdiiApp

fun main() = application {
    val appIcon = painterResource("drawable/new-obd2-512.png")
    val windowState = rememberWindowState(width = 420.dp, height = 840.dp)
    Window(
        onCloseRequest = ::exitApplication,
        title = "OBDII Windows",
        icon = appIcon,
        state = windowState
    ) {
        MaterialTheme {
            KotlinObdiiApp()
        }
    }
}



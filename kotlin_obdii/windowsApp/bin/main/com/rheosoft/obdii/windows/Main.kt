package com.rheosoft.obdii.windows

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.Modifier
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import com.rheosoft.obdii.windows.ui.screens.KotlinObdiiApp

fun main() = application {
    Window(
        onCloseRequest = ::exitApplication,
        title = "OBDII Windows"
    ) {
        MaterialTheme {
            KotlinObdiiApp()
        }
    }
}


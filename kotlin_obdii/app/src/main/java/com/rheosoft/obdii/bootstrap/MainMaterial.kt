package com.rheosoft.obdii.bootstrap

import com.rheosoft.obdii.views.MainScaffold

data class MaterialAppSpec(
    val title: String,
    val debugShowCheckedModeBanner: Boolean,
    val useMaterial3: Boolean,
    val seedColorHex: String,
    val supportedLocales: List<String>,
    val themeMode: String,
    val home: String,
)

object MainMaterial {
    val appSpec = MaterialAppSpec(
        title = "Rheosoft OBDII",
        debugShowCheckedModeBanner = false,
        useMaterial3 = true,
        seedColorHex = "#00C2FF",
        supportedLocales = listOf("en_US"),
        themeMode = "system",
        home = MainScaffold::class.simpleName ?: "MainScaffold",
    )

    suspend fun run() {
        AppBootstrap.initialize()
    }
}

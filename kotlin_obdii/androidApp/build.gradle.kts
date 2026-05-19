import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = project.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.rheosoft.obdii.android"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.rheosoft.obdiik"
        minSdk = 29
        targetSdk = 36
        versionCode = 216
        versionName = "0.4.20"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storePassword = keystoreProperties.getProperty("storePassword")
                storeFile = project.file(keystoreProperties.getProperty("storeFile"))
            }
        }
    }

    buildTypes {
        debug {
            enableAndroidTestCoverage = true
            enableUnitTestCoverage = true
        }

        release {
            isMinifyEnabled = false
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }



    sourceSets {
        getByName("main") {
            // Use the directories API with a raw string path
            assets.directories.add("../../flutter_obdii/assets")
        }
    }
}

dependencies {
    implementation(project(":coreApp"))
    if (findProject(":kotlinobd2") != null) {
        implementation(project(":kotlinobd2"))
    } else {
        implementation("com.github.jamesmittlerii:SwiftOBD2:0.1.6")
    }
    implementation("androidx.core:core-ktx:1.18.0")
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.compose.ui:ui:1.11.0")
    implementation("androidx.compose.material3:material3:1.4.0")
    implementation("androidx.compose.material:material-icons-extended:1.7.8")
    implementation("androidx.compose.ui:ui-tooling-preview:1.11.0")
    debugImplementation("androidx.compose.ui:ui-tooling:1.11.0")

    implementation("androidx.car.app:app:1.7.0")

    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.7.0")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4:1.11.0")
    debugImplementation("androidx.compose.ui:ui-test-manifest:1.11.0")

    // Nordic BLE Library
    implementation("no.nordicsemi.android:ble:2.11.0")
    implementation("no.nordicsemi.android:ble-ktx:2.11.0")
}

tasks.register<Exec>("runDebug") {
    group = "application"
    description =
        "Installs and launches the debug app. With multiple devices, set ANDROID_SERIAL or -PandroidSerial=<id>."
    dependsOn("installDebug")
    val serial =
        (findProperty("androidSerial") as String?)?.takeIf { it.isNotBlank() }
            ?: System.getenv("ANDROID_SERIAL")?.takeIf { it.isNotBlank() }
    commandLine(
        buildList {
            add("adb")
            if (serial != null) {
                add("-s")
                add(serial)
            }
            addAll(
                listOf(
                    "shell",
                    "am",
                    "start",
                    "-n",
                    "com.rheosoft.obdiik/com.rheosoft.obdii.android.MainActivity",
                ),
            )
        },
    )
}

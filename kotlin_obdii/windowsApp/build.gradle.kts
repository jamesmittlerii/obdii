import org.gradle.api.file.DuplicatesStrategy
import org.gradle.api.tasks.JavaExec
import org.jetbrains.compose.desktop.application.dsl.TargetFormat
import java.io.File
import java.net.URI

plugins {
    id("org.jetbrains.kotlin.jvm")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.compose")
}

version = "0.4.32"

dependencies {
    implementation(project(":windowsBle"))
    implementation(project(":coreApp"))
    if (findProject(":kotlinobd2") != null) {
        implementation(project(":kotlinobd2"))
    } else {
        implementation("com.github.jamesmittlerii:SwiftOBD2:0.1.15")
    }

    // Compose Desktop dependencies
    implementation(compose.desktop.currentOs)
    implementation(compose.material3)
    implementation(compose.ui)
    implementation(compose.foundation)
    implementation(compose.materialIconsExtended)
    implementation(compose.components.resources)
    // Coroutines & Data
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-swing:1.10.2")
    implementation("com.google.code.gson:gson:2.14.0")
}

compose.resources {
    packageOfResClass = "com.rheosoft.obdii.windows.generated.resources"
}

compose.desktop {
    application {
        mainClass = "com.rheosoft.obdii.windows.MainKt"
        jvmArgs += listOf(
            "-Dapp.version=${project.version}",
            "--enable-native-access=ALL-UNNAMED",
            "-Dfile.encoding=UTF-8",
            "-Dsun.stdout.encoding=UTF-8",
            "-Dsun.stderr.encoding=UTF-8",
        )


        nativeDistributions {
            targetFormats(TargetFormat.Dmg, TargetFormat.Msi, TargetFormat.Deb)
            packageName = "OBDII_Windows"
            packageVersion = "1.0.0"
            windows {
                iconFile.set(project.file("src/main/resources/app_icon.ico"))
            }
        }
    }
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(21))
    }
}

// forceWindowsProcessExit() uses taskkill on Windows; that exits the JVM with code 1.
afterEvaluate {
    val runTasks = setOf("run", "runDistributable", "runRelease", "runReleaseDistributable")
    tasks.withType<JavaExec>().matching { it.name in runTasks }.configureEach {
        isIgnoreExitValue = true
    }
}

sourceSets {
    main {
        resources.srcDirs("../../flutter_obdii/assets")
    }
}

tasks.register("testEmoji") {
    doLast {
        println("🔵 ⚪ 🟡 🔴 Test Emoji")
    }
}

tasks.register<Jar>("standaloneJar") {
    group = "distribution"
    description = "Builds a self-contained runnable jar for the Windows desktop app."
    dependsOn("classes")

    archiveBaseName.set("obdii-windows")
    archiveClassifier.set("standalone")
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE

    manifest {
        attributes["Main-Class"] = "com.rheosoft.obdii.windows.MainKt"
    }

    from(sourceSets.main.get().output)
    from({
        sourceSets.main.get().runtimeClasspath.files
            .filter { it.exists() }
            .map { file -> if (file.isDirectory) file else zipTree(file) }
    })

    exclude(
        "META-INF/*.DSA",
        "META-INF/*.RSA",
        "META-INF/*.SF",
    )
}

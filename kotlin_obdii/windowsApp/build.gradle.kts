import org.gradle.api.file.DuplicatesStrategy
import org.jetbrains.compose.desktop.application.dsl.TargetFormat
import java.io.File
import java.net.URI

plugins {
    id("org.jetbrains.kotlin.jvm")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.compose")
}

version = "0.4.18"

val simpleBleVersion = "0.14.0"
val simpleBleJarName = "simplejavable-v$simpleBleVersion.jar"

tasks.register("downloadSimpleBle") {
    val jarFile = layout.projectDirectory.file("libs/$simpleBleJarName")
    val downloadUrl = "https://github.com/simpleble/simpleble/releases/download/v$simpleBleVersion/$simpleBleJarName"
    outputs.file(jarFile)
    onlyIf { !jarFile.asFile.exists() }
    doLast {
        val target = jarFile.asFile
        target.parentFile.mkdirs()
        URI(downloadUrl).toURL().openStream().use { input ->
            target.outputStream().use { output -> input.copyTo(output) }
        }
        logger.lifecycle("Downloaded SimpleJavaBLE to ${target.absolutePath}")
    }
}

tasks.named("compileKotlin") {
    dependsOn("downloadSimpleBle")
}

dependencies {
    implementation(project(":coreApp"))
    if (findProject(":kotlinobd2") != null) {
        implementation(project(":kotlinobd2"))
    } else {
        implementation("com.github.jamesmittlerii:SwiftOBD2:0.1.3")
    }

    // Compose Desktop dependencies
    implementation(compose.desktop.currentOs)
    implementation(compose.material3)
    implementation(compose.ui)
    implementation(compose.foundation)
    implementation(compose.materialIconsExtended)
    // Coroutines & Data
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-swing:1.10.2")
    implementation("com.google.code.gson:gson:2.14.0")
    implementation(files("libs/$simpleBleJarName"))
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

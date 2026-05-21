import org.gradle.api.file.DuplicatesStrategy

plugins {
    id("org.jetbrains.kotlin.jvm")
    application
}

dependencies {
    implementation(project(":windowsBle"))
    if (findProject(":kotlinobd2") != null) {
        implementation(project(":kotlinobd2"))
    } else {
        implementation("com.github.jamesmittlerii:SwiftOBD2:0.1.8")
    }
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
}

application {
    mainClass.set("com.rheosoft.obdii.windows.bleprobe.BleProbeMainKt")
    applicationDefaultJvmArgs = listOf(
        "--enable-native-access=ALL-UNNAMED",
        "-Dfile.encoding=UTF-8",
    )
}

// taskkill self exits non-zero; probe success is determined from log output.
tasks.named<JavaExec>("run") {
    isIgnoreExitValue = true
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(21))
    }
}

tasks.register<Jar>("standaloneProbeJar") {
    group = "distribution"
    description = "Fat jar for the BLE shutdown probe (no Compose UI)."
    dependsOn("classes")
    archiveBaseName.set("obdii-ble-probe")
    archiveClassifier.set("standalone")
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
    manifest {
        attributes["Main-Class"] = "com.rheosoft.obdii.windows.bleprobe.BleProbeMainKt"
    }
    from(sourceSets.main.get().output)
    from({
        sourceSets.main.get().runtimeClasspath.files
            .filter { it.exists() }
            .map { file -> if (file.isDirectory) file else zipTree(file) }
    })
    exclude("META-INF/*.DSA", "META-INF/*.RSA", "META-INF/*.SF")
}

pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}

val isCi = System.getenv("CI") == "true" || System.getenv("GITHUB_ACTIONS") == "true"

rootProject.name = "kotlin_obdii"
include(":coreApp")
include(":androidApp")
include(":windowsApp")
project(":coreApp").projectDir = file("app")

val kotlinObd2DirEnv = System.getenv("KOTLINOBD2_DIR")
val kotlinObd2Dir = if (!kotlinObd2DirEnv.isNullOrBlank()) {
    file(kotlinObd2DirEnv)
} else {
    file("../../SwiftOBD2/kotlinobd2")
}

if (!isCi && kotlinObd2Dir.exists()) {
    include(":kotlinobd2")
    project(":kotlinobd2").projectDir = kotlinObd2Dir
} else if (!isCi) {
    println("Warning: kotlinobd2 module not found locally at ${kotlinObd2Dir.absolutePath}. Falling back to JitPack.")
}

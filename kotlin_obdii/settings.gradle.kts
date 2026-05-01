pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "kotlin_obdii"
include(":app")
include(":androidApp")
include(":kotlinobd2")
val kotlinObd2DirEnv = System.getenv("KOTLINOBD2_DIR")
val kotlinObd2Dir = if (!kotlinObd2DirEnv.isNullOrBlank()) {
    file(kotlinObd2DirEnv)
} else {
    file("../../SwiftOBD2/kotlinobd2")
}
require(kotlinObd2Dir.exists()) {
    "kotlinobd2 module not found at: ${kotlinObd2Dir.absolutePath}. " +
        "Set KOTLINOBD2_DIR to the checked-out SwiftOBD2/kotlinobd2 path."
}
project(":kotlinobd2").projectDir = kotlinObd2Dir

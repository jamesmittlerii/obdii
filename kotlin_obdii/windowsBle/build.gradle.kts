import java.net.URI

plugins {
    id("org.jetbrains.kotlin.jvm")
}

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
    if (findProject(":kotlinobd2") != null) {
        implementation(project(":kotlinobd2"))
    } else {
        implementation("com.github.jamesmittlerii:SwiftOBD2:0.1.9")
    }
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
    api(files("libs/$simpleBleJarName"))
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(21))
    }
}

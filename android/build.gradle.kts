allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: org.gradle.api.file.Directory =
    rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: org.gradle.api.file.Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")

    // file_picker (through 12.0.0-beta) ships an android/build.gradle that applies
    // com.android.library but never the Kotlin plugin. Older AGP supplied Kotlin
    // globally so its .kt sources compiled anyway; under AGP 9's decoupled Kotlin
    // the module gets no Kotlin compilation, so FilePickerPlugin is never built and
    // the app fails with "cannot find symbol FilePickerPlugin". Apply the Kotlin
    // Android plugin to that module ourselves until upstream ships the fix.
    // https://github.com/miguelpruivo/flutter_file_picker/issues/1973
    if (project.name == "file_picker") {
        project.plugins.apply("org.jetbrains.kotlin.android")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

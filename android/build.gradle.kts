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

    // Force every Android module (app + plugins, incl. flutter_gemma's :jni) onto
    // the same NDK version. Plugins otherwise request a mix of versions (Flutter's
    // default 27.x plus flutter_gemma's 28.2.x), so the build downloads several
    // NDKs — and each download is a chance for the runner's flaky SDK fetch to
    // corrupt ("Archive is not a ZIP archive"). One version = one pre-installable
    // NDK. Set via reflection so the root project needs no AGP types on its
    // classpath.
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            runCatching {
                ext.javaClass.getMethod("setNdkVersion", String::class.java)
                    .invoke(ext, "28.2.13676358")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

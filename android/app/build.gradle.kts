import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    jacoco
}

// Release signing is read from android/key.properties when present (created in
// CI from GitHub Secrets). Without it, the build falls back to debug signing.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.transcriber.app"
    // receive_sharing_intent 1.9.0+ requires compiling against API 37 or later
    // (AAR metadata check); see CheckAarMetadata failure on compileSdk 36.
    compileSdk = 37
    // Pinned so the whole build uses one NDK (see android/build.gradle.kts) and
    // CI can pre-install exactly this version reliably.
    ndkVersion = "28.2.13676358"

    testOptions {
        unitTests.isIncludeAndroidResources = true
    }

    testCoverage {
        jacocoVersion = "0.8.14"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.transcriber.app"
        // minSdk 26 for adaptive icons and the supported Android plugins.
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        ndk {
            // arm64-v8a only: every real Android device is arm64. x86_64 is just
            // for emulators and would increase packaging cost. Flutter 3.35+
            // pre-sets abiFilters to all three ABIs before this
            // file runs, so clear() is required or arm64-v8a just gets added
            // alongside them.
            // https://docs.flutter.dev/release/breaking-changes/default-abi-filters-android
            abiFilters.clear()
            abiFilters.add("arm64-v8a")
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            enableAndroidTestCoverage = true
        }
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.17")
    testImplementation("org.mockito:mockito-core:5.24.0")
    // Keep Kotlin's runtime lock graph stable (Gradle issue 21396).
    testRuntimeOnly("org.jetbrains.kotlin:kotlin-stdlib-common:2.4.21")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
}

// Keep the complete native unit-test graph reviewable and available to OSV.
configurations.matching {
    it.name in setOf("debugUnitTestCompileClasspath", "debugUnitTestRuntimeClasspath")
}.configureEach {
    resolutionStrategy.activateDependencyLocking()
}

// Resolve the exact sandbox SDKs through Gradle so the audit sees runtime downloads too.
val robolectricSdks = listOf(
    "8.1.0-robolectric-4611349-i7",
    "9-robolectric-4913185-2-i7",
    "15-robolectric-13954326-i7",
).mapIndexed { index, version ->
    configurations.create("robolectricSdk$index") {
        isCanBeConsumed = false
        isCanBeResolved = true
        resolutionStrategy.activateDependencyLocking()
    }.also {
        dependencies.add(it.name, "org.robolectric:android-all-instrumented:$version")
    }
}
val sandboxDirectory = layout.buildDirectory.dir("robolectric-sdks")
val prepareRobolectricSdks = tasks.register<Sync>("prepareRobolectricSdks") {
    from(robolectricSdks)
    into(sandboxDirectory)
}
tasks.withType<Test>().configureEach {
    dependsOn(prepareRobolectricSdks)
    inputs.files(robolectricSdks).withPropertyName("robolectricSdks")
        .withPathSensitivity(PathSensitivity.NAME_ONLY)
    systemProperty("robolectric.offline", "true")
    systemProperty("robolectric.dependency.dir", sandboxDirectory.get().asFile.absolutePath)
}

// Built-in Kotlin (AGP 9+): the Kotlin toolchain is configured via the new
// kotlin.compilerOptions DSL instead of the legacy android.kotlinOptions block.
// See https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

extra["requiredTestSourceRoot"] = file("src/test/kotlin")
extra["requiredTestSourceFiles"] = fileTree("src/test/kotlin") {
    include("**/*Test.kt")
}.files
apply(from = rootProject.file("../tool/ci/jvm/require_executed_tests.gradle.kts"))

extra["coverageSources"] = fileTree("src/main/kotlin") { include("**/*.kt") }.files
extra["coverageSourceRoot"] = file("src/main/kotlin")
extra["coverageClassDirectories"] = files(layout.buildDirectory.dir("tmp/kotlin-classes/debug"))
extra["coverageTestTask"] = "testDebugUnitTest"
extra["coverageDeviceTask"] = "connectedDebugAndroidTest"
apply(from = rootProject.file("../tool/ci/jvm/native_coverage.gradle.kts"))

// Robolectric's resource APK consumes the Flutter assets produced by this task.
tasks.matching { it.name == "packageDebugUnitTestForUnitTest" }.configureEach {
    dependsOn("copyFlutterAssetsDebug")
}

import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
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

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.transcriber.app"
        // minSdk 26 for adaptive icons + on-device ML (flutter_gemma / ffmpeg).
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            // arm64-v8a only: every real Android device is arm64. x86_64 is just
            // for emulators and would double the packaging cost of the large
            // ffmpeg-kit / flutter_gemma native libraries.
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

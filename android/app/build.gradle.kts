import org.gradle.api.artifacts.component.ModuleComponentIdentifier
import org.gradle.api.artifacts.dsl.LockMode
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val testApk = providers.environmentVariable("TRANSCRIBER_TEST_APK").orNull == "true"
val androidTestResults = layout.buildDirectory.dir("outputs/androidTest-results").get().asFile

// Only a local canonical release may use a configured release keystore.
// The release workflow builds unsigned and signs outside Gradle.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = !testApk && keystorePropertiesFile.isFile
if (hasReleaseSigning) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.transcriber.app"
    compileSdk = 37
    // Pinned so the whole build uses one NDK (see android/build.gradle.kts) and
    // CI can pre-install exactly this version reliably.
    ndkVersion = "28.2.13676358"

    testOptions {
        unitTests.isIncludeAndroidResources = true
        resultsDir = androidTestResults.absolutePath
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.transcriber.app"
        manifestPlaceholders["transcriberLabel"] = "Transcriber"
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
        release {
            if (testApk) {
                applicationIdSuffix = ".preview"
                manifestPlaceholders["transcriberLabel"] = "Transcriber Test"
            }
            signingConfig = when {
                testApk -> signingConfigs.getByName("debug")
                hasReleaseSigning -> signingConfigs.getByName("release")
                else -> null
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    constraints {
        implementation("com.google.guava:guava:33.8.0-android") {
            because("Fix GHSA-xxph-c9ww-hj94 in the Android application runtime")
        }
        testImplementation("com.google.guava:guava:33.8.0-jre") {
            because("Fix GHSA-xxph-c9ww-hj94 in the Robolectric test runtime")
        }
    }
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.18.1")
    testImplementation("org.mockito:mockito-core:5.24.0")
    // Keep Kotlin's runtime lock graph stable (Gradle issue 21396).
    runtimeOnly("org.jetbrains.kotlin:kotlin-stdlib-common:2.4.21")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
}

// The release and test graphs share one lockfile consumed by OSV.
val auditedClasspaths = setOf(
    "releaseRuntimeClasspath",
    "debugAndroidTestRuntimeClasspath",
    "debugUnitTestCompileClasspath",
    "debugUnitTestRuntimeClasspath",
)
dependencyLocking {
    lockMode.set(LockMode.STRICT)
}
configurations.matching { it.name in auditedClasspaths }.configureEach {
    resolutionStrategy.activateDependencyLocking()
}

// Resolve the test sandbox through Gradle so the audit sees the runtime download.
val robolectricSdk = configurations.create("robolectricSdk") {
    isCanBeConsumed = false
    isCanBeResolved = true
    resolutionStrategy.activateDependencyLocking()
}
dependencies.add(robolectricSdk.name, "org.robolectric:android-all-instrumented:15-robolectric-14663667-2-i7")

tasks.register("verifyAuditedAndroidDependencies") {
    group = "verification"
    description = "Resolve each Android dependency graph scanned by OSV."
    doLast {
        (auditedClasspaths.map(configurations::getByName) + listOf(robolectricSdk)).forEach { configuration ->
            configuration.incoming.artifactView {
                // Verify external artifacts without building the dependent projects.
                componentFilter { it is ModuleComponentIdentifier }
            }.files.files
        }
    }
}
val sandboxDirectory = layout.buildDirectory.dir("robolectric-sdks")
val prepareRobolectricSdks = tasks.register<Sync>("prepareRobolectricSdks") {
    from(robolectricSdk)
    into(sandboxDirectory)
}
tasks.withType<Test>().configureEach {
    dependsOn(prepareRobolectricSdks)
    inputs.files(robolectricSdk).withPropertyName("robolectricSdk")
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
extra["requiredConnectedTestSourceRoot"] = file("src/androidTest/kotlin")
extra["requiredConnectedTestResults"] = androidTestResults.resolve("connected/debug")
apply(from = rootProject.file("../tool/ci/jvm/require_executed_tests.gradle.kts"))

// Robolectric's resource APK consumes the Flutter assets produced by this task.
tasks.matching { it.name == "packageDebugUnitTestForUnitTest" }.configureEach {
    dependsOn("copyFlutterAssetsDebug")
}

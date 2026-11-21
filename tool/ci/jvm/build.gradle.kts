plugins {
    kotlin("jvm") version "2.4.21"
    jacoco
}

repositories {
    mavenCentral()
}

val repositoryRoot = layout.projectDirectory.dir("../../..")
val pureClasses = file("sources.txt").readLines().filter(String::isNotBlank)
require(pureClasses.isNotEmpty()) { "The JVM source manifest must not be empty." }
val sourcePaths = pureClasses.map { "${it.replace('.', '/')}.kt" }
val testPaths = pureClasses.map { "${it.replace('.', '/')}Test.kt" }
for (path in sourcePaths) {
    require(repositoryRoot.file("android/app/src/main/kotlin/$path").asFile.isFile) {
        "A configured JVM production source is missing."
    }
}
for (path in testPaths) {
    require(repositoryRoot.file("android/app/src/test/kotlin/$path").asFile.isFile) {
        "A configured JVM test source is missing."
    }
}

kotlin {
    jvmToolchain(17)
    sourceSets {
        main {
            kotlin.setSrcDirs(listOf(repositoryRoot.dir("android/app/src/main/kotlin")))
            kotlin.setIncludes(sourcePaths)
        }
        test {
            kotlin.setSrcDirs(listOf(repositoryRoot.dir("android/app/src/test/kotlin")))
            kotlin.setIncludes(testPaths)
        }
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}

dependencyLocking {
    lockAllConfigurations()
}

configurations.matching { it.name in setOf("jacocoAgent", "jacocoAnt") }.configureEach {
    resolutionStrategy.activateDependencyLocking()
}

tasks.test {
    useJUnit()
    filter {
        isFailOnNoMatchingTests = true
        pureClasses.forEach { includeTestsMatching("${it}Test") }
    }
}

extra["requiredTestSourceRoot"] = repositoryRoot.dir("android/app/src/test/kotlin").asFile
extra["requiredTestSourceFiles"] = testPaths.map {
    repositoryRoot.file("android/app/src/test/kotlin/$it").asFile
}
apply(from = "require_executed_tests.gradle.kts")

extra["coverageSources"] = sourcePaths.map {
    repositoryRoot.file("android/app/src/main/kotlin/$it").asFile
}
extra["coverageSourceRoot"] = repositoryRoot.dir("android/app/src/main/kotlin").asFile
extra["coverageClassDirectories"] = files(layout.buildDirectory.dir("classes/kotlin/main"))
extra["coverageTestTask"] = "test"
apply(from = "native_coverage.gradle.kts")

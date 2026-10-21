import org.gradle.api.tasks.testing.Test
import org.gradle.testing.jacoco.plugins.JacocoPluginExtension
import org.gradle.testing.jacoco.plugins.JacocoTaskExtension
import org.gradle.testing.jacoco.tasks.JacocoReport
import org.w3c.dom.Element
import javax.xml.XMLConstants
import javax.xml.parsers.DocumentBuilderFactory

configure<JacocoPluginExtension> { toolVersion = "0.8.14" }

val coverageSources = (extra["coverageSources"] as Collection<*>).map { it as File }
val coverageRoot = extra["coverageSourceRoot"] as File
val coverageClasses = extra["coverageClassDirectories"] as FileCollection
val coverageTestTask = extra["coverageTestTask"] as String
val coverageDeviceTask = if (extra.has("coverageDeviceTask")) extra["coverageDeviceTask"] as String else null
val includeDeviceCoverage = providers.gradleProperty("nativeDeviceCoverage").map {
    require(it in setOf("true", "false")) { "nativeDeviceCoverage must be true or false." }
    it == "true"
}.getOrElse(false)
val deviceData = fileTree(layout.buildDirectory.dir("outputs/code_coverage/debugAndroidTest/connected")) {
    include("**/*.ec")
}
require(coverageSources.isNotEmpty()) { "Native coverage source inventory must not be empty." }
require(coverageSources.all { it.isFile && it.extension == "kt" }) {
    "Every native coverage source must exist."
}
val expectedSources = coverageSources.map {
    it.relativeTo(coverageRoot).invariantSeparatorsPath
}.toSet()
require(expectedSources.size == coverageSources.size) { "Duplicate native coverage source." }

tasks.withType<Test>().configureEach {
    extensions.configure<JacocoTaskExtension> {
        // Robolectric defines maintained classes in a sandbox without a code location.
        isIncludeNoLocationClasses = true
        includes = expectedSources.map { it.substringBeforeLast('/').replace('/', '.') + ".*" }.distinct()
        // JDK reflection adapters are not application code and cannot be instrumented.
        excludes = listOf("jdk.internal.*")
    }
}

val nativeReport = tasks.register<JacocoReport>("nativeCoverageReport") {
    dependsOn(coverageTestTask)
    executionData(layout.buildDirectory.file("jacoco/$coverageTestTask.exec"))
    if (includeDeviceCoverage) {
        require(coverageDeviceTask != null) { "This build has no Android device test task." }
        dependsOn(coverageDeviceTask)
        executionData(deviceData)
    }
    sourceDirectories.setFrom(coverageRoot)
    classDirectories.setFrom(coverageClasses)
    reports {
        xml.required = true
        html.required = true
    }
    doFirst {
        require(!includeDeviceCoverage || deviceData.files.any { it.isFile && it.length() > 0 }) {
            "Requested native device coverage is missing or empty."
        }
        require(executionData.files.any { it.isFile && it.length() > 0 }) {
            "Native coverage execution data is missing or empty."
        }
        require(classDirectories.asFileTree.files.any { it.extension == "class" }) {
            "Native coverage production bytecode is missing."
        }
    }
}

fun coverageDocument(report: File): Element {
    require(report.isFile && report.length() in 1..16 * 1024 * 1024) {
        "Native coverage XML is missing, empty, or oversized."
    }
    val factory = DocumentBuilderFactory.newInstance()
    // JaCoCo writes a DOCTYPE; disable its external resolution without discarding it.
    factory.setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false)
    factory.setFeature("http://xml.org/sax/features/external-general-entities", false)
    factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false)
    factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_DTD, "")
    factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "")
    factory.isXIncludeAware = false
    factory.isExpandEntityReferences = false
    return factory.newDocumentBuilder().parse(report).documentElement.also {
        require(it.tagName == "report") { "Expected a JaCoCo report." }
    }
}

fun directCounters(element: Element): Map<String, Pair<Long, Long>> =
    (0 until element.childNodes.length).mapNotNull { index ->
        val node = element.childNodes.item(index)
        if (node !is Element || node.tagName != "counter") return@mapNotNull null
        val covered = node.getAttribute("covered").toLong()
        val missed = node.getAttribute("missed").toLong()
        require(covered >= 0 && missed >= 0) { "Negative native coverage counter." }
        node.getAttribute("type") to (covered to missed)
    }.toMap()

fun requireNativeSourceInventory(report: Element, expected: Set<String>) {
    val measured = mutableSetOf<String>()
    val packages = report.getElementsByTagName("package")
    for (index in 0 until packages.length) {
        val entry = packages.item(index) as Element
        val sources = entry.getElementsByTagName("sourcefile")
        for (sourceIndex in 0 until sources.length) {
            val source = sources.item(sourceIndex) as Element
            val path = "${entry.getAttribute("name")}/${source.getAttribute("name")}"
            require(measured.add(path)) { "Duplicate native coverage source: $path" }
            val lines = directCounters(source)["LINE"]
            require(lines != null && lines.first + lines.second > 0) {
                "Native source has no measured executable lines: $path"
            }
        }
    }
    require(measured == expected) {
        "Native coverage inventory mismatch. Missing: ${expected - measured}; unexpected: ${measured - expected}"
    }
}

tasks.register("verifyNativeCoverage") {
    group = "verification"
    description = "Enforce complete native coverage with unchanged strict thresholds."
    dependsOn(nativeReport)
    doLast {
        require(nativeReport.get().executionData.files.any { it.isFile && it.length() > 0 }) {
            "Native coverage execution data is missing or empty."
        }
        val report = coverageDocument(nativeReport.get().reports.xml.outputLocation.get().asFile)
        requireNativeSourceInventory(report, expectedSources)
        val counters = directCounters(report)
        val limits = mapOf("LINE" to 85, "INSTRUCTION" to 85, "METHOD" to 85, "BRANCH" to 80)
        for ((metric, limit) in limits) {
            val counts = requireNotNull(counters[metric]) { "Missing native $metric coverage." }
            val total = counts.first + counts.second
            require(total > 0 && counts.first * 100 >= total * limit) {
                "Native $metric coverage ${counts.first}/$total is below $limit%."
            }
            logger.lifecycle("Native {} coverage: {}/{} (minimum {}%)", metric, counts.first, total, limit)
        }
    }
}

import org.gradle.api.tasks.testing.Test
import org.w3c.dom.Element
import javax.xml.XMLConstants
import javax.xml.parsers.DocumentBuilder
import javax.xml.parsers.DocumentBuilderFactory

fun requiredTestClasses(root: File, sources: Collection<File>): Set<String> {
    val sourceRoot = root.toPath().toAbsolutePath().normalize()
    require(sources.isNotEmpty()) { "Maintained test sources must not be empty." }
    val classes = sources.map { source ->
        val path = source.toPath().toAbsolutePath().normalize()
        require(source.isFile && path.startsWith(sourceRoot) && source.name.endsWith("Test.kt")) {
            "Every maintained test source must exist below its configured Kotlin source root."
        }
        sourceRoot.relativize(path).toString().replace(File.separatorChar, '.').removeSuffix(".kt")
    }.toSet()
    require(classes.size == sources.size) {
        "Maintained test sources must be distinct."
    }
    return classes
}

fun junitParser(): DocumentBuilder {
    val factory = DocumentBuilderFactory.newInstance()
    factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)
    factory.setFeature("http://xml.org/sax/features/external-general-entities", false)
    factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false)
    factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_DTD, "")
    factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "")
    factory.isXIncludeAware = false
    factory.isExpandEntityReferences = false
    return factory.newDocumentBuilder()
}

fun junitReportRoot(parser: DocumentBuilder, report: File): Element {
    require(report.length() <= 8 * 1024 * 1024) { "JUnit report exceeds its size limit." }
    return parser.parse(report).documentElement
}

fun directElements(parent: Element, tag: String): List<Element> =
    (0 until parent.childNodes.length).mapNotNull { index ->
        (parent.childNodes.item(index) as? Element)?.takeIf { it.tagName == tag }
    }

fun testCases(suite: Element, expectedClass: String): List<Element> {
    require(suite.tagName == "testsuite" && suite.getAttribute("name") == expectedClass && expectedClass.isNotBlank()) {
        "JUnit report does not describe its expected test suite."
    }
    return directElements(suite, "testcase").onEach { test ->
        require(test.getAttribute("classname") == expectedClass && test.getAttribute("name").isNotBlank()) {
            "JUnit test case does not belong to its expected test class."
        }
    }
}

fun verifyConnectedReportCounts(report: Element, cases: List<Element>) {
    require(report.getAttribute("tests").toIntOrNull() == cases.size) {
        "Connected test report count does not match its test cases."
    }
    val skipped = cases.count { it.getElementsByTagName("skipped").length != 0 }
    require(report.getAttribute("skipped").toIntOrNull() == skipped) {
        "Connected test report skipped count does not match its test cases."
    }
    require(
        report.getAttribute("failures") == "0" && report.getAttribute("errors") == "0" &&
            report.getElementsByTagName("failure").length == 0 && report.getElementsByTagName("error").length == 0,
    ) {
        "Connected test report contains a failure or an error."
    }
}

fun successfulConnectedClasses(parser: DocumentBuilder, report: File): Set<String> {
    val root = junitReportRoot(parser, report)
    require(root.tagName == "testsuites") { "Expected an aggregate connected Android test report." }
    val cases = directElements(root, "testsuite").flatMap { suite ->
        testCases(suite, suite.getAttribute("name")).also { verifyConnectedReportCounts(suite, it) }
    }
    verifyConnectedReportCounts(root, cases)
    return cases.filter { it.getElementsByTagName("skipped").length == 0 }
        .map { it.getAttribute("classname") }
        .toSet()
}

fun verifyExecutedTestClasses(requiredClasses: Set<String>, executedClasses: Set<String>) {
    require(executedClasses.isNotEmpty()) {
        "The suite must execute tests; zero or entirely skipped tests cannot pass."
    }
    val missing = requiredClasses - executedClasses
    require(missing.isEmpty()) {
        "Every maintained test class must execute tests: ${missing.joinToString()}"
    }
}

fun verifyExecutedTests(testTask: Test, requiredClasses: Set<String>) {
    require(!testTask.state.noSource) {
        "The test task has no compiled sources; maintained tests cannot be skipped."
    }
    val parser = junitParser()
    val reportRoot = testTask.reports.junitXml.outputLocation.get().asFile
    val reports = requiredClasses.associateWith { reportRoot.resolve("TEST-$it.xml") }
    val executedClasses = reports.filter { (className, report) ->
        report.isFile && testCases(junitReportRoot(parser, report), className)
            .any { it.getElementsByTagName("skipped").length == 0 }
    }.keys
    verifyExecutedTestClasses(requiredClasses, executedClasses)
}

val maintainedTestClasses = requiredTestClasses(
    extra["requiredTestSourceRoot"] as File,
    (extra["requiredTestSourceFiles"] as Collection<*>).map { it as File },
)
val executionVerification = tasks.register("verifyMaintainedTestExecution") {
    group = "verification"
    description = "Require an unskipped test in every maintained Kotlin test class."
    mustRunAfter(tasks.withType<Test>())
    doLast {
        val completed = tasks.withType<Test>().filter { it.state.executed }
        require(completed.isNotEmpty()) { "No maintained test task completed." }
        completed.forEach { verifyExecutedTests(it, maintainedTestClasses) }
    }
}
tasks.withType<Test>().configureEach { finalizedBy(executionVerification) }

if (extra.has("requiredConnectedTestSourceRoot")) {
    val sourceRoot = extra["requiredConnectedTestSourceRoot"] as File
    val testSources = fileTree(sourceRoot) { include("**/*Test.kt") }
    val connectedTestClasses = requiredTestClasses(sourceRoot, testSources.files)
    val reportDirectory = extra["requiredConnectedTestResults"] as File
    val connectedTests = tasks.matching { it.name == "connectedDebugAndroidTest" }
    val connectedVerification = tasks.register("verifyMaintainedConnectedTestExecution") {
        group = "verification"
        description = "Require an unskipped run of every maintained Android instrumentation class."
        mustRunAfter(connectedTests)
        doLast {
            val state = connectedTests.single().state
            if (state.failure != null) return@doLast
            require(state.executed && !state.skipped && !state.noSource) {
                "The connected Android test task must execute on a device."
            }
            val parser = junitParser()
            val reports = fileTree(reportDirectory) { include("**/TEST-*.xml") }
            val executedClasses = reports.files.flatMap { successfulConnectedClasses(parser, it) }.toSet()
            verifyExecutedTestClasses(connectedTestClasses, executedClasses)
        }
    }
    connectedTests.configureEach { finalizedBy(connectedVerification) }
}

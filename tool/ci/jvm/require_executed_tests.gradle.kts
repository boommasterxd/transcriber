import org.gradle.api.tasks.testing.Test
import javax.xml.XMLConstants
import javax.xml.parsers.DocumentBuilderFactory

val maintainedTestRoot = (extra["requiredTestSourceRoot"] as File).toPath().toAbsolutePath().normalize()
val maintainedTestFiles = (extra["requiredTestSourceFiles"] as Collection<*>).map { it as File }
require(maintainedTestFiles.isNotEmpty()) { "Maintained test sources must not be empty." }
val maintainedTestClasses = maintainedTestFiles.map { source ->
    val path = source.toPath().toAbsolutePath().normalize()
    require(source.isFile && path.startsWith(maintainedTestRoot) && source.name.endsWith("Test.kt")) {
        "Every maintained test source must exist below its configured Kotlin source root."
    }
    maintainedTestRoot.relativize(path).toString().replace(File.separatorChar, '.')
        .removeSuffix(".kt")
}.toSet()
require(maintainedTestClasses.size == maintainedTestFiles.size) {
    "Maintained test sources must be distinct."
}

fun verifyExecutedTests(testTask: Test, requiredClasses: Set<String>) {
    require(!testTask.state.noSource) {
        "The test task has no compiled sources; maintained tests cannot be skipped."
    }
    val factory = DocumentBuilderFactory.newInstance()
    factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)
    factory.setFeature("http://xml.org/sax/features/external-general-entities", false)
    factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false)
    factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_DTD, "")
    factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "")
    factory.isXIncludeAware = false
    factory.isExpandEntityReferences = false
    val builder = factory.newDocumentBuilder()
    val reportRoot = testTask.reports.junitXml.outputLocation.get().asFile
    val executedClasses = requiredClasses.filter { className ->
        val report = reportRoot.resolve("TEST-$className.xml")
        if (!report.isFile) return@filter false
        require(report.length() <= 8 * 1024 * 1024) { "JUnit report exceeds its size limit." }
        val suite = builder.parse(report).documentElement
        require(suite.tagName == "testsuite" && suite.getAttribute("name") == className) {
            "JUnit report does not describe its expected maintained test class."
        }
        val cases = suite.getElementsByTagName("testcase")
        (0 until cases.length).any { index ->
            val test = cases.item(index) as org.w3c.dom.Element
            require(test.getAttribute("classname") == className) {
                "JUnit test case does not belong to its maintained test class."
            }
            test.getElementsByTagName("skipped").length == 0
        }
    }.toSet()
    require(executedClasses.isNotEmpty()) {
        "The suite must execute tests; zero or entirely skipped tests cannot pass."
    }
    val missing = requiredClasses - executedClasses
    require(missing.isEmpty()) {
        "Every maintained test class must execute tests: ${missing.joinToString()}"
    }
}

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

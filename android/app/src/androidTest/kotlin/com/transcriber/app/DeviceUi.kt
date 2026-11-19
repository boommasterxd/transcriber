package com.transcriber.app

import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Instrumentation
import android.content.Intent
import android.graphics.Rect
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.view.InputDevice
import android.view.MotionEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.junit.Assert.assertTrue
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit

internal class DeviceUi(instrumentation: Instrumentation) : AutoCloseable {
    private val automation = instrumentation.uiAutomation
    private val accessibilityEvents = Semaphore(0)
    private val originalFlags = automation.serviceInfo.flags
    private val fixture = "${instrumentation.context.packageName}/${ExternalDeviceFixtureActivity::class.java.name}"

    init {
        val service = automation.serviceInfo
        service.flags = service.flags or AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        automation.serviceInfo = service
        automation.setOnAccessibilityEventListener { accessibilityEvents.release() }
    }

    fun launchFixture(target: String? = null) {
        val arguments = if (target == null) "" else " --es target $target"
        val flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        val output = shell("am start -W -f $flags -n $fixture$arguments")
        assertTrue("Could not launch external fixture $fixture: $output", "Status: ok" in output)
    }

    fun requireLabel(vararg labels: String): AccessibilityNodeInfo = awaitLabel(labels)

    fun requireActiveLabel(vararg labels: String): AccessibilityNodeInfo =
        awaitLabel(labels, activeOnly = true)

    private fun awaitLabel(
        labels: Array<out String>,
        activeOnly: Boolean = false,
        clickable: Boolean = false,
    ): AccessibilityNodeInfo {
        val deadline = SystemClock.elapsedRealtime() + uiTimeoutMillis
        while (true) {
            findLabel(labels, activeOnly, clickable)?.let { return it }
            accessibilityEvents.drainPermits()
            findLabel(labels, activeOnly, clickable)?.let { return it }
            val remaining = deadline - SystemClock.elapsedRealtime()
            if (remaining <= 0L || !accessibilityEvents.tryAcquire(remaining, TimeUnit.MILLISECONDS)) {
                error("Visible control or text missing: ${labels.joinToString()}")
            }
        }
    }

    fun tap(vararg labels: String) {
        val node = awaitLabel(labels, clickable = true)
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        val now = SystemClock.uptimeMillis()
        injectTap(now, MotionEvent.ACTION_DOWN, bounds)
        injectTap(now, MotionEvent.ACTION_UP, bounds)
    }

    fun shell(command: String): String = ParcelFileDescriptor.AutoCloseInputStream(
        automation.executeShellCommand(command),
    ).bufferedReader().use { it.readText().trim() }

    override fun close() {
        automation.setOnAccessibilityEventListener(null)
        val service = automation.serviceInfo
        service.flags = originalFlags
        automation.serviceInfo = service
    }

    private fun findLabel(
        labels: Array<out String>,
        activeOnly: Boolean,
        clickable: Boolean,
    ): AccessibilityNodeInfo? {
        val active = listOfNotNull(automation.rootInActiveWindow)
        val roots = if (activeOnly) active else active + automation.windows.mapNotNull { it.root }
        val pending = ArrayDeque(roots)
        while (pending.isNotEmpty()) {
            val node = pending.removeFirst()
            if (node.isVisibleToUser && node.matches(labels, clickable)) return node
            repeat(node.childCount) { index ->
                node.getChild(index)?.let(pending::addLast)
            }
        }
        return null
    }

    private fun AccessibilityNodeInfo.matches(labels: Array<out String>, clickable: Boolean): Boolean {
        val descriptions = listOfNotNull(text, contentDescription, hintText)
        val labeled = descriptions.any { description ->
            description.lineSequence().any { it in labels }
        }
        return labeled && (!clickable || isClickable)
    }

    private fun injectTap(start: Long, action: Int, bounds: Rect) {
        val event = MotionEvent.obtain(
            start,
            SystemClock.uptimeMillis(),
            action,
            bounds.exactCenterX(),
            bounds.exactCenterY(),
            0,
        )
        try {
            event.source = InputDevice.SOURCE_TOUCHSCREEN
            assertTrue("Could not inject a fixture touch event", automation.injectInputEvent(event, true))
        } finally {
            event.recycle()
        }
    }

    private companion object {
        const val uiTimeoutMillis = 20_000L
    }
}

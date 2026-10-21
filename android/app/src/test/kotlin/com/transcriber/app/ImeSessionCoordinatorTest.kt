package com.transcriber.app

import android.text.InputType
import android.view.View
import android.view.inputmethod.EditorInfo
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.loader.FlutterLoader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.RETURNS_DEEP_STUBS
import org.mockito.Mockito.mock
import org.mockito.Mockito.mockConstruction
import org.mockito.Mockito.mockStatic
import org.mockito.Mockito.times
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.mockito.Mockito.withSettings
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE)
class ImeSessionCoordinatorTest {
    @Test
    fun lifecycleCreatesBoundedInputSurfaceAndReleasesTheFlutterEngine() {
        val service = Robolectric.buildService(TranscriberInputMethodService::class.java).get()
        val loader = mock(FlutterLoader::class.java)
        val injector = mock(FlutterInjector::class.java)
        `when`(injector.flutterLoader()).thenReturn(loader)
        `when`(loader.findAppBundlePath()).thenReturn("test-assets")
        mockStatic(FlutterInjector::class.java).use { factory ->
            factory.`when`<FlutterInjector> { FlutterInjector.instance() }.thenReturn(injector)
            mockConstruction(
                FlutterEngine::class.java,
                withSettings().defaultAnswer(RETURNS_DEEP_STUBS)
            ).use { engines ->
                val coordinator = ImeSessionCoordinator(service)
                coordinator.create()
                assertNotNull(coordinator.inputView)
                val width = View.MeasureSpec.makeMeasureSpec(800, View.MeasureSpec.EXACTLY)
                coordinator.inputView.measure(width, View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED))
                val desired = (312 * service.resources.displayMetrics.density).toInt()
                assertEquals(desired, coordinator.inputView.measuredHeight)
                coordinator.inputView.measure(width, View.MeasureSpec.makeMeasureSpec(100, View.MeasureSpec.AT_MOST))
                assertEquals(minOf(desired, 100), coordinator.inputView.measuredHeight)
                coordinator.startInput(EditorInfo().apply { inputType = InputType.TYPE_CLASS_TEXT })
                coordinator.startInputView()
                coordinator.windowShown()
                coordinator.windowHidden()
                coordinator.finishInputView()
                coordinator.finishInput()
                coordinator.unbindInput()
                coordinator.destroy()
                val engine = engines.constructed().single()
                verify(engine.lifecycleChannel).appIsResumed()
                verify(engine.lifecycleChannel).appIsInactive()
                verify(engine.lifecycleChannel).appIsDetached()
                verify(engine).destroy()
                verify(loader).startInitialization(service.applicationContext)
                verify(loader).ensureInitializationComplete(service.applicationContext, null)
            }
        }
    }

    @Test
    fun serviceDelegatesEveryLifecycleEventAndNeverUsesFullscreenMode() {
        mockConstruction(ImeSessionCoordinator::class.java).use { coordinators ->
            val controller = Robolectric.buildService(TranscriberInputMethodService::class.java).create()
            val service = controller.get()
            val coordinator = coordinators.constructed().single()
            assertEquals(false, service.onEvaluateFullscreenMode())
            service.onCreateInputView()
            service.onStartInput(null, false)
            service.onStartInputView(null, false)
            service.onWindowShown()
            service.onWindowHidden()
            service.onFinishInputView(false)
            service.onFinishInput()
            service.onUnbindInput()
            controller.destroy()
            verify(coordinator).create()
            verify(coordinator).startInput(null)
            verify(coordinator).startInputView()
            verify(coordinator).windowShown()
            verify(coordinator).windowHidden()
            verify(coordinator, times(1)).finishInputView()
            verify(coordinator, times(1)).finishInput()
            verify(coordinator).unbindInput()
            verify(coordinator).destroy()
        }
    }
}

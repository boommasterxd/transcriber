package com.transcriber.app

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.widget.FrameLayout
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

/** Coordinates IME lifecycle resources without owning editor or channel behavior. */
class ImeSessionCoordinator(
    private val service: TranscriberInputMethodService,
) {
    private lateinit var engine: FlutterEngine
    private lateinit var flutterView: FlutterView
    private lateinit var recorder: PcmAudioRecorder
    private lateinit var editor: ImeEditorContext
    private lateinit var events: ImeEventPublisher

    lateinit var inputView: View
        private set

    fun create() {
        engine = FlutterEngine(service.applicationContext)
        editor = ImeEditorContext(service)
        events = ImeEventPublisher(engine.dartExecutor.binaryMessenger, editor)
        recorder = PcmAudioRecorder(service, events::emitAudioChunk, events::emitAudioFailure)
        ImeMethodHandler(service, engine.dartExecutor.binaryMessenger, editor, recorder).register()
        events.register(recorder)
        KeyboardSettingsChannel(service, engine.dartExecutor.binaryMessenger).register()
        startDartEntrypoint()
        flutterView = FlutterView(service, FlutterSurfaceView(service))
        inputView = FixedHeightInputView(
            service,
            (keyboardHeightDp * service.resources.displayMetrics.density).toInt(),
        ).apply {
            addView(
                flutterView,
                ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )
        }
        flutterView.attachToFlutterEngine(engine)
    }

    fun windowShown() {
        editor.setVisible(true)
        engine.lifecycleChannel.appIsResumed()
        events.emitEditorState(recorder)
    }

    fun windowHidden() {
        editor.setVisible(false)
        recorder.stop()
        editor.invalidate()
        events.emitEditorState(recorder)
        engine.lifecycleChannel.appIsInactive()
    }

    fun startInput(attribute: EditorInfo?) {
        recorder.stop()
        editor.start(attribute)
        events.emitEditorState(recorder)
    }

    fun startInputView() {
        editor.start(service.currentInputEditorInfo)
        editor.setVisible(true)
        events.emitEditorState(recorder)
    }

    fun finishInputView() {
        recorder.stop()
        editor.invalidate()
        events.emitEditorState(recorder)
    }

    fun finishInput() {
        recorder.stop()
        editor.invalidate()
        events.emitEditorState(recorder)
    }

    fun destroy() {
        recorder.stop()
        editor.invalidate()
        flutterView.detachFromFlutterEngine()
        engine.lifecycleChannel.appIsDetached()
        engine.destroy()
    }

    private fun startDartEntrypoint() {
        val loader = FlutterInjector.instance().flutterLoader()
        if (!loader.initialized()) {
            loader.startInitialization(service.applicationContext)
            loader.ensureInitializationComplete(service.applicationContext, null)
        }
        val entrypoint = DartExecutor.DartEntrypoint(loader.findAppBundlePath(), keyboardEntrypoint)
        engine.dartExecutor.executeDartEntrypoint(entrypoint)
    }

    private companion object {
        const val keyboardEntrypoint = "keyboardMain"
        const val keyboardHeightDp = 280
    }
}

/** Gives Android's WRAP_CONTENT IME host a bounded, keyboard-sized measurement. */
private class FixedHeightInputView(
    context: Context,
    private val desiredHeight: Int,
) : FrameLayout(context) {
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val availableHeight = if (MeasureSpec.getMode(heightMeasureSpec) == MeasureSpec.UNSPECIFIED) {
            desiredHeight
        } else {
            MeasureSpec.getSize(heightMeasureSpec)
        }
        val measuredHeight = minOf(desiredHeight, availableHeight)
        super.onMeasure(
            widthMeasureSpec,
            MeasureSpec.makeMeasureSpec(measuredHeight, MeasureSpec.EXACTLY),
        )
    }
}

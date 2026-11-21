package com.transcriber.app

import android.inputmethodservice.InputMethodService
import android.view.View
import android.view.inputmethod.EditorInfo

/** Android lifecycle host for the Flutter-rendered dictation input method. */
class TranscriberInputMethodService : NonFullscreenInputMethodService() {
    private lateinit var coordinator: ImeSessionCoordinator
    private val navigationBarAppearance = ImeNavigationBarAppearance { window.window }
    internal val requestLightNavigationBar = navigationBarAppearance::request

    override fun onCreate() {
        super.onCreate()
        coordinator = ImeSessionCoordinator(this)
        coordinator.create()
        onEditorSelectionChanged = coordinator::updateSelection
    }

    override fun onCreateInputView(): View = coordinator.inputView

    override fun onWindowShown() {
        super.onWindowShown()
        navigationBarAppearance.apply()
        coordinator.windowShown()
    }

    override fun onWindowHidden() {
        coordinator.windowHidden()
        super.onWindowHidden()
    }

    override fun onStartInput(attribute: EditorInfo?, restarting: Boolean) {
        super.onStartInput(attribute, restarting)
        coordinator.startInput(attribute)
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        coordinator.startInputView()
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        coordinator.finishInput()
        super.onFinishInputView(finishingInput)
    }

    override fun onFinishInput() {
        coordinator.finishInput()
        super.onFinishInput()
    }

    override fun onUnbindInput() {
        coordinator.finishInput()
        super.onUnbindInput()
    }

    override fun onDestroy() {
        onEditorSelectionChanged = null
        coordinator.destroy()
        super.onDestroy()
    }
}

/** Keeps the host editor in control of the text and forwards selection offsets. */
abstract class NonFullscreenInputMethodService : InputMethodService() {
    protected var onEditorSelectionChanged: ((Int, Int, Int, Int) -> Unit)? = null

    final override fun onEvaluateFullscreenMode(): Boolean = false

    final override fun onUpdateSelection(
        oldSelStart: Int,
        oldSelEnd: Int,
        newSelStart: Int,
        newSelEnd: Int,
        candidatesStart: Int,
        candidatesEnd: Int,
    ) {
        super.onUpdateSelection(oldSelStart, oldSelEnd, newSelStart, newSelEnd, candidatesStart, candidatesEnd)
        onEditorSelectionChanged?.invoke(newSelStart, newSelEnd, candidatesStart, candidatesEnd)
    }
}

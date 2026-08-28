package com.transcriber.app

import android.inputmethodservice.InputMethodService
import android.view.View
import android.view.inputmethod.EditorInfo

/** Android lifecycle host for the Flutter-rendered dictation input method. */
class TranscriberInputMethodService : InputMethodService() {
    private lateinit var coordinator: ImeSessionCoordinator

    override fun onCreate() {
        super.onCreate()
        coordinator = ImeSessionCoordinator(this)
        coordinator.create()
    }

    override fun onCreateInputView(): View = coordinator.inputView

    override fun onWindowShown() {
        super.onWindowShown()
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
        coordinator.finishInputView()
        super.onFinishInputView(finishingInput)
    }

    override fun onFinishInput() {
        coordinator.finishInput()
        super.onFinishInput()
    }

    override fun onDestroy() {
        coordinator.destroy()
        super.onDestroy()
    }
}

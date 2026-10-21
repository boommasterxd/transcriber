package com.transcriber.app

import android.content.ComponentName
import android.content.pm.PackageManager
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class InputMethodRegistrationTest {
    @Test
    fun manifestRegistersProtectedExportedInputMethodService() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val component = ComponentName(context, TranscriberInputMethodService::class.java)

        @Suppress("DEPRECATION")
        val info = context.packageManager.getServiceInfo(component, PackageManager.GET_META_DATA)

        assertTrue(info.exported)
        assertEquals("android.permission.BIND_INPUT_METHOD", info.permission)
        assertEquals(R.xml.input_method, info.metaData.getInt("android.view.im"))
    }
}

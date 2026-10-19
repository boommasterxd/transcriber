package com.transcriber.app

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import java.nio.ByteBuffer
import org.junit.Assert.assertEquals

/** Exercises the real platform channel codec against an in-memory transport. */
internal class NativeChannelHarness : BinaryMessenger {
    private val handlers = mutableMapOf<String, BinaryMessenger.BinaryMessageHandler>()
    val events = mutableListOf<Any?>()
    val backgroundChannels = mutableSetOf<String>()

    override fun makeBackgroundTaskQueue(options: BinaryMessenger.TaskQueueOptions): BinaryMessenger.TaskQueue =
        object : BinaryMessenger.TaskQueue {}

    override fun setMessageHandler(
        channel: String,
        handler: BinaryMessenger.BinaryMessageHandler?,
        taskQueue: BinaryMessenger.TaskQueue?,
    ) {
        if (taskQueue != null) backgroundChannels.add(channel)
        setMessageHandler(channel, handler)
    }

    override fun send(channel: String, message: ByteBuffer?) {
        if (message != null) events.add(StandardMethodCodec.INSTANCE.decodeEnvelope(readable(message)))
    }

    override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) {
        send(channel, message)
        callback?.reply(null)
    }

    override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {
        if (handler == null) handlers.remove(channel) else handlers[channel] = handler
    }

    fun call(channel: String, method: String, arguments: Any? = null): Any? {
        return dispatch(checkNotNull(handlers[channel]), method, arguments)
    }

    fun captureCall(channel: String, method: String, arguments: Any? = null): () -> Any? {
        val handler = checkNotNull(handlers[channel])
        return { dispatch(handler, method, arguments) }
    }

    private fun dispatch(handler: BinaryMessenger.BinaryMessageHandler, method: String, arguments: Any?): Any? {
        val message = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall(method, arguments))
        var response: ByteBuffer? = null
        var replied = false
        handler.onMessage(readable(message)) {
            response = it
            replied = true
        }
        assertEquals("Channel must reply synchronously", true, replied)
        return response?.let { StandardMethodCodec.INSTANCE.decodeEnvelope(readable(it)) }
    }

    private fun readable(buffer: ByteBuffer): ByteBuffer = buffer.duplicate().apply { flip() }
}

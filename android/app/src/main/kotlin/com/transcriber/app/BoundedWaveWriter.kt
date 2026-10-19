package com.transcriber.app

import java.io.File
import java.io.IOException
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Writes complete PCM16 samples and finalizes a valid WAV before the byte cap. */
class BoundedWaveWriter(private val file: File, private val maxBytes: Long) {
    private var output: RandomAccessFile? = null
    var dataBytes = 0L
        private set
    private var closed = false

    init {
        require(maxBytes in (headerBytes + bytesPerSample)..maxSupportedBytes)
        require((maxBytes - headerBytes) % bytesPerSample == 0L)
        val destination = RandomAccessFile(file, "rw")
        try {
            destination.setLength(0)
            destination.write(header(0))
            output = destination
        } catch (error: IOException) {
            destination.close()
            throw error
        }
    }

    /** Returns true once no more PCM samples may be accepted. */
    @Synchronized
    fun append(chunk: ByteArray): Boolean {
        val destination = output
        if (closed || destination == null) return true
        val available = maxBytes - headerBytes - dataBytes
        val count = minOf(chunk.size.toLong(), available).toInt() / bytesPerSample * bytesPerSample
        if (count > 0) {
            destination.write(chunk, 0, count)
            dataBytes += count
        }
        return dataBytes + headerBytes == maxBytes
    }

    /** Keeps the file intact when capture ends or fails; safe to retry. */
    @Synchronized
    fun finish() {
        if (closed) return
        val destination = output ?: RandomAccessFile(file, "rw")
        try {
            destination.seek(0)
            destination.write(header(dataBytes))
            destination.setLength(headerBytes + dataBytes)
            destination.fd.sync()
            closed = true
        } finally {
            output = null
            destination.close()
        }
    }

    /** Releases capture resources without requiring successful finalization. */
    @Synchronized
    fun close() {
        val destination = output
        output = null
        closed = true
        destination?.close()
    }

    private fun header(size: Long): ByteArray = ByteBuffer.allocate(headerBytes).apply {
        order(ByteOrder.LITTLE_ENDIAN)
        put("RIFF".toByteArray(Charsets.US_ASCII))
        putInt((size + headerBytes - riffPrefixBytes).toInt())
        put("WAVEfmt ".toByteArray(Charsets.US_ASCII))
        putInt(formatChunkBytes)
        putShort(1)
        putShort(1)
        putInt(sampleRate)
        putInt(sampleRate * bytesPerSample)
        putShort(bytesPerSample.toShort())
        putShort(bitsPerSample.toShort())
        put("data".toByteArray(Charsets.US_ASCII))
        putInt(size.toInt())
    }.array()

    companion object {
        private const val riffPrefixBytes = 8
        private const val formatChunkBytes = 16
        private const val bitsPerSample = 16
        const val headerBytes = 44
        const val sampleRate = 16_000
        const val bytesPerSample = 2
        const val maxSupportedBytes = 100L * 1024 * 1024
    }
}

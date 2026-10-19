package com.transcriber.app

import java.io.File
import java.io.IOException
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class BoundedWaveWriterTest {
    @get:Rule val temporary = TemporaryFolder()

    @Test
    fun exactAndOversizedChunksNeverExceedTheCapAndFinalizeValidPcmHeaders() {
        for (chunk in listOf(byteArrayOf(1, 2, 3, 4), byteArrayOf(1, 2, 3, 4, 5, 6))) {
            val file = temporary.newFile()
            val writer = BoundedWaveWriter(file, 48)
            assertTrue(writer.append(chunk))
            assertEquals(4L, writer.dataBytes)
            assertEquals(48L, file.length())
            writer.finish()
            writer.finish()
            assertTrue(writer.append(byteArrayOf(7, 8)))
            val bytes = file.readBytes()
            val header = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
            assertEquals("RIFF", String(bytes, 0, 4, Charsets.US_ASCII))
            assertEquals("WAVEfmt ", String(bytes, 8, 8, Charsets.US_ASCII))
            assertEquals("data", String(bytes, 36, 4, Charsets.US_ASCII))
            assertEquals(40, header.getInt(4))
            assertEquals(16, header.getInt(16))
            assertEquals(1, header.getShort(20).toInt())
            assertEquals(1, header.getShort(22).toInt())
            assertEquals(16_000, header.getInt(24))
            assertEquals(32_000, header.getInt(28))
            assertEquals(2, header.getShort(32).toInt())
            assertEquals(16, header.getShort(34).toInt())
            assertEquals(4, header.getInt(40))
            assertEquals(listOf<Byte>(1, 2, 3, 4), bytes.drop(44))
        }
    }

    @Test
    fun shortEmptyAndOddChunksKeepCompleteSamplesAndFinalizeEarly() {
        val file = temporary.newFile()
        val writer = BoundedWaveWriter(file, 52)
        assertFalse(writer.append(byteArrayOf()))
        assertFalse(writer.append(byteArrayOf(1)))
        assertFalse(writer.append(byteArrayOf(1, 2, 3)))
        assertFalse(writer.append(byteArrayOf(4, 5)))
        assertEquals(4L, writer.dataBytes)
        writer.finish()
        assertEquals(48L, file.length())
        assertEquals(listOf<Byte>(1, 2, 4, 5), file.readBytes().drop(44))
        val empty = temporary.newFile()
        BoundedWaveWriter(empty, 46).finish()
        assertEquals(44L, empty.length())
    }

    @Test
    fun rejectsInvalidBudgetsAndInaccessibleDestinations() {
        for (limit in listOf(0L, 44L, 45L, 47L, BoundedWaveWriter.maxSupportedBytes + 2)) {
            assertThrows(IllegalArgumentException::class.java) { BoundedWaveWriter(temporary.newFile(), limit) }
        }
        assertThrows(IOException::class.java) {
            BoundedWaveWriter(File(temporary.root, "missing/destination.wav"), 48)
        }
    }

    @Test
    fun aPersistentFinalizationFailureReleasesTheDescriptorAndCanBeDiscarded() {
        val file = temporary.newFile()
        val writer = BoundedWaveWriter(file, 48)
        val outputField = writer.javaClass.getDeclaredField("output").apply { isAccessible = true }
        val output = outputField.get(writer) as RandomAccessFile
        output.close()
        assertThrows(IOException::class.java) { writer.finish() }
        assertEquals(null, outputField.get(writer))
        writer.finish()
        assertEquals(44L, file.length())
        writer.close()
        assertTrue(writer.append(byteArrayOf(1, 2)))
    }
}

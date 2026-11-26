package com.transcriber.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.nio.ByteBuffer
import java.nio.ByteOrder

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
}

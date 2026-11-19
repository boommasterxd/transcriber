package com.transcriber.app;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.Intent;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.Objects;

/** Exposes only synthetic audio through Android's temporary URI grants. */
public final class FixtureAudioProvider extends ContentProvider {
    static final String MIME_TYPE = "audio/wav";
    private static final String SEND_FILE_NAME = "device-send-fixture.wav";
    private static final String VIEW_FILE_NAME = "device-view-fixture.wav";
    private static final int SAMPLE_BYTES = 32_000;

    public static Uri uri(String packageName, String action) {
        String fileName = switch (action) {
            case Intent.ACTION_SEND -> SEND_FILE_NAME;
            case Intent.ACTION_VIEW -> VIEW_FILE_NAME;
            default -> throw new IllegalArgumentException("Unsupported fixture intent");
        };
        return Uri.parse("content://" + packageName + ".audio/" + fileName);
    }

    @Override
    public boolean onCreate() {
        return true;
    }

    @Override
    public String getType(Uri uri) {
        return MIME_TYPE;
    }

    @Override
    public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
        String fileName = uri.getLastPathSegment();
        if (!"r".equals(mode) || (!SEND_FILE_NAME.equals(fileName) && !VIEW_FILE_NAME.equals(fileName))) {
            throw new FileNotFoundException("Fixture audio is only available for reading");
        }
        File fixture = new File(Objects.requireNonNull(getContext()).getCacheDir(), fileName);
        try (FileOutputStream output = new FileOutputStream(fixture)) {
            output.write(silentWave());
        } catch (IOException cause) {
            FileNotFoundException failure = new FileNotFoundException("Could not create fixture audio");
            failure.initCause(cause);
            throw failure;
        }
        return ParcelFileDescriptor.open(fixture, ParcelFileDescriptor.MODE_READ_ONLY);
    }

    @Override
    public Cursor query(Uri uri, String[] projection, String selection, String[] args, String sort) {
        String[] columns = projection == null
            ? new String[] {OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE}
            : projection;
        MatrixCursor cursor = new MatrixCursor(columns);
        MatrixCursor.RowBuilder row = cursor.newRow();
        for (String column : columns) {
            Object value = switch (column) {
                case OpenableColumns.DISPLAY_NAME -> uri.getLastPathSegment();
                case OpenableColumns.SIZE -> 44 + SAMPLE_BYTES;
                default -> null;
            };
            row.add(value);
        }
        return cursor;
    }

    @Override
    public Uri insert(Uri uri, ContentValues values) {
        return null;
    }

    @Override
    public int delete(Uri uri, String selection, String[] args) {
        return 0;
    }

    @Override
    public int update(Uri uri, ContentValues values, String selection, String[] args) {
        return 0;
    }

    private static byte[] silentWave() {
        return ByteBuffer.allocate(44 + SAMPLE_BYTES)
            .order(ByteOrder.LITTLE_ENDIAN)
            .put("RIFF".getBytes(StandardCharsets.US_ASCII))
            .putInt(36 + SAMPLE_BYTES)
            .put("WAVEfmt ".getBytes(StandardCharsets.US_ASCII))
            .putInt(16)
            .putShort((short) 1)
            .putShort((short) 1)
            .putInt(16_000)
            .putInt(32_000)
            .putShort((short) 2)
            .putShort((short) 16)
            .put("data".getBytes(StandardCharsets.US_ASCII))
            .putInt(SAMPLE_BYTES)
            .array();
    }
}

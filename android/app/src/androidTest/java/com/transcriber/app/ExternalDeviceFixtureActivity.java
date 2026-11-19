package com.transcriber.app;

import android.app.Activity;
import android.content.ClipData;
import android.content.Intent;
import android.graphics.Insets;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.text.InputType;
import android.view.WindowInsets;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;

/** Runs as the separate test APK, using only its own Android framework libraries. */
public final class ExternalDeviceFixtureActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        LinearLayout controls = new LinearLayout(this);
        controls.setOrientation(LinearLayout.VERTICAL);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            controls.setOnApplyWindowInsetsListener((view, insets) -> {
                Insets bars = insets.getInsets(WindowInsets.Type.systemBars());
                view.setPadding(bars.left, bars.top, bars.right, bars.bottom);
                return insets;
            });
        }
        String target = getIntent().getStringExtra("target");
        if (target == null) {
            controls.addView(editor("Ordinary fixture editor", InputType.TYPE_TEXT_VARIATION_NORMAL));
            controls.addView(editor("Protected fixture editor", InputType.TYPE_TEXT_VARIATION_PASSWORD));
        } else {
            controls.addView(action("Send fixture audio", () -> share(target, Intent.ACTION_SEND)));
            controls.addView(action("Open fixture audio", () -> share(target, Intent.ACTION_VIEW)));
        }
        setContentView(controls);
    }

    private Button action(String label, Runnable perform) {
        Button button = new Button(this);
        button.setAllCaps(false);
        button.setText(label);
        button.setOnClickListener(view -> perform.run());
        return button;
    }

    private EditText editor(String label, int variation) {
        EditText editor = new EditText(this);
        editor.setHint(label);
        editor.setInputType(InputType.TYPE_CLASS_TEXT | variation);
        return editor;
    }

    private void share(String target, String action) {
        Uri audio = FixtureAudioProvider.uri(getPackageName(), action);
        Intent intent = new Intent(action).setPackage(target);
        if (Intent.ACTION_SEND.equals(action)) {
            intent.setType(FixtureAudioProvider.MIME_TYPE);
            intent.putExtra(Intent.EXTRA_STREAM, audio);
        } else {
            intent.setDataAndType(audio, FixtureAudioProvider.MIME_TYPE);
        }
        intent.setClipData(ClipData.newRawUri("Fixture audio", audio));
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        startActivity(intent);
    }
}

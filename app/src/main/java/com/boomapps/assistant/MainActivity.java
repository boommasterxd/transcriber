package com.boomapps.assistant;

import android.annotation.SuppressLint;
import android.content.ContentResolver;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.text.style.ForegroundColorSpan;
import android.util.Base64;
import android.util.TypedValue;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ImageButton;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;

import com.google.android.material.bottomsheet.BottomSheetBehavior;
import com.google.android.material.bottomsheet.BottomSheetDialog;

import org.commonmark.node.Heading;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;

import io.noties.markwon.AbstractMarkwonPlugin;
import io.noties.markwon.Markwon;
import io.noties.markwon.MarkwonSpansFactory;
import io.noties.markwon.core.MarkwonTheme;
import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

/**
 * @noinspection deprecation
 */
public class MainActivity extends AppCompatActivity {

    private TextView transcriptionTextView;
    private ProgressBar progressBar;
    private LinearLayout buttonContainer;
    private ImageButton shareButton;
    private ImageButton copyButton;
    private Markwon markwon;
    private String apiKey;

    String promptText = "Anweisung an das KI-Modell:\n" +
            "\n" +
            "Du bist ein fortschrittliches KI-Modell, spezialisiert auf Audioverarbeitung und Textzusammenfassung. Deine Aufgabe ist es, eine gegebene Audioaufnahme präzise zu transkribieren und anschließend eine gut formatierte Zusammenfassung dieser Transkription in Markdown zu erstellen.\n" +
            "\n" +
            "Aufgabe:\n" +
            "\n" +
            "1. Transkribiere die gesamte Audioaufnahme Wort für Wort.  \n" +
            "2. Erstelle eine prägnante, gut strukturierte und lesbare Zusammenfassung der Transkription im Markdown-Format.  \n" +
            "3. Extrahiere alle explizit genannten Aufgaben oder Handlungsaufforderungen aus der Transkription und liste sie gesondert in der Zusammenfassung auf.\n" +
            "\n" +
            "Formatierungsregeln für die Zusammenfassung:\n" +
            "\n" +
            "* Verwende Markdown-Syntax für Überschriften (\\#), Listen (\\*, \\-, \\+), Fettgedruckt \\*\\*Text\\*\\*, Kursiv \\*Text\\* und andere Elemente, wo angebracht.  \n" +
            "* Für Aufgaben oder Handlungsaufforderungen, erstelle einen eigenen Abschnitt, z.B. \"Aufgaben\" oder \"Nächste Schritte\", und liste die Punkte als ungeordnete Liste auf.  \n" +
            "* Halte die Sprache klar und direkt.\n" +
            "\n" +
            "Erforderliche Ausgabe:\n" +
            "\n" +
            "Deine Ausgabe muss aus zwei Hauptteilen bestehen:\n" +
            "\n" +
            "1. Vollständige Transkription: Der gesamte Text der Audioaufnahme.  \n" +
            "2. Zusammenfassung (Markdown): Eine Markdown-formatierte Zusammenfassung, die den oben genannten Regeln entspricht.\n" +
            "\n" +
            "Beispiel für Eingabe (Audio-Inhalt):\n" +
            "\n" +
            "\"Guten Tag zusammen. Ich möchte heute über die Fortschritte in der künstlichen Intelligenz sprechen. Insbesondere über die Anwendung von neuronalen Netzen in der Bilderkennung. Neurale Netze haben hier erstaunliche Ergebnisse geliefert, besonders in der medizinischen Diagnostik. Es gibt jedoch auch Herausforderungen, wie die Notwendigkeit großer Datenmengen für das Training und die Interpretierbarkeit der Modelle. Bitte stellen Sie sicher, dass bis nächste Woche alle relevanten Daten für die Fallstudien gesammelt sind. Im weiteren Verlauf werde ich einige Fallstudien vorstellen und die zukünftigen Potenziale beleuchten.\"\n" +
            "\n" +
            "Erwartete Ausgabe des KI-Modells:\n" +
            "\n" +
            "Guten Tag zusammen. Ich möchte heute über die Fortschritte in der künstlichen Intelligenz sprechen. Insbesondere über die Anwendung von neuronalen Netzen in der Bilderkennung. Neurale Netze haben hier erstaunliche Ergebnisse geliefert, besonders in der medizinischen Diagnostik. Es gibt jedoch auch Herausforderungen, wie die Notwendigkeit großer Datenmengen für das Training und die Interpretierbarkeit der Modelle. Bitte stellen Sie sicher, dass bis nächste Woche alle relevanten Daten für die Fallstudien gesammelt sind. Im weiteren Verlauf werde ich einige Fallstudien vorstellen und die zukünftigen Potenziale beleuchten.\n" +
            "\n" +
            "\\# Zusammenfassung der KI-Fortschritte\n" +
            "\n" +
            "Dieser Vortrag behandelt die Fortschritte in der künstlichen Intelligenz, speziell die Nutzung neuronaler Netze für die Bilderkennung.\n" +
            "\n" +
            "\\#\\# Hauptergebnisse und Anwendungen  \n" +
            "\\* Hervorragende Ergebnisse wurden in der medizinischen Diagnostik erzielt.\n" +
            "\n" +
            "\\#\\# Herausforderungen  \n" +
            "\\* Bedarf an großen Trainingsdatenmengen.  \n" +
            "\\* Schwierigkeit der Modellinterpretierbarkeit.\n" +
            "\n" +
            "\\#\\# Aufgaben  \n" +
            "\\* Stellen Sie sicher, dass bis nächste Woche alle relevanten Daten für die Fallstudien gesammelt sind.\n" +
            "\n" +
            "\\#\\# Ausblick  \n" +
            "\\* Es werden Fallstudien und zukünftige Potenziale diskutiert.";

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        markwon = Markwon.builder(this)
                .usePlugin(new AbstractMarkwonPlugin() {
                    @Override
                    public void configureTheme(@NonNull MarkwonTheme.Builder builder) {
                        // Überschriften-Textgrößen-Multiplikatoren (wie in Ihrem Code)
                        builder.headingTextSizeMultipliers(new float[]{1.15f, 1.0f, .9f, 0.8f, 0.7f, 0.6f});

                        int textPrimaryColor = ContextCompat.getColor(MainActivity.this, R.color.text_primary);
                        // Überschriften schwarz färben
                        builder.headingBreakColor(textPrimaryColor); // Farbe für die Linie unter der Überschrift (optional)
                        builder.headingTypeface(null); // Behält die Standard-Schriftart bei

                        builder.headingBreakHeight(0);

                        builder.bulletWidth(dpToPx(6)); // Größe der Aufzählungspunkte
                    }

                    @Override
                    public void configureSpansFactory(@NonNull MarkwonSpansFactory.Builder builder) {
                        builder.appendFactory(Heading.class, (configuration, props) -> {
                            int textPrimaryColor = ContextCompat.getColor(MainActivity.this, R.color.text_primary);
                            return new ForegroundColorSpan(textPrimaryColor);
                        });
                    }
                })
                .build();

        Uri audioUri;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            audioUri = getIntent().getParcelableExtra(Intent.EXTRA_STREAM, Uri.class);
        } else {
            audioUri = getIntent().getParcelableExtra(Intent.EXTRA_STREAM);
        }

        if (audioUri != null) {
            showBottomSheetDialog();
            transcribeAudio(audioUri);
        } else {
            showApiKeyDialog();
        }
    }

    private void showApiKeyDialog() {
        BottomSheetDialog bottomSheetDialog = new BottomSheetDialog(this, R.style.BottomSheetDialogTheme);
        @SuppressLint("InflateParams") View bottomSheetView = LayoutInflater.from(this).inflate(R.layout.bottom_sheet_description, null);
        bottomSheetDialog.setContentView(bottomSheetView);

        EditText apiKeyEditText = bottomSheetView.findViewById(R.id.apiKeyEditText);
        Button saveApiKeyButton = bottomSheetView.findViewById(R.id.saveApiKeyButton);

        SharedPreferences prefs = getSharedPreferences("api_key_prefs", MODE_PRIVATE);
        apiKeyEditText.setText(prefs.getString("api_key", ""));

        saveApiKeyButton.setOnClickListener(v -> {
            String key = apiKeyEditText.getText().toString().trim();
            if (!key.isEmpty()) {
                SharedPreferences.Editor editor = prefs.edit();
                editor.putString("api_key", key);
                editor.apply();
                apiKey = key;
                bottomSheetDialog.dismiss();
                showDescriptionDialog();
            } else {
                Toast.makeText(this, "API-Schlüssel darf nicht leer sein", Toast.LENGTH_SHORT).show();
            }
        });


        bottomSheetDialog.setOnShowListener(dialog -> {
            BottomSheetDialog d = (BottomSheetDialog) dialog;
            FrameLayout bottomSheet = d.findViewById(com.google.android.material.R.id.design_bottom_sheet);
            if (bottomSheet != null) {
                BottomSheetBehavior<FrameLayout> behavior = BottomSheetBehavior.from(bottomSheet);

                behavior.setBottomSheetCallback(new BottomSheetBehavior.BottomSheetCallback() {
                    @Override
                    public void onStateChanged(@NonNull View bottomSheet, int newState) {
                        if (newState == BottomSheetBehavior.STATE_HIDDEN) {
                            bottomSheetDialog.dismiss();
                        }
                    }

                    @Override
                    public void onSlide(@NonNull View bottomSheet, float slideOffset) {
                    }
                });
            }
        });

        bottomSheetDialog.setOnDismissListener(dialog -> {
            if (apiKey == null || apiKey.isEmpty()) {
                finish();
            }
        });
        bottomSheetDialog.show();
    }


    private void showDescriptionDialog() {
        BottomSheetDialog bottomSheetDialog = new BottomSheetDialog(this, R.style.BottomSheetDialogTheme);
        @SuppressLint("InflateParams") View bottomSheetView = LayoutInflater.from(this).inflate(R.layout.bottom_sheet_description, null);
        bottomSheetDialog.setContentView(bottomSheetView);

        bottomSheetDialog.setOnShowListener(dialog -> {
            BottomSheetDialog d = (BottomSheetDialog) dialog;
            FrameLayout bottomSheet = d.findViewById(com.google.android.material.R.id.design_bottom_sheet);
            if (bottomSheet != null) {
                BottomSheetBehavior<FrameLayout> behavior = BottomSheetBehavior.from(bottomSheet);

                behavior.setBottomSheetCallback(new BottomSheetBehavior.BottomSheetCallback() {
                    @Override
                    public void onStateChanged(@NonNull View bottomSheet, int newState) {
                        if (newState == BottomSheetBehavior.STATE_HIDDEN) {
                            bottomSheetDialog.dismiss();
                        }
                    }

                    @Override
                    public void onSlide(@NonNull View bottomSheet, float slideOffset) {
                    }
                });
            }
        });

        bottomSheetDialog.setOnDismissListener(dialog -> finish());
        bottomSheetDialog.show();
    }

    private void showBottomSheetDialog() {
        BottomSheetDialog bottomSheetDialog = new BottomSheetDialog(this, R.style.BottomSheetDialogTheme);
        @SuppressLint("InflateParams") View bottomSheetView = LayoutInflater.from(this).inflate(R.layout.bottom_sheet_dialog, null);
        bottomSheetDialog.setContentView(bottomSheetView);

        transcriptionTextView = bottomSheetView.findViewById(R.id.transcriptionTextView);
        progressBar = bottomSheetView.findViewById(R.id.progressBar);
        buttonContainer = bottomSheetView.findViewById(R.id.buttonContainer);
        shareButton = bottomSheetView.findViewById(R.id.shareButton);
        copyButton = bottomSheetView.findViewById(R.id.copyButton);

        ScrollView scrollView = bottomSheetView.findViewById(R.id.scrollView);

        shareButton.setOnClickListener(v -> {
            String text = transcriptionTextView.getText().toString();
            if (!text.isEmpty()) {
                Intent shareIntent = new Intent(Intent.ACTION_SEND);
                shareIntent.setType("text/plain");
                shareIntent.putExtra(Intent.EXTRA_TEXT, text);
                startActivity(Intent.createChooser(shareIntent, "Teile die Transkription"));
            }
        });

        copyButton.setOnClickListener(v -> {
            String text = transcriptionTextView.getText().toString();
            if (!text.isEmpty()) {
                android.content.ClipboardManager clipboard = (android.content.ClipboardManager) getSystemService(CLIPBOARD_SERVICE);
                android.content.ClipData clip = android.content.ClipData.newPlainText("Transkription", text);
                if (clipboard != null) {
                    clipboard.setPrimaryClip(clip);
                    getApplicationContext().getSystemService(android.content.ClipboardManager.class).setPrimaryClip(clip);
                } else {
                    Toast.makeText(this, "Kopieren fehlgeschlagen", Toast.LENGTH_SHORT).show();
                }

            }
        });

        bottomSheetDialog.setOnShowListener(dialog -> {
            BottomSheetDialog d = (BottomSheetDialog) dialog;
            FrameLayout bottomSheet = d.findViewById(com.google.android.material.R.id.design_bottom_sheet);
            if (bottomSheet != null) {
                BottomSheetBehavior<FrameLayout> behavior = BottomSheetBehavior.from(bottomSheet);
                scrollView.getViewTreeObserver().addOnScrollChangedListener(() -> behavior.setDraggable(scrollView.getScrollY() == 0));

                behavior.setBottomSheetCallback(new BottomSheetBehavior.BottomSheetCallback() {
                    @Override
                    public void onStateChanged(@NonNull View bottomSheet, int newState) {
                        scrollView.setNestedScrollingEnabled(newState == BottomSheetBehavior.STATE_EXPANDED);

                        if (newState == BottomSheetBehavior.STATE_HIDDEN) {
                            bottomSheetDialog.dismiss();
                        }
                    }

                    @Override
                    public void onSlide(@NonNull View bottomSheet, float slideOffset) {
                    }
                });
            }
        });

        bottomSheetDialog.setOnDismissListener(dialog -> finish());
        bottomSheetDialog.show();
    }

    private void transcribeAudio(Uri audioUri) {
        SharedPreferences prefs = getSharedPreferences("api_key_prefs", MODE_PRIVATE);
        apiKey = prefs.getString("api_key", null);

        if (apiKey == null || apiKey.isEmpty()) {
            runOnUiThread(() -> {
                if (progressBar != null) progressBar.setVisibility(View.GONE);
                if (transcriptionTextView != null) {
                    transcriptionTextView.setVisibility(View.VISIBLE);
                    transcriptionTextView.setText("Kein API-Schlüssel festgelegt. Bitte starten Sie die App neu und geben Sie einen Schlüssel ein.");
                }
            });
            return;
        }

        try {
            InputStream audioStream = getContentResolver().openInputStream(audioUri);
            if (audioStream == null) {
                runOnUiThread(() -> {
                    if (progressBar != null) progressBar.setVisibility(View.GONE);
                    if (transcriptionTextView != null) {
                        transcriptionTextView.setVisibility(View.VISIBLE);
                        transcriptionTextView.setText("Fehler beim Öffnen der Audiodatei.");
                    }
                });
                return;
            }

            String mimeType = getContentResolver().getType(audioUri);
            if (mimeType == null) {
                mimeType = "application/octet-stream"; // Fallback
            }

            ContentResolver resolver = getApplicationContext().getContentResolver();

            try (InputStream stream = resolver.openInputStream(audioUri)) {
                if (stream != null) {
                    byte[] audioBytes = getBytes(stream);
                    sendGeminiRequest(audioBytes, mimeType);
                }
            } catch (IOException e) {
                runOnUiThread(() -> {
                    if (progressBar != null) progressBar.setVisibility(View.GONE);
                    if (transcriptionTextView != null) {
                        transcriptionTextView.setVisibility(View.VISIBLE);
                        transcriptionTextView.setText("Fehler beim Lesen der Audiodatei: " + e.getMessage());
                    }
                });
            }

        } catch (Exception e) {
            runOnUiThread(() -> {
                if (progressBar != null) progressBar.setVisibility(View.GONE);
                if (transcriptionTextView != null) {
                    transcriptionTextView.setVisibility(View.VISIBLE);
                    transcriptionTextView.setText("Fehler bei der Transkription: " + e.getMessage());
                }
            });
        }
    }

    private void sendGeminiRequest(byte[] audioBytes, String mimeType) {
        OkHttpClient client = new OkHttpClient();

        String modelId = "gemini-1.5-flash";
        String url = "https://generativelanguage.googleapis.com/v1beta/models/" + modelId + ":generateContent?key=" + apiKey;

        JSONObject requestBodyJson = new JSONObject();
        try {
            JSONArray contents = new JSONArray();
            JSONObject content = new JSONObject();
            JSONArray parts = new JSONArray();

            JSONObject textPart = new JSONObject();
            textPart.put("text", promptText);

            JSONObject audioPart = new JSONObject();
            audioPart.put("inlineData", Base64.encodeToString(audioBytes, Base64.NO_WRAP));
            audioPart.put("mimeType", mimeType);

            parts.put(textPart);
            parts.put(audioPart);
            content.put("parts", parts);
            contents.put(content);

            JSONObject generationConfig = new JSONObject();
            generationConfig.put("responseMimeType", "text/plain");

            requestBodyJson.put("contents", contents);
            requestBodyJson.put("generationConfig", generationConfig);

        } catch (JSONException e) {
            runOnUiThread(() -> {
                if (progressBar != null) progressBar.setVisibility(View.GONE);
                if (transcriptionTextView != null) {
                    transcriptionTextView.setVisibility(View.VISIBLE);
                    transcriptionTextView.setText("Fehler beim Erstellen der Anfrage: " + e.getMessage());
                }
            });
            return;
        }

        RequestBody body = RequestBody.create(
                requestBodyJson.toString(),
                MediaType.get("application/json; charset=utf-8")
        );

        Request request = new Request.Builder()
                .url(url)
                .post(body)
                .build();

        client.newCall(request).enqueue(new Callback() {
            @Override
            public void onFailure(@NonNull Call call, @NonNull IOException e) {
                runOnUiThread(() -> {
                    if (progressBar != null) progressBar.setVisibility(View.GONE);
                    if (transcriptionTextView != null) {
                        transcriptionTextView.setVisibility(View.VISIBLE);
                        transcriptionTextView.setText("Fehler bei der Transkription: " + e.getMessage());
                    }
                });
            }

            @Override
            public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                if (response.isSuccessful() && response.body() != null) {
                    try {
                        String responseBodyString = response.body().string();
                        JSONObject responseBody = new JSONObject(responseBodyString);
                        JSONArray candidates = responseBody.getJSONArray("candidates");
                        JSONObject firstCandidate = candidates.getJSONObject(0);
                        JSONObject content = firstCandidate.getJSONObject("content");
                        JSONArray parts = content.getJSONArray("parts");
                        JSONObject firstPart = parts.getJSONObject(0);
                        String text = firstPart.getString("text");

                        if (text.isEmpty()) {
                            text = "Fehler: Keine Transkription erhalten.";
                        }
                        String finalText = text;
                        runOnUiThread(() -> {
                            if (progressBar != null) progressBar.setVisibility(View.GONE);
                            if (transcriptionTextView != null) {
                                transcriptionTextView.setVisibility(View.VISIBLE);
                                buttonContainer.setVisibility(View.VISIBLE);
                                markwon.setMarkdown(transcriptionTextView, finalText);
                            }
                        });
                    } catch (JSONException e) {
                        onFailure(call, new IOException("Fehler beim Parsen der Antwort", e));
                    }
                } else {
                    String errorBody = response.body() != null ? response.body().string() : "Unbekannter Fehler";
                    onFailure(call, new IOException("Unerwarteter Code " + response + "\n" + errorBody));
                }
            }
        });
    }


    private byte[] getBytes(InputStream inputStream) throws IOException {
        ByteArrayOutputStream byteBuffer = new ByteArrayOutputStream();
        int bufferSize = 1024;
        byte[] buffer = new byte[bufferSize];

        int len;
        while ((len = inputStream.read(buffer)) != -1) {
            byteBuffer.write(buffer, 0, len);
        }
        return byteBuffer.toByteArray();
    }

    private int dpToPx(int dp) {
        return (int) TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP,
                dp,
                this.getResources().getDisplayMetrics()
        );
    }
}


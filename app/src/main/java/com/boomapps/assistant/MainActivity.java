package com.boomapps.assistant;

import android.annotation.SuppressLint;
import android.content.ContentResolver;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.text.style.ForegroundColorSpan;
import android.util.TypedValue;
import android.view.LayoutInflater;
import android.view.View;
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
import com.google.common.util.concurrent.FutureCallback;
import com.google.common.util.concurrent.Futures;
import com.google.common.util.concurrent.ListenableFuture;
import com.google.firebase.ai.FirebaseAI;
import com.google.firebase.ai.GenerativeModel;
import com.google.firebase.ai.java.GenerativeModelFutures;
import com.google.firebase.ai.type.Content;
import com.google.firebase.ai.type.GenerateContentResponse;
import com.google.firebase.ai.type.GenerativeBackend;

import org.commonmark.node.Heading;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.noties.markwon.AbstractMarkwonPlugin;
import io.noties.markwon.Markwon;
import io.noties.markwon.MarkwonSpansFactory;
import io.noties.markwon.core.MarkwonTheme;

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

    // Create a `GenerativeModel` instance with a model that supports your use case
    GenerativeModel ai = FirebaseAI.getInstance(GenerativeBackend.googleAI())
            .generativeModel("gemini-2.5-flash");

    GenerativeModelFutures model = GenerativeModelFutures.from(ai);

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
            showDescriptionDialog();
        }
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

                    // Provide a prompt that includes the audio specified above and text
                    Content prompt = new Content.Builder()
                            .addInlineData(audioBytes, mimeType)  // Specify the appropriate audio MIME type
                            .addText(promptText)
                            .build();

                    ExecutorService executor = Executors.newSingleThreadExecutor();

                    // To generate text output, call `generateContent` with the prompt
                    ListenableFuture<GenerateContentResponse> response = model.generateContent(prompt);
                    Futures.addCallback(response, new FutureCallback<GenerateContentResponse>() {
                        @Override
                        public void onSuccess(GenerateContentResponse result) {
                            String text = result.getText();
                            if (text == null || text.isEmpty()) {
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
                        }

                        @Override
                        public void onFailure(Throwable t) {
                            runOnUiThread(() -> {
                                if (progressBar != null) progressBar.setVisibility(View.GONE);
                                if (transcriptionTextView != null) {
                                    transcriptionTextView.setVisibility(View.VISIBLE);
                                    transcriptionTextView.setText("Fehler bei der Transkription: " + t.getMessage());
                                }
                            });
                        }
                    }, executor);
                }
            } catch (IOException e) {
                runOnUiThread(() -> {
                    if (progressBar != null) progressBar.setVisibility(View.GONE);
                    if (transcriptionTextView != null) {
                        transcriptionTextView.setVisibility(View.VISIBLE);
                        transcriptionTextView.setText("Fehler beim Lesen der Audiodatei: " + e.getMessage());
                    }
                });
                return;
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
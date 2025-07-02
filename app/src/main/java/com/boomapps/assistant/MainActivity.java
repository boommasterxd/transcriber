package com.boomapps.assistant;

import android.annotation.SuppressLint;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.InputType;
import android.text.style.ForegroundColorSpan;
import android.util.TypedValue;
import android.view.LayoutInflater;
import android.view.View;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
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

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;

import io.noties.markwon.AbstractMarkwonPlugin;
import io.noties.markwon.Markwon;
import io.noties.markwon.MarkwonSpansFactory;
import io.noties.markwon.core.MarkwonTheme;

/**
 * The main activity of the application.
 * This class handles the user interface, processes incoming audio files,
 * and interacts with the Google Gemini API to generate transcriptions and summaries.
 *
 * @noinspection deprecation
 */
public class MainActivity extends AppCompatActivity {

    private TextView transcriptionTextView;
    private ProgressBar progressBar;
    private LinearLayout buttonContainer;
    private Markwon markwon;
    private String apiKey;
    private GeminiApiManager geminiApiManager;
    private EditText apiKeyEditText;
    private LinearLayout inputLayout;

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
            "* Verwende Markdown-Syntax für Überschriften (\\#), Listen (\\*, \\-, \\+), Fettgedruckt \\*\\*Text\\*\\*, Kursiv \\*Text\\* und andere Elemente, wo angebracht, wie zum Beispiel Trennlinien.  \n" +
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
            "---\n" +
            "\n" +
            "\\# Zusammenfassung der KI-Fortschritte\n" +
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

    String markdownDescription = "# Anleitung: Google AI Studio API Key und App-Nutzung\n" +
            "\n" +
            "Diese Anleitung erklärt, wie Sie einen API-Key von Google AI Studio erhalten und die App verwenden, um aus Ihren Audiodateien automatisch Transkriptionen und Zusammenfassungen zu erstellen.\n" +
            "\n" +
            "---\n" +
            "\n" +
            "## 1. Google AI Studio API Key erhalten\n" +
            "\n" +
            "Ein API-Key ist notwendig, damit die App auf die KI-Dienste von Google zugreifen kann. Sie benötigen diesen nur einmal bei der Ersteinrichtung.\n" +
            "\n" +
            "### Schritte:\n" +
            "* **Besuche Google AI Studio:** Öffnen Sie die Webseite [aistudio.google.com](https://aistudio.google.com/) in Ihrem Browser.\n" +
            "* **Anmelden:** Melden Sie sich mit Ihrem Google-Konto an.\n" +
            "* **API-Key erstellen:**\n" +
            "    * Klicken Sie in der linken Navigationsleiste auf **\"Get API key\"**.\n" +
            "    * Klicken Sie auf **\"Create API key in new project\"**.\n" +
            "    * Ihr API-Key wird nun generiert und angezeigt.\n" +
            "* **Kopieren und Sichern:** Kopieren Sie den API-Key. Sie werden ihn in der App einfügen müssen.\n" +
            "\n" +
            "**Wichtig:** Behandeln Sie Ihren API-Key wie ein Passwort und teilen Sie ihn nicht mit anderen.\n" +
            "\n" +
            "---\n" +
            "\n" +
            "## 2. App-Nutzung: Von der Audiodatei zur Zusammenfassung\n" +
            "\n" +
            "Der Prozess ist einfach und schnell.\n" +
            "\n" +
            "### So funktioniert's:\n" +
            "* **API-Key eingeben:**\n" +
            "    * Starten Sie die App.\n" +
            "    * Fügen Sie beim ersten Start Ihren kopierten API-Key in das dafür vorgesehene Feld ein.\n" +
            "* **Audio-Datei teilen:**\n" +
            "    * Wählen Sie eine beliebige Audiodatei auf Ihrem Gerät aus.\n" +
            "    * Nutzen Sie die \\\"Teilen\\\"-Funktion Ihres Betriebssystems und wählen Sie die App als Ziel aus.\n" +
            "* **Automatische Verarbeitung:**\n" +
            "    * Die App empfängt die Datei und sendet sie automatisch an die Google AI.\n" +
            "    * Die KI erstellt eine wortwörtliche **Transkription** und eine strukturierte **Zusammenfassung** des Inhalts.\n" +
            "* **Ergebnis kopieren oder teilen:**\n" +
            "    * Nach kurzer Zeit zeigt die App das fertige Ergebnis an.\n" +
            "    * Sie können den gesamten Text (Transkription und Zusammenfassung) einfach in Ihre Zwischenablage **kopieren** oder direkt mit anderen Apps **teilen**.";

    /**
     * Called when the activity is first created. Initializes the UI, Markwon, and handles the incoming intent.
     *
     * @param savedInstanceState If the activity is being re-initialized after previously being shut down then this Bundle contains the data it most recently supplied in onSaveInstanceState(Bundle). Otherwise it is null.
     */
    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Migration logic from old SharedPreferences
        migrateApiKey();

        markwon = Markwon.builder(this)
                .usePlugin(new AbstractMarkwonPlugin() {
                    @Override
                    public void configureTheme(@NonNull MarkwonTheme.Builder builder) {
                        // Set heading text size multipliers
                        builder.headingTextSizeMultipliers(new float[]{1.15f, 1.0f, .9f, 0.8f, 0.7f, 0.6f});

                        int textPrimaryColor = ContextCompat.getColor(MainActivity.this, R.color.text_primary);
                        int samsungBlueColor = ContextCompat.getColor(MainActivity.this, R.color.samsung_blue);
                        // Set heading color to primary text color
                        builder.headingBreakColor(textPrimaryColor); // Color for the line under the heading (optional)

                        builder.headingBreakHeight(0);

                        builder.bulletWidth(dpToPx(6)); // Size of the bullet points

                        builder.linkColor(samsungBlueColor); // Adjust link color
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
        // Handle getting the URI from the intent based on Android version
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            audioUri = getIntent().getParcelableExtra(Intent.EXTRA_STREAM, Uri.class);
        } else {
            audioUri = getIntent().getParcelableExtra(Intent.EXTRA_STREAM);
        }

        // If an audio URI is present, start transcription. Otherwise, show the API key dialog.
        if (audioUri != null) {
            showBottomSheetDialog();
            transcribeAudio(audioUri);
        } else {
            showApiKeyDialog();
        }
    }

    /**
     * Migrates the API key from the old insecure SharedPreferences to the new secure KeyStoreManager.
     */
    private void migrateApiKey() {
        SharedPreferences oldPrefs = getSharedPreferences("api_key_prefs", MODE_PRIVATE);
        String oldApiKey = oldPrefs.getString("api_key", null);

        if (oldApiKey != null && !oldApiKey.isEmpty()) {
            // Key exists in old storage, migrate it to the new secure storage
            KeyStoreManager.saveApiKey(this, oldApiKey);

            // Clear the old SharedPreferences
            SharedPreferences.Editor editor = oldPrefs.edit();
            editor.clear();
            editor.apply();
        }
    }

    /**
     * Displays a bottom sheet dialog for the user to enter and save their Google AI Studio API key.
     * Also shows instructions on how to obtain the key.
     */
    private void showApiKeyDialog() {
        BottomSheetDialog bottomSheetDialog = new BottomSheetDialog(this, R.style.BottomSheetDialogTheme);
        @SuppressLint("InflateParams") View bottomSheetView = LayoutInflater.from(this).inflate(R.layout.bottom_sheet_description, null);
        bottomSheetDialog.setContentView(bottomSheetView);

        apiKeyEditText = bottomSheetView.findViewById(R.id.apiKeyEditText);
        ImageButton saveApiKeyButton = bottomSheetView.findViewById(R.id.saveApiKeyButton);
        ImageButton showHidePasswordButton = bottomSheetView.findViewById(R.id.showHidePasswordButton);
        TextView descriptionTextView = bottomSheetView.findViewById(R.id.descriptionTextView);
        inputLayout = bottomSheetView.findViewById(R.id.inputLayout);
        ScrollView scrollView = bottomSheetView.findViewById(R.id.scrollView);

        // Load saved API key
        apiKey = KeyStoreManager.getApiKey(this);
        if (apiKey != null) {
            apiKeyEditText.setText(apiKey);
        }

        // Set the instructional markdown text
        markwon.setMarkdown(descriptionTextView, markdownDescription);

        // Save the API key when the save button is clicked
        saveApiKeyButton.setOnClickListener(v -> saveApiKey());

        apiKeyEditText.setOnEditorActionListener((v, actionId, event) -> {
            if (actionId == EditorInfo.IME_ACTION_DONE) {
                saveApiKey();
                InputMethodManager imm = (InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE);
                if (imm != null) {
                    imm.hideSoftInputFromWindow(apiKeyEditText.getWindowToken(), 0);
                }
                return true;
            }
            return false;
        });

        // Toggle password visibility
        showHidePasswordButton.setOnClickListener(v -> {
            if (apiKeyEditText.getInputType() == (InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD)) {
                apiKeyEditText.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD);
                showHidePasswordButton.setImageResource(R.drawable.ic_rounded_visibility_off); // Eye off Icon
            } else {
                apiKeyEditText.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
                showHidePasswordButton.setImageResource(R.drawable.ic_rounded_visibility); // Eye Icon
            }
            apiKeyEditText.setSelection(apiKeyEditText.getText().length());
        });

        // Configure the bottom sheet behavior
        bottomSheetDialog.setOnShowListener(dialog -> {
            BottomSheetDialog d = (BottomSheetDialog) dialog;
            FrameLayout bottomSheet = d.findViewById(com.google.android.material.R.id.design_bottom_sheet);
            if (bottomSheet != null) {
                BottomSheetBehavior<FrameLayout> behavior = BottomSheetBehavior.from(bottomSheet);

                // Make the bottom sheet draggable only when the scroll view is at the top
                scrollView.setOnScrollChangeListener((v, scrollX, scrollY, oldScrollX, oldScrollY) -> behavior.setDraggable(scrollY == 0));

                behavior.setBottomSheetCallback(new BottomSheetBehavior.BottomSheetCallback() {
                    @Override
                    public void onStateChanged(@NonNull View bottomSheet, int newState) {
                        if (newState != BottomSheetBehavior.STATE_EXPANDED) {
                            behavior.setDraggable(true);
                        } else {
                            // When expanded, set initial draggable state based on scroll position
                            behavior.setDraggable(scrollView.getScrollY() == 0);
                        }

                        if (newState == BottomSheetBehavior.STATE_HIDDEN) {
                            bottomSheetDialog.dismiss();
                        }
                    }

                    @Override
                    public void onSlide(@NonNull View bottomSheet, float slideOffset) {
                        // No action needed here
                    }
                });
            }
        });

        // Finish the activity when the dialog is dismissed
        bottomSheetDialog.setOnDismissListener(dialog -> finish());


        bottomSheetDialog.show();
    }

    /**
     * Saves the API key entered by the user.
     * Validates the input and provides feedback to the user.
     */
    private void saveApiKey() {
        String key = apiKeyEditText.getText().toString().trim();
        if (!key.isEmpty()) {
            KeyStoreManager.saveApiKey(this, key);
            apiKey = key;
            Toast.makeText(this, "API-Schlüssel erfolgreich gespeichert", Toast.LENGTH_SHORT).show();
            inputLayout.setBackgroundResource(R.drawable.api_input_background_rounded_success);
        } else {
            Toast.makeText(this, "API-Schlüssel darf nicht leer sein", Toast.LENGTH_SHORT).show();
            inputLayout.setBackgroundResource(R.drawable.api_input_background_rounded_error);
        }
        // Reset background after 2 seconds
        new Handler(Looper.getMainLooper()).postDelayed(() -> inputLayout.setBackgroundResource(R.drawable.api_input_background_rounded_default), 2000);
    }

    /**
     * Displays the bottom sheet dialog that shows the transcription progress and the final result.
     */
    private void showBottomSheetDialog() {
        BottomSheetDialog bottomSheetDialog = new BottomSheetDialog(this, R.style.BottomSheetDialogTheme);
        @SuppressLint("InflateParams") View bottomSheetView = LayoutInflater.from(this).inflate(R.layout.bottom_sheet_dialog, null);
        bottomSheetDialog.setContentView(bottomSheetView);

        transcriptionTextView = bottomSheetView.findViewById(R.id.transcriptionTextView);
        progressBar = bottomSheetView.findViewById(R.id.progressBar);
        buttonContainer = bottomSheetView.findViewById(R.id.buttonContainer);
        ImageButton shareButton = bottomSheetView.findViewById(R.id.shareButton);
        ImageButton copyButton = bottomSheetView.findViewById(R.id.copyButton);

        ScrollView scrollView = bottomSheetView.findViewById(R.id.scrollView);

        // Share the transcription text
        shareButton.setOnClickListener(v -> {
            String text = transcriptionTextView.getText().toString();
            if (!text.isEmpty()) {
                Intent shareIntent = new Intent(Intent.ACTION_SEND);
                shareIntent.setType("text/plain");
                shareIntent.putExtra(Intent.EXTRA_TEXT, text);
                startActivity(Intent.createChooser(shareIntent, "Teile die Transkription"));
            }
        });

        // Copy the transcription text to the clipboard
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

        // Configure the bottom sheet behavior
        bottomSheetDialog.setOnShowListener(dialog -> {
            BottomSheetDialog d = (BottomSheetDialog) dialog;
            FrameLayout bottomSheet = d.findViewById(com.google.android.material.R.id.design_bottom_sheet);
            if (bottomSheet != null) {
                BottomSheetBehavior<FrameLayout> behavior = BottomSheetBehavior.from(bottomSheet);

                // Make the bottom sheet draggable only when the scroll view is at the top
                scrollView.setOnScrollChangeListener((v, scrollX, scrollY, oldScrollX, oldScrollY) -> behavior.setDraggable(scrollY == 0));

                behavior.setBottomSheetCallback(new BottomSheetBehavior.BottomSheetCallback() {
                    @Override
                    public void onStateChanged(@NonNull View bottomSheet, int newState) {

                        if (newState != BottomSheetBehavior.STATE_EXPANDED) {
                            behavior.setDraggable(true);
                        } else {
                            behavior.setDraggable(scrollView.getScrollY() == 0);
                        }
                        if (newState == BottomSheetBehavior.STATE_HIDDEN) {
                            bottomSheetDialog.dismiss();
                        }
                    }

                    @Override
                    public void onSlide(@NonNull View bottomSheet, float slideOffset) {
                        // No action needed here
                    }
                });
            }
        });

        // Finish the activity when the dialog is dismissed
        bottomSheetDialog.setOnDismissListener(dialog -> finish());
        bottomSheetDialog.show();
    }

    /**
     * Starts the audio transcription process.
     * Checks for network availability and a valid API key before proceeding.
     *
     * @param audioUri The URI of the audio file to be transcribed.
     */
    private void transcribeAudio(Uri audioUri) {
        // Check for network connection
        if (!isNetworkAvailable()) {
            runOnUiThread(() -> {
                if (progressBar != null) progressBar.setVisibility(View.GONE);
                if (transcriptionTextView != null) {
                    transcriptionTextView.setVisibility(View.VISIBLE);
                    transcriptionTextView.setText("Keine Internetverbindung. Bitte überprüfen Sie Ihre Verbindung und versuchen Sie es erneut.");
                    LinearLayout.LayoutParams params = (LinearLayout.LayoutParams) transcriptionTextView.getLayoutParams();
                    params.bottomMargin = dpToPx(32); // 32dp margin
                    transcriptionTextView.setLayoutParams(params);
                }
            });
            return;
        }

        // Load API key from KeyStore
        apiKey = KeyStoreManager.getApiKey(this);

        // Check if API key is available
        if (apiKey == null || apiKey.isEmpty()) {
            runOnUiThread(() -> {
                if (progressBar != null) progressBar.setVisibility(View.GONE);
                if (transcriptionTextView != null) {
                    transcriptionTextView.setVisibility(View.VISIBLE);
                    transcriptionTextView.setText("Kein API-Schlüssel festgelegt. Bitte starten Sie die App über den Homescreen und geben Sie einen API-Schlüssel ein.");
                    LinearLayout.LayoutParams params = (LinearLayout.LayoutParams) transcriptionTextView.getLayoutParams();
                    params.bottomMargin = dpToPx(32); // 32dp margin
                    transcriptionTextView.setLayoutParams(params);
                }
            });
            return;
        }

        geminiApiManager = new GeminiApiManager(apiKey);

        try {
            // Get InputStream from the audio URI
            InputStream audioStream = getContentResolver().openInputStream(audioUri);
            if (audioStream == null) {
                runOnUiThread(() -> {
                    if (progressBar != null) progressBar.setVisibility(View.GONE);
                    if (transcriptionTextView != null) {
                        transcriptionTextView.setVisibility(View.VISIBLE);
                        transcriptionTextView.setText("Fehler beim Öffnen der Audiodatei.");
                        LinearLayout.LayoutParams params = (LinearLayout.LayoutParams) transcriptionTextView.getLayoutParams();
                        params.bottomMargin = dpToPx(32); // 32dp margin
                        transcriptionTextView.setLayoutParams(params);
                    }
                });
                return;
            }

            // Get MIME type of the audio file
            String mimeType = getContentResolver().getType(audioUri);
            if (mimeType == null) {
                mimeType = "application/octet-stream"; // Fallback MIME type
            }

            ContentResolver resolver = getApplicationContext().getContentResolver();

            // Convert audio stream to byte array and send the request
            try (InputStream stream = resolver.openInputStream(audioUri)) {
                if (stream != null) {
                    byte[] audioBytes = getBytes(stream);
                    String userPrompt = "Bitte transkribiere diese Audiodatei. Gib die Transkription und die Zusammenfassung aus.";
                    geminiApiManager.generateContent(audioBytes, mimeType, promptText, userPrompt, new GeminiApiManager.GeminiApiResponseListener() {
                        @Override
                        public void onSuccess(String response) {
                            runOnUiThread(() -> {
                                if (progressBar != null) progressBar.setVisibility(View.GONE);
                                if (transcriptionTextView != null) {
                                    transcriptionTextView.setVisibility(View.VISIBLE);
                                    markwon.setMarkdown(transcriptionTextView, response);
                                    buttonContainer.setVisibility(View.VISIBLE);
                                }
                            });
                        }

                        @Override
                        public void onFailure(String error) {
                            runOnUiThread(() -> {
                                if (progressBar != null) progressBar.setVisibility(View.GONE);
                                if (transcriptionTextView != null) {
                                    transcriptionTextView.setVisibility(View.VISIBLE);
                                    transcriptionTextView.setText(error);
                                    LinearLayout.LayoutParams params = (LinearLayout.LayoutParams) transcriptionTextView.getLayoutParams();
                                    params.bottomMargin = dpToPx(32); // 32dp margin
                                    transcriptionTextView.setLayoutParams(params);
                                }
                            });
                        }
                    });
                }
            } catch (IOException e) {
                runOnUiThread(() -> {
                    if (progressBar != null) progressBar.setVisibility(View.GONE);
                    if (transcriptionTextView != null) {
                        transcriptionTextView.setVisibility(View.VISIBLE);
                        transcriptionTextView.setText("Fehler beim Lesen der Audiodatei: " + e.getMessage());
                        LinearLayout.LayoutParams params = (LinearLayout.LayoutParams) transcriptionTextView.getLayoutParams();
                        params.bottomMargin = dpToPx(32); // 32dp margin
                        transcriptionTextView.setLayoutParams(params);
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

    /**
     * Checks if a network connection is available.
     *
     * @return true if a network connection is available, false otherwise.
     */
    private boolean isNetworkAvailable() {
        ConnectivityManager connectivityManager
                = (ConnectivityManager) getSystemService(CONNECTIVITY_SERVICE);
        NetworkInfo activeNetworkInfo = connectivityManager.getActiveNetworkInfo();
        return activeNetworkInfo != null && activeNetworkInfo.isConnected();
    }

    /**
     * Reads an InputStream and converts it to a byte array.
     *
     * @param inputStream The InputStream to be read.
     * @return A byte array containing the data from the InputStream.
     * @throws IOException if an I/O error occurs.
     */
    public byte[] getBytes(InputStream inputStream) throws IOException {
        ByteArrayOutputStream byteBuffer = new ByteArrayOutputStream();
        int bufferSize = 1024;
        byte[] buffer = new byte[bufferSize];

        int len;
        while ((len = inputStream.read(buffer)) != -1) {
            byteBuffer.write(buffer, 0, len);
        }
        return byteBuffer.toByteArray();
    }

    /**
     * Converts a value from density-independent pixels (dp) to pixels (px).
     *
     * @param dp The value in dp.
     * @return The corresponding value in px.
     */
    private int dpToPx(int dp) {
        return (int) TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP,
                dp,
                this.getResources().getDisplayMetrics()
        );
    }
}

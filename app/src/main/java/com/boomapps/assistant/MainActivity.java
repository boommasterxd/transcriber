package com.boomapps.assistant;

import android.annotation.SuppressLint;
import android.content.ContentResolver;
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
import android.util.Base64;
import android.util.TypedValue;
import android.view.LayoutInflater;
import android.view.View;
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
     * @param savedInstanceState If the activity is being re-initialized after previously being shut down then this Bundle contains the data it most recently supplied in onSaveInstanceState(Bundle). Otherwise it is null.
     */
    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
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
     * Displays a bottom sheet dialog for the user to enter and save their Google AI Studio API key.
     * Also shows instructions on how to obtain the key.
     */
    private void showApiKeyDialog() {
        BottomSheetDialog bottomSheetDialog = new BottomSheetDialog(this, R.style.BottomSheetDialogTheme);
        @SuppressLint("InflateParams") View bottomSheetView = LayoutInflater.from(this).inflate(R.layout.bottom_sheet_description, null);
        bottomSheetDialog.setContentView(bottomSheetView);

        EditText apiKeyEditText = bottomSheetView.findViewById(R.id.apiKeyEditText);
        ImageButton saveApiKeyButton = bottomSheetView.findViewById(R.id.saveApiKeyButton);
        ImageButton showHidePasswordButton = bottomSheetView.findViewById(R.id.showHidePasswordButton);
        TextView descriptionTextView = bottomSheetView.findViewById(R.id.descriptionTextView);
        LinearLayout inputLayout = bottomSheetView.findViewById(R.id.inputLayout);
        ScrollView scrollView = bottomSheetView.findViewById(R.id.scrollView);

        // Load saved API key
        SharedPreferences prefs = getSharedPreferences("api_key_prefs", MODE_PRIVATE);
        apiKeyEditText.setText(prefs.getString("api_key", ""));

        // Set the instructional markdown text
        markwon.setMarkdown(descriptionTextView, markdownDescription);

        // Save the API key when the save button is clicked
        saveApiKeyButton.setOnClickListener(v -> {
            String key = apiKeyEditText.getText().toString().trim();
            if (!key.isEmpty()) {
                SharedPreferences.Editor editor = prefs.edit();
                editor.putString("api_key", key);
                editor.apply();
                apiKey = key;
                Toast.makeText(this, "API-Schlüssel erfolgreich gespeichert", Toast.LENGTH_SHORT).show();
                inputLayout.setBackgroundResource(R.drawable.api_input_background_rounded_success);
            } else {
                Toast.makeText(this, "API-Schlüssel darf nicht leer sein", Toast.LENGTH_SHORT).show();
                inputLayout.setBackgroundResource(R.drawable.api_input_background_rounded_error);
            }
            // Reset background after 2 seconds
            new Handler(Looper.getMainLooper()).postDelayed(() -> inputLayout.setBackgroundResource(R.drawable.api_input_background_rounded_default), 2000);
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

        // Load API key from SharedPreferences
        SharedPreferences prefs = getSharedPreferences("api_key_prefs", MODE_PRIVATE);
        apiKey = prefs.getString("api_key", null);

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
                    sendGeminiRequest(audioBytes, mimeType);
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
     * Constructs and sends a request to the Google Gemini API with the audio data.
     * Handles the asynchronous response from the API.
     * @param audioBytes The audio data as a byte array.
     * @param mimeType The MIME type of the audio file.
     */
    private void sendGeminiRequest(byte[] audioBytes, String mimeType) {
        OkHttpClient client = new OkHttpClient();

        String modelId = "gemini-2.5-flash";
        String url = "https://generativelanguage.googleapis.com/v1beta/models/" + modelId + ":generateContent?key=" + apiKey;

        JSONObject requestBodyJson = new JSONObject();
        try {
            // System Instruction
            JSONObject systemInstruction = new JSONObject();
            JSONArray systemParts = new JSONArray();
            JSONObject systemPart = new JSONObject();
            systemPart.put("text", promptText);
            systemParts.put(systemPart);
            systemInstruction.put("role", "user");
            systemInstruction.put("parts", systemParts);
            requestBodyJson.put("systemInstruction", systemInstruction);


            // Contents (User prompt with audio)
            JSONArray contents = new JSONArray();
            JSONObject content = new JSONObject();
            content.put("role", "user");

            JSONArray parts = new JSONArray();

            // Audio part
            JSONObject audioPart = new JSONObject();
            JSONObject inlineData = new JSONObject();
            inlineData.put("mimeType", mimeType);
            inlineData.put("data", Base64.encodeToString(audioBytes, Base64.NO_WRAP));
            audioPart.put("inlineData", inlineData);

            // Text part
            JSONObject textPart = new JSONObject();
            textPart.put("text", "Bitte transkribiere diese Audiodatei. Gib die Transkription und die Zusammenfassung aus.");

            parts.put(audioPart);
            parts.put(textPart);
            content.put("parts", parts);
            contents.put(content);
            requestBodyJson.put("contents", contents);

            // Generation Config
            JSONObject generationConfig = new JSONObject();
            generationConfig.put("temperature", 1);
            generationConfig.put("topK", 40);
            generationConfig.put("topP", 0.95);
            generationConfig.put("maxOutputTokens", 65536);
            JSONObject thinkingBudget = new JSONObject();
            thinkingBudget.put("thinkingBudget", 0);
            generationConfig.put("thinkingConfig", thinkingBudget);
            generationConfig.put("responseMimeType", "text/plain");
            requestBodyJson.put("generationConfig", generationConfig);

        } catch (JSONException e) {
            runOnUiThread(() -> {
                if (progressBar != null) progressBar.setVisibility(View.GONE);
                if (transcriptionTextView != null) {
                    transcriptionTextView.setVisibility(View.VISIBLE);
                    transcriptionTextView.setText("Fehler beim Erstellen der Anfrage: " + e.getMessage());
                    LinearLayout.LayoutParams params = (LinearLayout.LayoutParams) transcriptionTextView.getLayoutParams();
                    params.bottomMargin = dpToPx(32); // 32dp margin
                    transcriptionTextView.setLayoutParams(params);
                }
            });
            return;
        }

        RequestBody body = RequestBody.create(requestBodyJson.toString(), MediaType.get("application/json; charset=utf-8"));
        Request request = new Request.Builder()
                .url(url)
                .post(body)
                .build();

        // Asynchronous API call
        client.newCall(request).enqueue(new Callback() {
            @Override
            public void onFailure(@NonNull Call call, @NonNull IOException e) {
                runOnUiThread(() -> {
                    if (progressBar != null) progressBar.setVisibility(View.GONE);
                    if (transcriptionTextView != null) {
                        transcriptionTextView.setVisibility(View.VISIBLE);
                        transcriptionTextView.setText("Fehler bei der Anfrage: " + e.getMessage());
                        LinearLayout.LayoutParams params = (LinearLayout.LayoutParams) transcriptionTextView.getLayoutParams();
                        params.bottomMargin = dpToPx(32); // 32dp margin
                        transcriptionTextView.setLayoutParams(params);
                    }
                });
            }

            @Override
            public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                final String responseBody = response.body() != null ? response.body().string() : null;

                if (response.isSuccessful() && responseBody != null) {
                    try {
                        // Parse the successful response
                        JSONObject responseBodyJson = new JSONObject(responseBody);
                        JSONArray candidates = responseBodyJson.getJSONArray("candidates");
                        JSONObject firstCandidate = candidates.getJSONObject(0);
                        JSONObject content = firstCandidate.getJSONObject("content");
                        JSONArray parts = content.getJSONArray("parts");
                        JSONObject firstPart = parts.getJSONObject(0);
                        String transcription = firstPart.getString("text");

                        // Update UI with the result
                        runOnUiThread(() -> {
                            if (progressBar != null) progressBar.setVisibility(View.GONE);
                            if (transcriptionTextView != null) {
                                transcriptionTextView.setVisibility(View.VISIBLE);
                                markwon.setMarkdown(transcriptionTextView, transcription);
                                buttonContainer.setVisibility(View.VISIBLE);
                            }
                        });
                    } catch (JSONException e) {
                        // Handle JSON parsing errors
                        runOnUiThread(() -> {
                            if (progressBar != null) progressBar.setVisibility(View.GONE);
                            if (transcriptionTextView != null) {
                                transcriptionTextView.setVisibility(View.VISIBLE);
                                transcriptionTextView.setText("Fehler beim Parsen der Antwort: " + e.getMessage());
                                LinearLayout.LayoutParams params = (LinearLayout.LayoutParams) transcriptionTextView.getLayoutParams();
                                params.bottomMargin = dpToPx(32); // 32dp margin
                                transcriptionTextView.setLayoutParams(params);
                            }
                        });
                    }
                } else {
                    // Handle API errors
                    runOnUiThread(() -> {
                        if (progressBar != null) progressBar.setVisibility(View.GONE);
                        if (transcriptionTextView != null) {
                            transcriptionTextView.setVisibility(View.VISIBLE);
                            String errorMessage = "Fehler bei der Transkription";
                            if (responseBody != null) {
                                try {
                                    JSONObject errorJson = new JSONObject(responseBody);
                                    JSONObject error = errorJson.getJSONObject("error");
                                    errorMessage = "API-Fehler: " + error.getString("message");
                                } catch (JSONException e) {
                                    errorMessage = "Fehler: " + response.code() + " " + response.message();
                                }
                            } else {
                                errorMessage = "Fehler: " + response.code() + " " + response.message();
                            }
                            transcriptionTextView.setText(errorMessage);
                            LinearLayout.LayoutParams params = (LinearLayout.LayoutParams) transcriptionTextView.getLayoutParams();
                            params.bottomMargin = dpToPx(32); // 32dp margin
                            transcriptionTextView.setLayoutParams(params);
                        }
                    });
                }
            }
        });
    }

    /**
     * Checks if a network connection is available.
     * @return true if a network connection is available, false otherwise.
     */
    private boolean isNetworkAvailable() {
        ConnectivityManager connectivityManager
                = (ConnectivityManager) getSystemService(this.CONNECTIVITY_SERVICE);
        NetworkInfo activeNetworkInfo = connectivityManager.getActiveNetworkInfo();
        return activeNetworkInfo != null && activeNetworkInfo.isConnected();
    }

    /**
     * Reads an InputStream and converts it to a byte array.
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

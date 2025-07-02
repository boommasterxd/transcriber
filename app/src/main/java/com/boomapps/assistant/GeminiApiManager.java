package com.boomapps.assistant;

import android.util.Base64;
import androidx.annotation.NonNull;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import java.io.IOException;
import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

/**
 * Manages all interactions with the Google Gemini API.
 */
public class GeminiApiManager {

    private final OkHttpClient client = new OkHttpClient();
    private final String apiKey;

    /**
     * Listener interface for API responses.
     */
    public interface GeminiApiResponseListener {
        void onSuccess(String response);
        void onFailure(String error);
    }

    /**
     * Constructs a GeminiApiManager.
     * @param apiKey The API key for the Gemini API.
     */
    public GeminiApiManager(String apiKey) {
        this.apiKey = apiKey;
    }

    /**
     * Generates content by sending a request to the Gemini API.
     * @param audioBytes The audio data as a byte array.
     * @param mimeType The MIME type of the audio file.
     * @param systemPrompt The system prompt to guide the model.
     * @param listener The listener to handle the response.
     */
    public void generateContent(byte[] audioBytes, String mimeType, String systemPrompt, String userPrompt, GeminiApiResponseListener listener) {
        String modelId = "gemini-2.5-flash";
        String url = "https://generativelanguage.googleapis.com/v1beta/models/" + modelId + ":generateContent?key=" + apiKey;

        JSONObject requestBodyJson = new JSONObject();
        try {
            // System Instruction
            JSONObject systemInstruction = new JSONObject();
            JSONArray systemParts = new JSONArray();
            JSONObject systemPart = new JSONObject();
            systemPart.put("text", systemPrompt);
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
            textPart.put("text", userPrompt);

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
            listener.onFailure("Fehler beim Erstellen der Anfrage: " + e.getMessage());
            return;
        }

        RequestBody body = RequestBody.create(requestBodyJson.toString(), MediaType.get("application/json; charset=utf-8"));
        Request request = new Request.Builder()
                .url(url)
                .post(body)
                .build();

        client.newCall(request).enqueue(new Callback() {
            @Override
            public void onFailure(@NonNull Call call, @NonNull IOException e) {
                listener.onFailure("Fehler bei der Anfrage: " + e.getMessage());
            }

            @Override
            public void onResponse(@NonNull Call call, @NonNull Response response) throws IOException {
                final String responseBody = response.body() != null ? response.body().string() : null;

                if (response.isSuccessful() && responseBody != null) {
                    try {
                        JSONObject responseBodyJson = new JSONObject(responseBody);
                        JSONArray candidates = responseBodyJson.getJSONArray("candidates");
                        JSONObject firstCandidate = candidates.getJSONObject(0);
                        JSONObject content = firstCandidate.getJSONObject("content");
                        JSONArray parts = content.getJSONArray("parts");
                        JSONObject firstPart = parts.getJSONObject(0);
                        String transcription = firstPart.getString("text");
                        listener.onSuccess(transcription);
                    } catch (JSONException e) {
                        listener.onFailure("Fehler beim Parsen der Antwort: " + e.getMessage());
                    }
                } else {
                    String errorMessage;
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
                    listener.onFailure(errorMessage);
                }
            }
        });
    }
}


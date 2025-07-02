package com.boomapps.assistant;

import android.content.Context;
import android.content.SharedPreferences;
import android.widget.Toast;

import androidx.security.crypto.EncryptedSharedPreferences;
import androidx.security.crypto.MasterKeys;
import java.io.IOException;
import java.security.GeneralSecurityException;

/**
 * Manages the secure storage and retrieval of the API key using Android Keystore.
 * This class uses EncryptedSharedPreferences to securely store the API key.
 */
public class KeyStoreManager {

    private static final String PREFERENCE_FILE_NAME = "secure_api_key_prefs";
    private static final String API_KEY_ALIAS = "api_key";

    /**
     * Saves the API key securely using EncryptedSharedPreferences.
     * @param context The application context.
     * @param apiKey The API key to save.
     */
    public static void saveApiKey(Context context, String apiKey) {
        try {
            String masterKeyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC);

            SharedPreferences sharedPreferences = EncryptedSharedPreferences.create(
                    PREFERENCE_FILE_NAME,
                    masterKeyAlias,
                    context,
                    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            );

            SharedPreferences.Editor editor = sharedPreferences.edit();
            editor.putString(API_KEY_ALIAS, apiKey);
            editor.apply();
        } catch (GeneralSecurityException | IOException e) {
            Toast.makeText(
                    context,
                    "Fehler beim Speichern des API-Keys: " + e.getMessage(),
                    Toast.LENGTH_LONG
            ).show();
        }
    }

    /**
     * Retrieves the API key from EncryptedSharedPreferences.
     * @param context The application context.
     * @return The saved API key, or null if it doesn't exist or an error occurs.
     */
    public static String getApiKey(Context context) {
        try {
            String masterKeyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC);

            SharedPreferences sharedPreferences = EncryptedSharedPreferences.create(
                    PREFERENCE_FILE_NAME,
                    masterKeyAlias,
                    context,
                    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            );

            return sharedPreferences.getString(API_KEY_ALIAS, null);
        } catch (GeneralSecurityException | IOException e) {
            Toast.makeText(
                    context,
                    "Fehler beim Laden des API-Keys: " + e.getMessage(),
                    Toast.LENGTH_LONG
            ).show();
            return null;
        }
    }
}

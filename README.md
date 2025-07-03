# Assistant v1.2

"Assistant" is an Android application that leverages the Google Gemini API to transcribe audio files and generate summaries. The app is designed with a clean, modern interface that supports both light and dark modes, and features adaptive icons that adjust to the system theme.

## Features

*   **Audio Transcription and Summarization:** Share any audio file with the app to receive a full transcription and a concise, well-structured summary in Markdown format.
*   **Dark Mode:** The app automatically switches between light and dark themes based on your device's system settings.
*   **Adaptive Icon:** The app icon's background changes to match the current light or dark mode.
*   **Simple API Key Management:** Easily enter and save your Google AI Studio API key within the app. You can save the key by tapping the save icon or by pressing the "done" action on your keyboard.
*   **Share and Copy:** Quickly share or copy the generated transcription and summary.

## Getting Started

1.  **Obtain a Google AI Studio API Key:**
    *   Visit [aistudio.google.com](https://aistudio.google.com/).
    *   Sign in with your Google account.
    *   Create a new API key in a new project.
    *   Copy the generated API key.
2.  **Install the App:**
    *   Build and run the project in Android Studio.
3.  **Set up the App:**
    *   Launch the app for the first time.
    *   Paste your Google AI Studio API key when prompted.
4.  **Transcribe and Summarize:**
    *   From any app, share an audio file and select "Assistant" from the share sheet.
    *   The app will process the audio and display the transcription and summary.

## Dependencies

*   [Markwon](https://github.com/noties/Markwon): A markdown library for Android.
*   [OkHttp](https://square.github.io/okhttp/): An HTTP client for Android and Java applications.

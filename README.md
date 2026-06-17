# Transcriber

Eine moderne Flutter-Android-App, mit der man Sprachnachrichten **lokal auf dem
Gerät** (oder via Cloud-API) **transkribiert und zusammenfasst** — mit Kernpunkten
und abhakbaren To-dos. Pillen-Look, viele Animationen, Hell/Dunkel + 5
Akzentfarben, DE/EN.

Die UI ist eine 1:1-Umsetzung des Claude-Design-Mockups; sämtliche Aktionen sind
funktional (echte Aufnahme, echter Datei-Import, echtes Android-Share-Intent,
echte On-Device-Inferenz und echte Cloud-API-Calls).

## Eingänge

1. **Teilen** – Audio aus anderen Apps (z. B. WhatsApp) wird via Android
   Share-Intent (`ACTION_SEND` / `audio/*`) empfangen → Verarbeitung → Detail.
2. **Datei auswählen** – Audiodatei aus dem Dateisystem (`file_picker`).
3. **Aufnehmen** – direkt in der App aufnehmen (`record`, WAV 16 kHz mono).

Jeder Eingang läuft durch dieselbe Pipeline: *Transkription → Zusammenfassung →
Detail-Screen* mit „Verarbeitet mit"-Sektion (zeigt die genutzten Modelle).

## Verarbeitung: On-Device vs. Cloud (entweder/oder, nie gemischt)

Der Master-Switch in den Einstellungen entscheidet zwischen:

### Auf dem Gerät (privat, offline)
- **Transkription:** [`whisper_kit`](https://pub.dev/packages/whisper_kit) –
  Whisper Tiny / Base / Small / Medium.
- **Zusammenfassung:** [`flutter_gemma`](https://pub.dev/packages/flutter_gemma) –
  Gemma 3 270M/1B, Qwen 2.5 0.5B/1.5B sowie die multimodalen Gemma 3n E2B/E4B
  (Audio-fähig). Modelle werden als LiteRT-Artefakte von Hugging Face geladen
  (gated Modelle benötigen einen HF-Token, einstellbar in den Settings).

Die echten Modell-Listen stammen aus den Docs der Libraries und liegen in
`lib/data/catalog/`.

### Cloud-API
Echte Requests an **Anthropic**, **OpenAI**, **Google** oder **OpenRouter**.
- Zusammenfassung: jeweilige Chat-Endpunkte.
- Transkription: OpenAI (`gpt-4o-transcribe`) bzw. Google Gemini (inline audio).
  Anthropic/OpenRouter haben keine native ASR — die UI weist darauf hin.

API-Schlüssel werden ausschließlich lokal in `flutter_secure_storage` abgelegt.

## Architektur

```
lib/
  core/         Theme (Palette/Akzent), Lokalisierung (DE/EN), Utils
  data/
    models/     Domänenmodelle (Settings, Note, Model-Specs …)
    catalog/    Echte Modell-Kataloge (Whisper, Gemma, Cloud-Provider)
    repositories/  Persistenz (Settings, Notes, Downloads)
  services/
    audio/      Aufnahme, Konvertierung (ffmpeg → WAV 16k), Player, Metadaten
    transcription/  Interface + Whisper-Engine + Cloud
    summarization/  Interface + Gemma-Engine + Cloud + Prompt
    remote/     Provider-Clients (Anthropic/OpenAI/Google/OpenRouter)
    processing/ Pipeline (orchestriert Transkription → Zusammenfassung)
    share/      Android-Share-Intent
  state/        Riverpod-Controller (Settings, Notes, Processing, Recording, …)
  ui/
    screens/    Onboarding, Home, Record, Settings, Processing, Detail
    widgets/    Geteilte Widgets (Wellenformen, Pills, Tiles, Effekte …)
```

Jede ML-Library ist hinter genau **einer** Engine-Datei gekapselt
(`WhisperEngine`, `GemmaEngine`), damit Versions-Updates lokal bleiben.

## Build

Voraussetzungen: Flutter ≥ 3.27, Android SDK, ein Gerät mit `arm64-v8a`.

```bash
flutter pub get
flutter run            # Debug auf angeschlossenem Gerät
flutter build apk      # Release-APK
flutter test           # Unit-Tests
```

Beim ersten `flutter pub get` erzeugt Flutter `android/local.properties`
(mit dem Pfad zum Flutter-SDK). Der Gradle-Wrapper (8.9) ist eingecheckt.

> On-Device-Inferenz lädt mehrere GB an Modellen und benötigt ein echtes
> Android-Gerät — im CI/Headless lässt sich die ML-Inferenz nicht ausführen.

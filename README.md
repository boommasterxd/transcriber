# Transcriber

Transcriber is a Flutter Android application that records, imports, or receives shared audio and creates transcript notes with optional summaries.

Processing is cloud-only and uses personal API keys:

- selectable OpenAI transcription and multimodal audio models, defaulting to
  `gpt-transcribe`
- selectable Gemini Transcribe and general multimodal audio models, defaulting
  to `gemini-3.5-transcribe`
- independently selected OpenAI or Gemini summary models

API keys are stored only in Android-backed `FlutterSecureStorage`. Settings, notes, points, to-dos, transcript segments, and migration state use Drift with SQLite. External source files are never deleted.

## Documentation

- [Architecture](docs/architecture.md)
- [Configuration](docs/configuration.md)
- [Provider key setup](docs/provider-setup.md)
- [Cache lifecycle](docs/cache-lifecycle.md)
- [Operations](docs/operations.md)
- [Security](docs/security.md)
- [Code quality](docs/code-quality.md)

## Development

Use the Flutter version pinned in `.fvmrc` and the locked dependency graph:

```bash
flutter pub get --enforce-lockfile
flutter analyze --fatal-infos
flutter test
flutter build bundle --debug
```

See [operations](docs/operations.md) and [code quality](docs/code-quality.md) for the complete validation workflow.

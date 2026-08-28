# ADR: Cloud BYOK Providers and Drift Persistence

- Status: Accepted
- Date: 2026-08-28

## Context

Local Whisper and Gemma integrations added model downloads, native engines, FFmpeg conversion, Android foreground services, large binaries, and operational complexity while producing weaker transcription results. SharedPreferences stored large untyped settings and note payloads without transactions or schema migrations.

The application requires personal OpenAI and Gemini keys, independent providers for transcription and summary, durable notes, and safe migration of existing user data.

## Decision

Support only OpenAI and Google Gemini through direct REST clients over the existing HTTP stack. Keep separate transcription and summary provider contracts. Store API keys only in `FlutterSecureStorage`.

Use Drift with SQLite for settings, notes, points, to-dos, transcript segments, and migration state. Import the old SharedPreferences payload once inside a Drift transaction, then remove only successfully imported source values.

Remove local models, downloads, FFmpeg, Hugging Face settings, background download infrastructure, and the processing foreground isolate. Use provider-supported audio formats and explicit app-file ownership with bounded cleanup.

## Consequences

- processing requires network access and provider API access;
- users control and pay for their provider accounts;
- audio and optional transcript text cross provider trust boundaries;
- the application becomes smaller and removes local engine lifecycle complexity;
- typed migrations and transactions replace untyped JSON persistence;
- SharedPreferences remains temporarily as a migration-only dependency;
- historical local provider/model provenance remains readable even though no new local processing can occur.

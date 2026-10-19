# ADR: Bound Recorded WAV Files in Native Capture

- Status: Accepted
- Date: 2026-10-19

## Context

Batch processing has configured file-size limits: 100 MiB generally and 20 MiB for OpenAI inline audio. The installed recording plugin exposes no maximum WAV file size. A Dart timer or file-size poll cannot enforce a capture limit while its isolate is suspended.

## Decision

Reuse the existing native `PcmAudioRecorder` with a focused `BoundedWaveWriter` and `app/recording` method channel. Capture remains mono PCM16 at 16 kHz. Native code checks remaining capacity before every write, reserves the 44-byte WAV header and accepts only complete samples. The configured model limit is resolved at recording start and rounded down to complete seconds.

Channel operations use a serial background task queue; PCM writes run on the capture worker. Handler transitions and engine cleanup share a monitor, and a terminal disposed flag rejects queued starts/resumes after teardown. Explicit stop finalizes the header on the background queue. Cancel closes without requiring successful finalization and discards the temporary file. Engine cleanup closes abandoned capture without a main-thread sync; ordinary temporary-cache cleanup removes abandoned files.

Flutter polls one bounded status snapshot at a time for presentation. It displays the budget and preserves explicit processing/discard actions after the limit; it does not automatically upload audio. Provider-side file validation remains authoritative.

## Consequences

The byte cap holds independently of Flutter scheduling, without a foreground service, new dependency or transcoding pipeline. Native and Dart lifecycle tests are required, including oversized chunks, sample alignment, pause/resume, late startup, finalization failure and engine teardown. Host unit tests do not replace Android microphone and lifecycle verification on a device.

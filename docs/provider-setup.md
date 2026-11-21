# Provider Key Setup

Transcriber uses personal provider credentials. A ChatGPT or Gemini consumer subscription is not the same as API access, and provider billing is independent.

## OpenAI

Transcriber makes direct API requests from the Android app with your personal OpenAI key. OpenAI recommends keeping keys on a backend because a compromised client can expose the key and allow charges or account access under your credentials. If you choose to connect OpenAI, use a dedicated project key with the narrowest available permissions and set spending controls before connecting it. See [OpenAI's API key safety guidance](https://help.openai.com/en/articles/5112595-best-practices-for-api-key-safety).

1. Sign in to the [OpenAI Platform](https://platform.openai.com/).
2. Review API billing and set an appropriate project budget or usage limit.
3. Open [API keys](https://platform.openai.com/api-keys).
4. Create a secret project key with the minimum permissions available for model listing, transcription, and summary requests.
5. Copy the secret immediately. OpenAI may not display it again.
6. In Transcriber, open Settings, Model selection, Providers & API keys, expand OpenAI, paste the key, and select Connect.
7. After validation succeeds, use Test to recheck it, Replace to validate a new key before overwriting, or Disconnect to remove the key from this installation.

OpenAI API usage and ChatGPT subscriptions are billed separately. Never send the key through chat, email, screenshots, logs, or issue reports.

See the [OpenAI API quickstart](https://developers.openai.com/api/docs/quickstart) and [`gpt-transcribe` documentation](https://developers.openai.com/api/docs/models/gpt-transcribe).

## Google Gemini

Google limits Gemini API use to people aged 18 or older and to professional or business purposes. For API clients offered in the EEA, Switzerland or the United Kingdom, Google requires Paid Services. For Gemini API usage, connect a Google Cloud project with active Cloud Billing. See the [Gemini API terms](https://aistudio.google.com/docs/terms).

1. Open [Google AI Studio API keys](https://aistudio.google.com/app/apikey).
2. Select or create the Google Cloud project that should own usage and billing.
3. Create a Gemini API key.
4. Review project quotas, billing, and available API restrictions. Apply the narrowest supported restriction without blocking the Gemini API.
5. Copy the key.
6. In Transcriber, open Settings, Model selection, Providers & API keys, expand Google Gemini, paste the key, and select Connect.
7. After validation succeeds, use Test to recheck it, Replace to validate a new key before overwriting, or Disconnect to remove the key from this installation.

Official references: [Gemini API keys](https://ai.google.dev/gemini-api/docs/api-key), [Gemini libraries](https://ai.google.dev/gemini-api/docs/libraries), and [Gemini transcription](https://ai.google.dev/gemini-api/docs/transcribe).

## Rotate or revoke a key

Disconnect removes the locally stored key. To invalidate it for API requests, revoke it in the provider's key console. If you think someone has obtained your key, revoke it immediately and review your provider usage. For regular rotation, connect and test a replacement before revoking the previous key.

## Data Transfer

The transcription key authorizes upload of the selected audio to that provider. If summary is enabled, the summary key authorizes sending transcript text to its independently selected provider. Live keyboard dictation streams microphone audio to the selected transcription provider with the same key and a separate live model. The app creates no local audio file for live dictation. Provider-side retention and charges depend on your account and terms.

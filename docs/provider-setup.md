# Provider Key Setup

Transcriber uses personal provider credentials. A ChatGPT or Gemini consumer subscription is not the same as API access, and provider billing is independent.

## OpenAI

1. Sign in to the [OpenAI Platform](https://platform.openai.com/).
2. Review API billing and set an appropriate project budget or usage limit.
3. Open [API keys](https://platform.openai.com/api-keys).
4. Create a secret project key with the minimum permissions available for model listing, transcription, and summary requests.
5. Copy the secret immediately. OpenAI may not display it again.
6. In Transcriber, open Settings, Model selection, Providers & API keys, expand OpenAI, paste the key, and select Connect.
7. After validation succeeds, use Test to recheck it, Replace to validate a new key before overwriting, or Disconnect to remove it.

OpenAI API usage and ChatGPT subscriptions are billed separately. Never send the key through chat, email, screenshots, logs, or issue reports.

Official references: [API key safety](https://help.openai.com/en/articles/5112595-best-practices-for-api-key-safety), [API quickstart](https://platform.openai.com/docs/quickstart/make-your-first-api-request), and [`gpt-transcribe`](https://developers.openai.com/api/docs/models/gpt-transcribe).

## Google Gemini

1. Open [Google AI Studio API keys](https://aistudio.google.com/app/apikey).
2. Select or create the Google Cloud project that should own usage and billing.
3. Create a Gemini API key.
4. Review project quotas, billing, and available API restrictions. Apply the narrowest supported restriction without blocking the Gemini API.
5. Copy the key.
6. In Transcriber, open Settings, Model selection, Providers & API keys, expand Google Gemini, paste the key, and select Connect.
7. After validation succeeds, use Test to recheck it, Replace to validate a new key before overwriting, or Disconnect to remove it.

Official references: [Gemini API keys](https://ai.google.dev/gemini-api/docs/api-key), [Gemini libraries](https://ai.google.dev/gemini-api/docs/libraries), and [Gemini transcription](https://ai.google.dev/gemini-api/docs/transcribe).

## Data Transfer

The transcription key authorizes upload of the selected audio to that provider. If summary is enabled, the summary key authorizes sending transcript text to its independently selected provider. Review both providers when the stages use different services.

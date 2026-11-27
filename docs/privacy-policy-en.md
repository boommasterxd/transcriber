# Privacy policy for Transcriber

## Privacy at a glance

Transcriber is an Android app for recording, importing and transcribing audio. The app stores your notes and settings on your device. For transcription, optional summaries and live dictation, it connects directly to the AI provider you choose. You use your own provider account. BoomApps does not receive recordings, transcripts, API keys or telemetry through the operation of the app.

## Controller and contact

The controller for the activities of BoomApps described in this policy is BoomApps, Yannick Schäfer, Am Mäuerchen 12, 67591 Mölsheim, Germany. Send privacy and support inquiries to [yannickschaefer@boomapps.de](mailto:yannickschaefer@boomapps.de).

## Data on your device

### Audio, notes and settings

When you record audio, select an audio file or share one to the app, Transcriber temporarily stores the audio on your device. Your original files remain in their source apps. These working copies are used for processing and allow you to retry a failed operation. After 24 hours, the app removes unused working copies the next time it cleans up.

When you save a note, the app stores it and the transcript locally, along with any summary, key points and tasks. By default, it also keeps an audio copy for playback. In the privacy settings, you can choose to have the app delete the audio copy after successful processing for future operations. If a summary fails, the app stores an error message with the transcript. The message can contain personal information from the provider's response.

Saved notes remain on your device until you delete them. When you delete a note, the app also deletes any associated error message. Once the deletion is final, the app removes the audio copy if it is no longer in use. If removal fails, the app tries again during later cleanups.

Some entries from older notes may remain on your device as local recovery data. You can remove these entries by deleting the app's data in Android.

The app excludes its data from new Android cloud backups and Android device transfers. Manage existing external copies and older system backups in the service that holds them or in Android.

### Device access and providing data

The app reads and stores the settings, credentials and content it needs for the feature you request. Where section 25 of Germany's TDDDG applies to this device access, the technically necessary access is based on section 25(2)(2) TDDDG.

The app needs Android's microphone permission for new recordings and live dictation. You can change this permission in Android and still use saved notes without microphone access.

The cloud feature you choose requires your own API key and the relevant audio recording or transcript text. You are under no obligation to provide these. Without them, the corresponding cloud feature cannot run. Summaries and live dictation are optional.

### Clipboard, sharing and live dictation

When you copy, the app puts the transcript on the Android clipboard. When you share a note, the app passes its title, transcript and any short summary to the destination app you choose. If the app knows that the title or short summary was AI-generated, it labels the relevant text and includes its AI origin in machine-readable form.

Live dictation streams the microphone signal to the selected provider. The app does not store a local audio file for dictation. The recognized text appears in the open text field.

What the receiving app does with this data is governed by its settings and privacy information.

## AI providers

The app sends audio and language or model settings to your transcription provider. When summaries are enabled, it sends the transcript text and the settings selected for summarization to your summary provider. Summaries are enabled by default and can be turned off in the settings.

When you record or select an audio file, or share an audio file to Transcriber, the app shows who will receive the audio and, if applicable, the transcript text before sending them. Processing starts after you confirm. If a recipient changes when you retry, the app asks you to confirm the recipients again.

When you connect a provider, the app sends the newly entered API key to that provider for verification. It saves the key in secure device storage only after successful verification. The app uses the stored key to authenticate with the provider when you test the connection again, retrieve the model list or submit processing requests. The provider also receives technical information about the connection, such as your IP address and the time of the request.

Your agreement with your provider determines the roles and conditions for its processing. If you process other people's data for work, check what is required before recording or sending it. You may only record or share another person's privately spoken words if you have the necessary authority.

### OpenAI

Under its standard API terms, the contracting party for API customers based in the European Economic Area or Switzerland is OpenAI Ireland Ltd., 1st Floor, The Liffey Trust Centre, 117–126 Sheriff Street Upper, Dublin 1, D01 YC43, Ireland. The [Data Processing Addendum](https://openai.com/policies/data-processing-addendum/) applies to customer data that OpenAI processes on behalf of the API customer.

By default, OpenAI does not use API data to train its models. This may change if you opt in to sharing in your provider account. OpenAI says that its standard audio file transcription endpoint does not retain data in abuse monitoring logs. For live dictation and requests to the chat endpoint, which is also used for summaries or certain audio models, the default abuse monitoring retention period can be up to 30 days. Account settings, legal requirements and specific safety cases can affect retention.

The app connects to the global API address. This means that processing may take place outside the European Economic Area, particularly in the United States. [OpenAI's privacy policy](https://openai.com/policies/eu-privacy-policy/) and [OpenAI's API data controls](https://developers.openai.com/api/docs/guides/your-data) explain account data, processing and retention. The international safeguards under the API agreement include the standard contractual clauses incorporated in that agreement.

### Google Gemini

Your Google contracting entity depends on the billing address of your cloud project. Under the standard terms for Germany, it is Google Cloud EMEA Limited, 70 Sir John Rogerson’s Quay, Dublin 2, Ireland. Google allows use of the Gemini API from age 18 for professional or business purposes. In the European Economic Area, Switzerland and the United Kingdom, Google requires a project with active billing.

Under the [Gemini API terms](https://ai.google.dev/gemini-api/terms), Google processes content from paid services under its [Data Processing Addendum](https://business.safety.google/processorterms/) and does not use that content to improve its products. For safety and abuse checks, Google retains inputs, context and responses for 55 days under its [abuse monitoring policy](https://aistudio.google.com/docs/usage-policies#how-we-handle-data). Authorized staff may review flagged content. Google may also process this data outside the European Economic Area. The terms include standard contractual clauses for relevant international transfers.

Google says its [Gemini file service](https://aistudio.google.com/docs/files#delete-uploaded) automatically deletes uploaded audio files after 48 hours. Transcriber attempts to delete these files once processing has finished.

For audio file transcription and summary requests, the app turns off additional logging in the Google Cloud project. This does not affect the abuse monitoring described above. Under [Google's project logging policy](https://aistudio.google.com/docs/logs-policy), entries stored in your project are marked for deletion after a maximum of 55 days, depending on the setting. Entries saved in datasets have no fixed retention period.

If you share such datasets with Google through your project, Google may use their content to improve its products and train its models. Google prohibits sharing personal, sensitive or confidential data, as well as data from apps available to users in the European Economic Area, Switzerland or the United Kingdom.

Google processes account, billing and usage data separately under its [privacy policy](https://policies.google.com/privacy?hl=en).

If you use Gemini outside the European Economic Area, Switzerland and the United Kingdom through an unpaid service, Google uses the content you submit and the responses to provide, improve and develop its products and services. Human reviewers may read, annotate and process the content and responses. Google prohibits submitting sensitive, confidential or personal information to these services.

## Email inquiries

When you write to us, we process your email address, the content of your message and the information you provide voluntarily. We use these data to respond to your inquiry, investigate errors and handle security reports. Our legitimate interest in handling these inquiries is the legal basis under Article 6(1)(f) GDPR. Providing this information is voluntary. We need a working contact address to reply. Please do not send API keys, confidential recordings or complete transcripts in support inquiries.

We delete emails once we have finished dealing with the inquiry and no longer need them for that purpose. Where statutory retention obligations apply, we continue to store the data under Article 6(1)(c) GDPR until the applicable period ends.

### Hostinger Mail

We use Hostinger Mail to receive and deliver emails and filter spam. For customers based in Germany, the [Hostinger Terms of Service](https://www.hostinger.com/legal/universal-terms-of-service-agreement) identify Hostinger International Ltd., 61 Lordou Vironos Str., 6023 Larnaca, Cyprus, as the contracting party. Hostinger processes customer data on our behalf under Section 2.1 of its [Data Processing Addendum](https://www.hostinger.com/legal/dpa). The service processes messages, addresses and technical delivery data. Hostinger identifies Proofpoint, Inc., Cloudflare, Inc. and MailChannels Corporation as subprocessors for the mail service. According to the [Hostinger Mail documentation](https://www.hostinger.com/support/hostinger-mail-data-location-backups-and-subprocessors/), mailbox data and backups are stored in Germany and France.

Hostinger says it removes messages from the [spam and trash folders](https://www.hostinger.com/support/5240863-what-happens-to-emails-in-the-spam-folder/) after 30 days. Its [guidance on deleted mailboxes](https://www.hostinger.com/support/1583466-how-to-restore-a-deleted-hostinger-email-account/) describes restoring a mailbox within 30 days of its deletion.

For direct and onward transfers to countries outside the European Economic Area that are not covered by an adequacy decision, Section 9.1 of the Data Processing Addendum provides for the [EU standard contractual clauses](https://eur-lex.europa.eu/eli/dec_impl/2021/914/oj/eng) unless another recognized mechanism makes the transfer lawful.

## Technical logs and downloads

When you use cloud features, the app sends connection data directly to the API providers you choose. See [AI providers](#ai-providers) for information on abuse monitoring logs that can contain content and on the providers' privacy rules. BoomApps does not operate its own application server for these cloud features.

When you visit the public repository, download the app or open this policy on GitHub, GitHub processes technical data as the platform provider. Examples include your IP address, the time of access and the pages requested. GitHub uses such data to provide the platform, keep it reliable and secure, and detect abuse, among other purposes. Under [GitHub's privacy statement on retention](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement#security-and-retention), the retention period depends on the purpose and any legal obligations. GitHub also retains data as needed to fulfil contractual obligations, resolve disputes or enforce agreements.

## Public bug reports

If you post a public bug report on GitHub, its contents and your account name may be publicly visible. BoomApps uses the information you voluntarily submit to investigate and resolve issues and handle follow-up questions. The legal basis is our legitimate interest in handling bug reports under Article 6(1)(f) GDPR. Public reports can remain in the project history for as long as they are needed to understand how issues were resolved. For confidential inquiries, use [our email address](mailto:yannickschaefer@boomapps.de).

## Security in transit

Connections to API providers are encrypted in transit using TLS. The app protects API keys in secure device storage. Stored notes rely on your Android device's access controls.

## Your rights

Under applicable law, you have the right to access the personal data we process about you and to request rectification, erasure and restriction of processing. You have the right to data portability under the conditions set out in Article 20 GDPR. Where processing is based on consent, you can withdraw that consent at any time with effect for the future.

For data on your device, you can use the features provided by the app and by Android. If your question concerns data held by an API provider, contact the controller responsible for your provider account. For data we process, you can reach us at [our contact address](mailto:yannickschaefer@boomapps.de).

### Right to object under Article 21 GDPR

Where processing is based on Article 6(1)(e) or (f) GDPR, you may object at any time on grounds relating to your particular situation. We stop the processing. We may continue only if we can demonstrate compelling legitimate grounds that override your interests, rights and freedoms, or if the processing is for the establishment, exercise or defence of legal claims. You may object to processing for direct marketing at any time. After you object, the data concerned will no longer be processed for that purpose.

### Right to lodge a complaint

You have the right to lodge a complaint with a data protection authority. This can be the authority in your place of habitual residence, your place of work or the place of the alleged infringement.

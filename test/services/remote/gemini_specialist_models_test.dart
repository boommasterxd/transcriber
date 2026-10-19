import 'package:test/test.dart';
import 'package:transcriber/services/remote/gemini_model_catalog.dart';
import 'package:transcriber/services/remote/google_client.dart';
import 'package:transcriber/services/remote/provider_model_capabilities.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'http_test_client.dart';
import 'remote_test_support.dart';

const _specialistIds = [
  'antigravity-preview-05-2026',
  'antigravity-preview-09-2026',
  'antigravity-preview-latest',
  'deep-research-max-preview-04-2026',
  'deep-research-preview-04-2026',
  'deep-research-pro-preview-12-2025',
  'gemini-2.5-computer-use-preview-10-2025',
  'gemini-future-agent-preview',
  'gemini-future-agents',
  'gemini-future-harness',
  'gemini-future-deep_research',
  'gemini-future-computer.use',
  'gemini-future-browser-use',
];

void main() {
  _registerSpecialistTests();
  _registerSpecialistMetadataTests();
  _registerGeneralTests();
  _registerSavedModelTests();
}

void _registerSpecialistTests() {
  for (final id in _specialistIds) {
    test('excludes specialist $id from both tasks and ASR routing', () {
      _expectEligibility(id: id, eligible: false);
      expect(
        ProviderModelCapabilities.usesGeminiNativeTranscription('$id-asr'),
        isFalse,
      );
    });
  }
}

void _registerSpecialistMetadataTests() {
  for (final label in [
    'Antigravity Agent Preview',
    'Next Agent Preview',
    'New Harness',
    'Deep Research Pro',
    'Computer Use Preview',
    'COMPUTER_USE PREVIEW',
    'Computer.Use Preview',
    'Browser-use Preview',
  ]) {
    test('recognizes specialist display label $label', () {
      _expectEligibility(displayName: label, eligible: false);
    });
  }
  for (final description in [
    'A powerful general-purpose managed agent for multi-step workflows.',
    'An autonomous agent that runs code and manages files.',
    'A dedicated agent for secure execution.',
    'A specialized agent for multi-step workflows.',
    'A Deep Research agent that browses the web.',
    'An agentic harness with native code search tools.',
    'A new agent model.',
    'A deep-research model.',
    'A computer use model requiring an execution loop.',
    'A COMPUTER_USE MODEL requiring an execution loop.',
    'A Computer.Use Model requiring an execution loop.',
    'A browser-use model.',
    'A model for agents.',
    'Designed for computer use.',
    'Specialized for deep research.',
    'A model for browser use.',
  ]) {
    test('recognizes concrete specialist purpose $description', () {
      _expectEligibility(description: description, eligible: false);
    });
  }
}

void _registerGeneralTests() {
  for (final id in [
    'gemini-3.8-flash',
    'gemini-99-pro-preview-2040-01-01',
    'next-general-family',
    'gemini-future-researcher',
    'gemini-future-agentic',
  ]) {
    test('retains general and future model $id', () {
      _expectEligibility(
        id: id,
        displayName: 'General Reasoning Model',
        description:
            'General multimodal model with advanced reasoning, research, '
            'deep research capabilities, coding and support for agents.',
        eligible: true,
      );
    });
  }
  test('does not reject research or agentic capability prose', () {
    _expectEligibility(
      description:
          'A general model that powers deep research and computer use '
          'applications with advanced agentic capabilities.',
      eligible: true,
    );
  });
}

void _registerSavedModelTests() {
  for (final id in _specialistIds.take(7)) {
    test('rejects saved specialist $id without any provider request', () async {
      final httpClient = RecordingHttpClient((_) async => jsonResponse({}));
      final client = GoogleClient(apiKey: 'test-key', httpClient: httpClient);
      await expectLater(
        client.summarize(systemPrompt: '', userPrompt: '', modelId: id),
        throwsA(_unsupportedModel('text summaries')),
      );
      await withTemporaryAudio(
        prefix: 'specialist-model-',
        action: (file) async {
          await expectLater(
            client.transcribe(file.path, modelId: id),
            throwsA(_unsupportedModel('audio transcription')),
          );
        },
      );
      expect(httpClient.requests, isEmpty);
    });
  }
}

Matcher _unsupportedModel(String task) => isA<RemoteApiException>().having(
  (error) => error.message,
  'message',
  'The selected Gemini model does not support $task.',
);

void _expectEligibility({
  String id = 'gemini-future',
  String? displayName,
  String? description,
  required bool eligible,
}) {
  for (final transcription in [false, true]) {
    final classify = transcription
        ? ProviderModelCapabilities.isGeminiTranscriptionModel
        : ProviderModelCapabilities.isGeminiSummaryModel;
    expect(
      classify(
        id,
        const {'generateContent'},
        displayName: displayName,
        description: description,
      ),
      eligible,
    );
    final catalogEntry = geminiCatalogModel({
      'name': 'models/$id',
      'displayName': displayName,
      'description': description,
      'supportedGenerationMethods': ['generateContent'],
    }, forTranscription: transcription);
    expect(catalogEntry?.id, eligible ? id : isNull);
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/service_exceptions.dart';
import 'package:transcriber/state/connections_controller.dart';
import 'package:transcriber/state/providers.dart';
import 'package:transcriber/state/remote_models_provider.dart';

import 'state_test_fakes.dart';

late ProviderContainer _container;
late AppDatabase _database;
late FakeSettingsRepository _repository;
late _QueuedHttpOverrides _httpOverrides;

void main() {
  setUp(() {
    _database = createTestDatabase();
    _repository = FakeSettingsRepository(_database);
    _httpOverrides = _QueuedHttpOverrides();
    HttpOverrides.global = _httpOverrides;
    _container = ProviderContainer(
      overrides: [
        initialConnectionsProvider.overrideWithValue(
          const <RemoteProviderId, bool>{},
        ),
        settingsRepositoryProvider.overrideWithValue(_repository),
        providerCredentialTesterProvider.overrideWithValue((_, _) async {}),
      ],
    );
  });

  tearDown(() async {
    _container.dispose();
    HttpOverrides.global = null;
    await _database.close();
  });

  _registerKeyAndSuccessTests();
  _registerErrorAndInvalidationTests();
  _registerCapabilityTests();
  _registerSharedCatalogTests();
  _registerInFlightCredentialTest();
  _registerCredentialScopeTests();
}

void _registerSharedCatalogTests() {
  for (final provider in RemoteProviderId.values) {
    test(
      '${provider.id} shares cold, warm and refreshed stage catalogs',
      () async {
        _repository.keys[provider] = 'test-key';
        _enqueueCatalog(provider);
        final transcription = (provider: provider, forTranscription: true);
        final summary = (provider: provider, forTranscription: false);
        final stages = await Future.wait([
          _container.read(remoteModelsProvider(transcription).future),
          _container.read(remoteModelsProvider(summary).future),
        ]);
        expect(stages.every((models) => models.isNotEmpty), isTrue);
        final pageCount = provider == RemoteProviderId.google ? 2 : 1;
        expect(_httpOverrides.requests, hasLength(pageCount));
        _container.invalidate(remoteModelsProvider(summary));
        expect(
          await _container.read(remoteModelsProvider(summary).future),
          isNotEmpty,
        );
        expect(_httpOverrides.requests, hasLength(pageCount));

        _enqueueCatalog(provider);
        _container.invalidate(remoteModelCatalogProvider(provider));
        await Future.wait([
          _container.read(remoteModelsProvider(transcription).future),
          _container.read(remoteModelsProvider(summary).future),
        ]);
        expect(_httpOverrides.requests, hasLength(pageCount * 2));
        expect(_httpOverrides.closeCalls, 2);
      },
    );
  }

  test(
    'both stages share errors and recover through a raw catalog refresh',
    () async {
      _repository.keys[RemoteProviderId.openai] = 'test-key';
      _httpOverrides.enqueue(401, '{"error":"denied"}');
      const transcription = (
        provider: RemoteProviderId.openai,
        forTranscription: true,
      );
      const summary = (
        provider: RemoteProviderId.openai,
        forTranscription: false,
      );
      final futures = [
        _container.read(remoteModelsProvider(transcription).future),
        _container.read(remoteModelsProvider(summary).future),
      ];
      await Future.wait([
        for (final future in futures)
          expectLater(future, throwsA(isA<RemoteApiException>())),
      ]);
      expect(_httpOverrides.requests, hasLength(1));
      _enqueueCatalog(RemoteProviderId.openai);
      _container.invalidate(
        remoteModelCatalogProvider(RemoteProviderId.openai),
      );
      for (final query in [transcription, summary]) {
        expect(
          await _container.read(remoteModelsProvider(query).future),
          isNotEmpty,
        );
      }
      expect(_httpOverrides.requests, hasLength(2));
    },
  );
}

void _registerInFlightCredentialTest() {
  test(
    'replaced in-flight catalog cannot restore the previous account',
    () async {
      _repository.keys[RemoteProviderId.openai] = 'old-key';
      final release = Completer<void>();
      _httpOverrides.enqueue(200, '{"data":[{"id":"gpt-4o"}]}', release.future);
      const query = (
        provider: RemoteProviderId.openai,
        forTranscription: false,
      );
      final pending = _container.read(remoteModelsProvider(query).future);
      await _httpOverrides.requestStarted.future;
      _httpOverrides.enqueue(200, '{"data":[{"id":"gpt-4.1-mini"}]}');
      await _container
          .read(connectionsControllerProvider.notifier)
          .connect(RemoteProviderId.openai, 'replacement-key');
      final current = await _container.read(remoteModelsProvider(query).future);
      release.complete();
      await pending;
      expect(current.single.id, 'gpt-4.1-mini');
      expect(
        (await _container.read(remoteModelsProvider(query).future)).single.id,
        'gpt-4.1-mini',
      );
      expect(_httpOverrides.requests, hasLength(2));
    },
  );
}

void _registerCredentialScopeTests() {
  test(
    'credential replacement and disconnect discard both stage catalogs',
    () async {
      final controller = _container.read(
        connectionsControllerProvider.notifier,
      );
      _repository.keys[RemoteProviderId.openai] = 'old-key';
      _enqueueCatalog(RemoteProviderId.openai);
      const transcription = (
        provider: RemoteProviderId.openai,
        forTranscription: true,
      );
      const summary = (
        provider: RemoteProviderId.openai,
        forTranscription: false,
      );
      await _container.read(remoteModelsProvider(transcription).future);
      await controller.connect(RemoteProviderId.openai, 'replacement-key');
      _enqueueCatalog(RemoteProviderId.openai);
      await _container.read(remoteModelsProvider(summary).future);
      await _container.read(remoteModelsProvider(transcription).future);
      expect(_httpOverrides.requests, hasLength(2));
      expect(
        _httpOverrides.requests.last.headers.value('authorization'),
        'Bearer replacement-key',
      );
      await controller.disconnect(RemoteProviderId.openai);
      expect(
        await _container.read(remoteModelsProvider(transcription).future),
        isEmpty,
      );
      expect(
        await _container.read(remoteModelsProvider(summary).future),
        isEmpty,
      );
      expect(_httpOverrides.requests, hasLength(2));
      await controller.connect(RemoteProviderId.openai, 'reconnected-key');
      _enqueueCatalog(RemoteProviderId.openai);
      expect(
        await _container.read(remoteModelsProvider(summary).future),
        isNotEmpty,
      );
      expect(_httpOverrides.requests, hasLength(3));
    },
  );

  test(
    'unrelated and failed credential changes retain a warm catalog',
    () async {
      _repository.keys[RemoteProviderId.openai] = 'stable-key';
      _enqueueCatalog(RemoteProviderId.openai);
      const query = (
        provider: RemoteProviderId.openai,
        forTranscription: false,
      );
      await _container.read(remoteModelsProvider(query).future);
      final controller = _container.read(
        connectionsControllerProvider.notifier,
      );
      await controller.connect(RemoteProviderId.google, 'google-key');
      await controller.disconnect(RemoteProviderId.google);
      _container.updateOverrides([
        initialConnectionsProvider.overrideWithValue(
          const <RemoteProviderId, bool>{},
        ),
        settingsRepositoryProvider.overrideWithValue(_repository),
        providerCredentialTesterProvider.overrideWithValue((_, _) async {
          throw StateError('invalid credential');
        }),
      ]);
      await expectLater(
        controller.connect(RemoteProviderId.openai, 'invalid-key'),
        throwsStateError,
      );
      expect(
        await _container.read(remoteModelsProvider(query).future),
        isNotEmpty,
      );
      expect(_repository.keys[RemoteProviderId.openai], 'stable-key');
      expect(_httpOverrides.requests, hasLength(1));
    },
  );
}

void _enqueueCatalog(RemoteProviderId provider) {
  if (provider == RemoteProviderId.openai) {
    _httpOverrides.enqueue(
      200,
      '{"data":[{"id":"whisper-1"},{"id":"gpt-4o"}]}',
    );
    return;
  }
  _httpOverrides.enqueue(
    200,
    '{"models":[{"name":"models/gemini-3.5-transcribe",'
    '"supportedGenerationMethods":["generateContent"]}],"nextPageToken":"second"}',
  );
  _httpOverrides.enqueue(
    200,
    '{"models":[{"name":"models/gemini-3.8-flash",'
    '"supportedGenerationMethods":["generateContent"]}]}',
  );
}

void _registerKeyAndSuccessTests() {
  test('returns no models and makes no request without an API key', () async {
    const query = (provider: RemoteProviderId.openai, forTranscription: false);

    expect(await _container.read(remoteModelsProvider(query).future), isEmpty);
    expect(_httpOverrides.requests, isEmpty);
  });

  test('uses the connection key and returns sorted chat models', () async {
    _repository.keys[RemoteProviderId.openai] = 'test-key';
    _httpOverrides.enqueue(
      200,
      '{"data":[{"id":"gpt-5.6-luna"},{"id":"whisper-1"},'
      '{"id":"gpt-4o"}]}',
    );
    const query = (provider: RemoteProviderId.openai, forTranscription: false);

    final models = await _container.read(remoteModelsProvider(query).future);

    expect(models.map((model) => model.id), ['gpt-4o', 'gpt-5.6-luna']);
    expect(_httpOverrides.requests.single.uri.path, '/v1/models');
    expect(
      _httpOverrides.requests.single.headers.value('authorization'),
      'Bearer test-key',
    );
    expect(_httpOverrides.closeCalls, 1);
  });
}

void _registerCapabilityTests() {
  test('forwards the transcription flag to provider filtering', () async {
    _repository.keys[RemoteProviderId.openai] = 'test-key';
    _httpOverrides.enqueue(
      200,
      '{"data":[{"id":"gpt-chat"},{"id":"whisper-1"},'
      '{"id":"gpt-4o-transcribe"}]}',
    );
    const query = (provider: RemoteProviderId.openai, forTranscription: true);

    final models = await _container.read(remoteModelsProvider(query).future);

    expect(models.map((model) => model.id), ['gpt-4o-transcribe', 'whisper-1']);
  });
}

void _registerErrorAndInvalidationTests() {
  test('does not inject a default into an incompatible live catalog', () async {
    _repository.keys[RemoteProviderId.google] = 'test-key';
    _httpOverrides.enqueue(
      200,
      '{"models":[{"name":"models/gemini-omni-1.1-flash",'
      '"supportedGenerationMethods":["generateContent"]}]}',
    );
    const query = (provider: RemoteProviderId.google, forTranscription: false);

    expect(await _container.read(remoteModelsProvider(query).future), isEmpty);
    expect(_httpOverrides.requests, hasLength(1));
  });

  test('surfaces provider errors through the future state', () async {
    _repository.keys[RemoteProviderId.openai] = 'test-key';
    _httpOverrides.enqueue(200, '{invalid-json');
    const query = (provider: RemoteProviderId.openai, forTranscription: false);

    final error = Completer<Object>();
    final subscription = _container.listen(remoteModelsProvider(query), (
      _,
      next,
    ) {
      if (next.hasError && !error.isCompleted) error.complete(next.error!);
    }, fireImmediately: true);
    addTearDown(subscription.close);

    expect(await error.future, isA<RemoteApiException>());
    expect(_httpOverrides.closeCalls, 1);
  });

  test('connection changes invalidate and refetch the same query', () async {
    const query = (provider: RemoteProviderId.openai, forTranscription: false);
    expect(await _container.read(remoteModelsProvider(query).future), isEmpty);
    _httpOverrides.enqueue(200, '{"data":[{"id":"gpt-4.1-mini"}]}');

    await _container
        .read(connectionsControllerProvider.notifier)
        .connect(RemoteProviderId.openai, 'new-key');
    final models = await _container.read(remoteModelsProvider(query).future);

    expect(models.map((model) => model.id), ['gpt-4.1-mini']);
    expect(_httpOverrides.requests, hasLength(1));
  });
}

class _QueuedHttpOverrides extends HttpOverrides {
  final List<_Reply> _replies = [];
  final List<_FakeRequest> requests = [];
  int closeCalls = 0;
  final requestStarted = Completer<void>();

  void enqueue(int statusCode, String body, [Future<void>? ready]) {
    _replies.add(_Reply(statusCode, body, ready));
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient(
    onClose: () => closeCalls++,
    onRequest: (method, uri) {
      final request = _FakeRequest(method, uri, _replies.removeAt(0));
      requests.add(request);
      if (!requestStarted.isCompleted) requestStarted.complete();
      return request;
    },
  );
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient({required this.onRequest, required this.onClose});

  final _FakeRequest Function(String method, Uri uri) onRequest;
  final void Function() onClose;

  @override
  void close({bool force = false}) => onClose();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      onRequest(method, url);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this.method, this.uri, this.reply);

  @override
  final String method;
  @override
  final Uri uri;
  final _Reply reply;
  @override
  final HttpHeaders headers = _FakeHeaders();
  final List<int> body = [];

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final bytes in stream) {
      body.addAll(bytes);
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    await reply.ready;
    return _FakeResponse(reply);
  }

  @override
  Future<HttpClientResponse> get done async => _FakeResponse(reply);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(this.reply);

  final _Reply reply;

  @override
  int get statusCode => reply.statusCode;

  @override
  int get contentLength => utf8.encode(reply.body).length;

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => statusCode == 200 ? 'OK' : 'Error';

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  HttpHeaders get headers => _FakeHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(utf8.encode(reply.body)).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHeaders implements HttpHeaders {
  final Map<String, List<String>> _values = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name.toLowerCase()] = [value.toString()];
  }

  @override
  String? value(String name) => _values[name.toLowerCase()]?.join(',');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Reply {
  const _Reply(this.statusCode, this.body, this.ready);

  final int statusCode;
  final String body;
  final Future<void>? ready;
}

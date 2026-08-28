import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/state/connections_controller.dart';
import 'package:transcriber/state/providers.dart';
import 'package:transcriber/state/remote_models_provider.dart';

import 'state_test_fakes.dart';

late ProviderContainer _container;
late FakeSettingsRepository _repository;
late _QueuedHttpOverrides _httpOverrides;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _repository = FakeSettingsRepository(await SharedPreferences.getInstance());
    _httpOverrides = _QueuedHttpOverrides();
    HttpOverrides.global = _httpOverrides;
    _container = ProviderContainer(
      overrides: [
        initialConnectionsProvider.overrideWithValue(
          const <RemoteProviderId, bool>{},
        ),
        settingsRepositoryProvider.overrideWithValue(_repository),
      ],
    );
  });

  tearDown(() {
    _container.dispose();
    HttpOverrides.global = null;
  });

  _registerKeyAndSuccessTests();
  _registerErrorAndInvalidationTests();
  _registerCapabilityTests();
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
      '{"data":[{"id":"z-chat"},{"id":"whisper-1"},{"id":"a-chat"}]}',
    );
    const query = (provider: RemoteProviderId.openai, forTranscription: false);

    final models = await _container.read(remoteModelsProvider(query).future);

    expect(models.map((model) => model.id), ['a-chat', 'z-chat']);
    expect(_httpOverrides.requests.single.uri.path, '/v1/models');
    expect(
      _httpOverrides.requests.single.headers.value('authorization'),
      'Bearer test-key',
    );
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

  test(
    'provider without transcription support returns no models locally',
    () async {
      _repository.keys[RemoteProviderId.anthropic] = 'test-key';
      const query = (
        provider: RemoteProviderId.anthropic,
        forTranscription: true,
      );

      expect(
        await _container.read(remoteModelsProvider(query).future),
        isEmpty,
      );
      expect(_httpOverrides.requests, isEmpty);
    },
  );
}

void _registerErrorAndInvalidationTests() {
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

    expect(await error.future, isA<FormatException>());
  });

  test('connection changes invalidate and refetch the same query', () async {
    const query = (provider: RemoteProviderId.openai, forTranscription: false);
    expect(await _container.read(remoteModelsProvider(query).future), isEmpty);
    _httpOverrides.enqueue(200, '{"data":[{"id":"new-model"}]}');

    await _container
        .read(connectionsControllerProvider.notifier)
        .connect(RemoteProviderId.openai, 'new-key');
    final models = await _container.read(remoteModelsProvider(query).future);

    expect(models.single.id, 'new-model');
    expect(_httpOverrides.requests, hasLength(1));
  });
}

class _QueuedHttpOverrides extends HttpOverrides {
  final List<_Reply> _replies = [];
  final List<_FakeRequest> requests = [];

  void enqueue(int statusCode, String body) {
    _replies.add(_Reply(statusCode, body));
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient(
    onRequest: (method, uri) {
      final request = _FakeRequest(method, uri, _replies.removeAt(0));
      requests.add(request);
      return request;
    },
  );
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient({required this.onRequest});

  final _FakeRequest Function(String method, Uri uri) onRequest;

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
  Future<HttpClientResponse> close() async => _FakeResponse(reply);

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
  const _Reply(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:transcriber/services/share/share_intent_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _registerShareIntentTests();
}

void _registerShareIntentTests() {
  late StreamController<List<SharedMediaFile>> streamController;

  setUp(() {
    streamController = StreamController<List<SharedMediaFile>>.broadcast();
    _setMockMedia(streamController, const []);
  });

  tearDown(() async {
    await streamController.close();
  });

  group('ShareIntentService', () {
    _registerColdStartTests(() => streamController);
    _registerWarmShareTests(() => streamController);
    _registerProviderFailureTest();
  });
}

void _registerColdStartTests(
  StreamController<List<SharedMediaFile>> Function() getController,
) {
  test('returns the first supported audio file from a cold start', () async {
    _setMockMedia(getController(), [
      _media('/cache/readme.txt'),
      _media('/cache/voice.M4A'),
      _media('/cache/second.mp3'),
    ]);

    final result = await ShareIntentService().initialSharedAudio();

    expect(result, '/cache/voice.M4A');
    expect(await ReceiveSharingIntent.instance.getInitialMedia(), isEmpty);
  });

  test(
    'returns null when cold-start media contains no audio candidate',
    () async {
      _setMockMedia(getController(), [
        _media('/cache/message.mp3', SharedMediaType.text),
        _media('/cache/link.m4a', SharedMediaType.url),
        _media('/cache/photo.jpg'),
      ]);

      final result = await ShareIntentService().initialSharedAudio();

      expect(result, isNull);
      expect(await ReceiveSharingIntent.instance.getInitialMedia(), isEmpty);
    },
  );

  test('accepts every supported extension case-insensitively', () async {
    final paths = <String>[
      '/cache/a.WAV',
      '/cache/b.MP3',
      '/cache/c.M4A',
      '/cache/d.MP4',
      '/cache/e.OGG',
      '/cache/f.OPUS',
      '/cache/g.FLAC',
      '/cache/h.WEBM',
      '/cache/i.MPEG',
      '/cache/j.MPGA',
    ];

    for (final path in paths) {
      _setMockMedia(getController(), [_media(path)]);
      expect(await ShareIntentService().initialSharedAudio(), path);
    }
  });

  test(
    'filters text, URLs, unsupported extensions, and extension tricks',
    () async {
      _setMockMedia(getController(), [
        _media('/cache/notes.mp3', SharedMediaType.text),
        _media('/cache/link.ogg', SharedMediaType.url),
        _media('/cache/image.jpg'),
        _media('/cache/audio.mp3.bak'),
        _media('/cache/audio'),
      ]);

      final result = await ShareIntentService().initialSharedAudio();

      expect(result, isNull);
    },
  );
}

void _registerWarmShareTests(
  StreamController<List<SharedMediaFile>> Function() getController,
) {
  test('emits only supported files for each warm share event', () async {
    final received = <String>[];
    final service = ShareIntentService();
    service.listen(received.add);

    await getController().addStream(
      Stream.value([
        _media('/cache/voice.wav'),
        _media('/cache/metadata.json'),
        _media('/cache/caption.mp3', SharedMediaType.text),
      ]),
    );
    await getController().addStream(
      Stream.value([_media('/cache/follow-up.OGG')]),
    );

    expect(received, ['/cache/voice.wav', '/cache/follow-up.OGG']);
    service.dispose();
  });

  test('resets warm-share state and stops after dispose', () async {
    _setMockMedia(getController(), [_media('/cache/initial.m4a')]);
    final received = <String>[];
    final service = ShareIntentService();
    service.listen(received.add);

    await getController().addStream(Stream.value([_media('/cache/warm.m4a')]));
    expect(await ReceiveSharingIntent.instance.getInitialMedia(), isEmpty);

    service.dispose();
    await getController().addStream(Stream.value([_media('/cache/late.m4a')]));

    expect(received, ['/cache/warm.m4a']);
  });
}

void _registerProviderFailureTest() {
  test('propagates an initial provider failure to the caller', () async {
    ReceiveSharingIntent.instance = _FailingSharingIntent();

    expect(ShareIntentService().initialSharedAudio, throwsA(isA<StateError>()));
  });
}

SharedMediaFile _media(
  String path, [
  SharedMediaType type = SharedMediaType.file,
]) => SharedMediaFile(path: path, type: type);

void _setMockMedia(
  StreamController<List<SharedMediaFile>> controller,
  List<SharedMediaFile> initialMedia,
) {
  ReceiveSharingIntent.setMockValues(
    initialMedia: initialMedia,
    mediaStream: controller.stream,
  );
}

final class _FailingSharingIntent extends ReceiveSharingIntent {
  @override
  Future<List<SharedMediaFile>> getInitialMedia() =>
      Future<List<SharedMediaFile>>.error(StateError('provider failed'));

  @override
  Stream<List<SharedMediaFile>> getMediaStream() => const Stream.empty();

  @override
  Future<dynamic> reset() async {}
}

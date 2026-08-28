import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/audio/audio_metadata.dart';

const _audioMainChannel = MethodChannel('com.ryanheise.just_audio.methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MethodChannel? playerChannel;
  late EventChannel? eventChannel;
  final state = _MetadataState();
  var disposeCalls = 0;

  setUp(() {
    playerChannel = null;
    eventChannel = null;
    state.reset();
    disposeCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_audioMainChannel, (call) async {
          if (call.method == 'init') {
            final mocks = _installPlayerMocks(call, state);
            playerChannel = mocks.player;
            eventChannel = mocks.events;
          }
          if (call.method == 'disposePlayer') disposeCalls++;
          return <String, dynamic>{};
        });
  });

  tearDown(() {
    _removeChannelMock(_audioMainChannel);
    if (playerChannel != null) _removeChannelMock(playerChannel!);
    if (eventChannel != null) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(eventChannel!, null);
    }
  });

  test('returns the loaded duration in whole seconds', () async {
    final seconds = await const AudioMetadata().durationSeconds('/voice.wav');

    expect(seconds, 12);
    expect(disposeCalls, 1);
  });

  test('maps an unavailable duration to zero', () async {
    state.durationMicros = null;

    expect(await const AudioMetadata().durationSeconds('/unknown.wav'), 0);
    expect(disposeCalls, 1);
  });

  test('returns zero after a platform loading error and disposes', () async {
    state.loadError = true;

    expect(await const AudioMetadata().durationSeconds('/broken.wav'), 0);
    expect(disposeCalls, 1);
  });
}

class _MetadataState {
  bool loadError = false;
  int? durationMicros;

  void reset() {
    loadError = false;
    durationMicros = const Duration(
      seconds: 12,
      milliseconds: 900,
    ).inMicroseconds;
  }
}

({MethodChannel player, EventChannel events}) _installPlayerMocks(
  MethodCall call,
  _MetadataState state,
) {
  final playerId = (call.arguments as Map)['id'] as String;
  final playerChannel = MethodChannel(
    'com.ryanheise.just_audio.methods.$playerId',
  );
  final eventChannel = EventChannel(
    'com.ryanheise.just_audio.events.$playerId',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(playerChannel, (playerCall) async {
        if (playerCall.method == 'load' && state.loadError) {
          throw PlatformException(code: 'decode_failed');
        }
        if (playerCall.method == 'load') {
          return <String, dynamic>{'duration': state.durationMicros ?? -1};
        }
        return <String, dynamic>{};
      });
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (_, events) {
            final duration = state.durationMicros ?? -1;
            events.success(<String, dynamic>{
              'processingState': 3,
              'updateTime': 0,
              'updatePosition': 0,
              'bufferedPosition': duration < 0 ? 0 : duration,
              'duration': duration,
              'icyMetadata': null,
              'currentIndex': 0,
              'androidAudioSessionId': null,
            });
          },
        ),
      );
  return (player: playerChannel, events: eventChannel);
}

void _removeChannelMock(MethodChannel channel) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
}

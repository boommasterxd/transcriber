import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/ui/screens/detail/widgets/detail_audio_player.dart';
import 'package:transcriber/ui/widgets/waveforms.dart';

void main() {
  final fixture = _AudioFileFixture();
  setUp(fixture.create);
  tearDown(fixture.dispose);
  _registerAvailabilityTests(fixture);
  _registerInteractionTests(fixture);
  _registerPositionTests(fixture);
  _registerLifecycleTests(fixture);
}

void _registerAvailabilityTests(_AudioFileFixture fixture) {
  testWidgets('disables playback when the source audio is missing', (
    tester,
  ) async {
    var factoryCalls = 0;
    await _pumpPlayer(
      tester,
      audioPath: '${fixture.temporaryDirectory.path}/missing.wav',
      durationSec: 42,
      playerFactory: () {
        factoryCalls++;
        return _FakePlayer();
      },
    );

    expect(factoryCalls, 0);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.text('0:00 / 0:42'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();

    expect(factoryCalls, 0);
  });

  testWidgets('uses the loaded duration and enables playback', (tester) async {
    final player = _FakePlayer(loadedDuration: const Duration(seconds: 75));

    await _pumpPlayer(tester, audioPath: fixture.audioPath, player: player);

    expect(player.loadedPaths, [fixture.audioPath]);
    expect(find.text('0:00 / 1:15'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow));

    expect(player.playCalls, 1);
  });

  testWidgets('keeps playback disabled and releases a failed player', (
    tester,
  ) async {
    final player = _FakePlayer(loadError: StateError('load failed'));

    await _pumpPlayer(tester, audioPath: fixture.audioPath, player: player);

    expect(player.disposeCalls, 1);
    await tester.tap(find.byIcon(Icons.play_arrow));
    expect(player.playCalls, 0);

    await _pumpPlayer(
      tester,
      audioPath: fixture.audioPath,
      playerFactory: createDefaultDetailAudioPlayer,
    );
    expect(tester.takeException(), isNull);
  });
}

void _registerInteractionTests(_AudioFileFixture fixture) {
  testWidgets('falls back to the note duration when loading returns null', (
    tester,
  ) async {
    final player = _FakePlayer();

    await _pumpPlayer(
      tester,
      audioPath: fixture.audioPath,
      durationSec: 8,
      player: player,
    );

    expect(find.text('0:00 / 0:08'), findsOneWidget);
    final waveform = tester.widget<PlayerWave>(find.byType(PlayerWave));
    waveform.onSeek!(-0.25);
    waveform.onSeek!(1.25);

    expect(player.seekPositions, [Duration.zero, const Duration(seconds: 8)]);
  });

  testWidgets('toggles play and pause from reported playback state', (
    tester,
  ) async {
    final player = _FakePlayer(loadedDuration: const Duration(seconds: 10));
    await _pumpPlayer(tester, audioPath: fixture.audioPath, player: player);

    await tester.tap(find.byIcon(Icons.play_arrow));
    expect(player.playCalls, 1);

    player.emitPlayback(playing: true);
    await tester.pump();
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause));
    expect(player.pauseCalls, 1);
  });

  testWidgets('resets and pauses completed playback', (tester) async {
    final player = _FakePlayer(loadedDuration: const Duration(seconds: 10));
    await _pumpPlayer(tester, audioPath: fixture.audioPath, player: player);
    player.emitPosition(const Duration(seconds: 9));
    player.emitPlayback(playing: true);
    await tester.pump();

    player.emitPlayback(playing: true, completed: true);
    await tester.pump();

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.text('0:00 / 0:10'), findsOneWidget);
    expect(player.seekPositions, [Duration.zero]);
    expect(player.pauseCalls, 1);
  });

  testWidgets('restarts playback when the current position reached the end', (
    tester,
  ) async {
    final player = _FakePlayer(loadedDuration: const Duration(seconds: 10));
    await _pumpPlayer(tester, audioPath: fixture.audioPath, player: player);
    player.emitPosition(const Duration(seconds: 12));
    await tester.pump();

    expect(tester.widget<PlayerWave>(find.byType(PlayerWave)).progress, 1);
    await tester.tap(find.byIcon(Icons.play_arrow));

    expect(player.seekPositions, [Duration.zero]);
    expect(player.playCalls, 1);
  });
}

void _registerPositionTests(_AudioFileFixture fixture) {
  testWidgets('rebuilds progress only for a visible position bucket', (
    tester,
  ) async {
    final player = _FakePlayer(loadedDuration: const Duration(seconds: 10));
    await _pumpPlayer(tester, audioPath: fixture.audioPath, player: player);

    player.emitPosition(const Duration(milliseconds: 100));
    await tester.pump();
    expect(tester.widget<PlayerWave>(find.byType(PlayerWave)).progress, 0.01);

    player.emitPosition(const Duration(milliseconds: 110));
    await tester.pump();
    expect(tester.widget<PlayerWave>(find.byType(PlayerWave)).progress, 0.01);

    player.emitPosition(const Duration(milliseconds: 200));
    await tester.pump();
    expect(tester.widget<PlayerWave>(find.byType(PlayerWave)).progress, 0.02);
  });
}

void _registerLifecycleTests(_AudioFileFixture fixture) {
  testWidgets('cancels subscriptions and disposes the player', (tester) async {
    final player = _FakePlayer(loadedDuration: const Duration(seconds: 10));
    await _pumpPlayer(tester, audioPath: fixture.audioPath, player: player);
    expect(player.hasPositionListener, isTrue);
    expect(player.hasPlaybackListener, isTrue);

    await tester.pumpWidget(const SizedBox());

    expect(player.disposeCalls, 1);
    expect(player.hasPositionListener, isFalse);
    expect(player.hasPlaybackListener, isFalse);
  });

  testWidgets('does not update state after disposal while loading', (
    tester,
  ) async {
    final loadCompleter = Completer<Duration?>();
    final player = _FakePlayer(loadCompleter: loadCompleter);
    await _pumpPlayer(tester, audioPath: fixture.audioPath, player: player);

    await tester.pumpWidget(const SizedBox());
    loadCompleter.complete(const Duration(seconds: 10));
    await tester.pump();

    expect(player.disposeCalls, 1);
    expect(player.hasPositionListener, isFalse);
    expect(player.hasPlaybackListener, isFalse);
    expect(tester.takeException(), isNull);
  });
}

class _AudioFileFixture {
  late Directory temporaryDirectory;
  late String audioPath;

  void create() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'detail_audio_player_test_',
    );
    audioPath = '${temporaryDirectory.path}/audio.wav';
    File(audioPath).writeAsStringSync('test');
  }

  void dispose() {
    temporaryDirectory.deleteSync(recursive: true);
  }
}

Future<void> _pumpPlayer(
  WidgetTester tester, {
  required String audioPath,
  int durationSec = 30,
  _FakePlayer? player,
  DetailAudioPlayerFactory? playerFactory,
}) async {
  final resolvedPlayer = player ?? _FakePlayer();
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        extensions: <ThemeExtension<dynamic>>[AppPalette.light(AppAccent.blue)],
      ),
      home: Scaffold(
        body: DetailAudioPlayer(
          key: UniqueKey(),
          audioPath: audioPath,
          durationSec: durationSec,
          playerFactory: playerFactory ?? () => resolvedPlayer,
        ),
      ),
    ),
  );
  await tester.pump();
}

class _FakePlayer implements DetailAudioPlayerPort {
  _FakePlayer({this.loadedDuration, this.loadError, this.loadCompleter});

  final Duration? loadedDuration;
  final Object? loadError;
  final Completer<Duration?>? loadCompleter;
  final StreamController<Duration> _positions =
      StreamController<Duration>.broadcast(sync: true);
  final StreamController<DetailPlaybackState> _playbackStates =
      StreamController<DetailPlaybackState>.broadcast(sync: true);
  final List<String> loadedPaths = [];
  final List<Duration> seekPositions = [];
  int playCalls = 0;
  int pauseCalls = 0;
  int disposeCalls = 0;

  bool get hasPositionListener => _positions.hasListener;
  bool get hasPlaybackListener => _playbackStates.hasListener;

  @override
  Stream<Duration> get positionStream => _positions.stream;

  @override
  Stream<DetailPlaybackState> get playbackStateStream => _playbackStates.stream;

  @override
  Future<Duration?> load(String path) async {
    loadedPaths.add(path);
    final error = loadError;
    if (error != null) throw error;
    final completer = loadCompleter;
    if (completer != null) return completer.future;
    return loadedDuration;
  }

  @override
  Future<void> play() async => playCalls++;

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> seek(Duration position) async => seekPositions.add(position);

  @override
  Future<void> dispose() async => disposeCalls++;

  void emitPosition(Duration position) => _positions.add(position);

  void emitPlayback({required bool playing, bool completed = false}) {
    _playbackStates.add(
      DetailPlaybackState(playing: playing, completed: completed),
    );
  }
}

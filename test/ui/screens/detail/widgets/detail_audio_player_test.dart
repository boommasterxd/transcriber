import 'dart:async';
import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_theme.dart';
import 'package:transcriber/ui/screens/detail/widgets/detail_audio_player.dart';
import 'package:transcriber/ui/widgets/waveforms.dart';

void main() {
  final fixture = _AudioFileFixture();
  setUp(fixture.create);
  tearDown(fixture.dispose);
  _registerAvailabilityTests(fixture);
  _registerInteractionTests(fixture);
  _registerCompletionTests(fixture);
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
    _expectDisabledControls(tester);
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
    await tester.tap(find.byType(Slider));
    expect(player.seekPositions, [const Duration(seconds: 4)]);
  });

  testWidgets('plays, pauses and seeks with a keyboard', (tester) async {
    final player = _FakePlayer(loadedDuration: const Duration(seconds: 120));
    await _pumpPlayer(tester, audioPath: fixture.audioPath, player: player);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(player.playCalls, 1);

    player.emitPlayback(playing: true);
    await tester.pump();
    expect(
      find.byTooltip(AppStrings.of(AppLanguage.en).audioPause),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(player.pauseCalls, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(player.seekPositions, [const Duration(seconds: 6)]);
  });

  testWidgets('exposes the localized playback and adjustable position', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('de')];
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(240, 640);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final player = _FakePlayer(loadedDuration: const Duration(seconds: 120));
    await _pumpPlayer(
      tester,
      audioPath: fixture.audioPath,
      player: player,
      brightness: Brightness.dark,
    );
    player.emitPosition(const Duration(minutes: 1));
    await tester.pump();

    final strings = AppStrings.of(AppLanguage.de);
    final button = find.byType(IconButton);
    final playback = tester.getSemantics(button).getSemanticsData();
    expect(playback.tooltip, strings.audioPlay);
    expect(playback.hasAction(SemanticsAction.tap), isTrue);
    expect(tester.getSize(button).shortestSide, greaterThanOrEqualTo(48));

    final position = tester.getSemantics(
      find.bySemanticsLabel(strings.audioPosition),
    );
    final data = position.getSemanticsData();
    expect(data.flagsCollection.isSlider, isTrue);
    expect(data.value, strings.audioPositionValue('1:00', '2:00'));
    expect(data.hasAction(SemanticsAction.increase), isTrue);
    expect(data.hasAction(SemanticsAction.decrease), isTrue);
    expect(position.rect.shortestSide, greaterThanOrEqualTo(48));
    position.owner!.performAction(position.id, SemanticsAction.decrease);
    expect(player.seekPositions, [const Duration(seconds: 54)]);
    expect(tester.takeException(), isNull);
  });
}

void _registerCompletionTests(_AudioFileFixture fixture) {
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
    _expectDisabledControls(tester);

    await tester.pumpWidget(const SizedBox());
    loadCompleter.complete(const Duration(seconds: 10));
    await tester.pump();

    expect(player.disposeCalls, 1);
    expect(player.hasPositionListener, isFalse);
    expect(player.hasPlaybackListener, isFalse);
    expect(tester.takeException(), isNull);
  });
}

void _expectDisabledControls(WidgetTester tester) {
  expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
  expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
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
  Brightness brightness = Brightness.light,
}) async {
  final resolvedPlayer = player ?? _FakePlayer();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(brightness, AppAccent.blue),
      supportedLocales: const [Locale('en'), Locale('de')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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

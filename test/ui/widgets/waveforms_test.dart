import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/ui/widgets/waveforms.dart';

import 'widget_test_helpers.dart';

void main() {
  _registerPlayerWaveTests();
  _registerRecordWaveTests();
}

void _registerPlayerWaveTests() {
  testWidgets('PlayerWave seeks by tap position', (tester) async {
    double? seek;
    await tester.pumpWidget(
      themed(
        SizedBox(
          width: 200,
          child: Row(
            children: [
              PlayerWave(progress: 0.5, onSeek: (value) => seek = value),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(GestureDetector), findsOneWidget);
    final wave = find.byType(GestureDetector);
    final topLeft = tester.getTopLeft(wave);
    final size = tester.getSize(wave);
    await tester.tapAt(topLeft + Offset(size.width * 0.75, size.height / 2));
    expect(seek, closeTo(0.75, 0.01));
  });

  testWidgets('PlayerWave clamps taps outside waveform to valid progress', (
    tester,
  ) async {
    double? seek;
    await tester.pumpWidget(
      themed(
        SizedBox(
          width: 100,
          child: Row(
            children: [
              PlayerWave(progress: 0, onSeek: (value) => seek = value),
            ],
          ),
        ),
      ),
    );

    final wave = find.byType(GestureDetector);
    final topLeft = tester.getTopLeft(wave);
    final size = tester.getSize(wave);
    await tester.tapAt(topLeft + Offset(0, size.height / 2));
    expect(seek, closeTo(0, 0.01));
  });
}

void _registerRecordWaveTests() {
  testWidgets('RecordWave respects reduced-motion settings', (tester) async {
    await tester.pumpWidget(
      themed(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: RecordWave(levels: [0.2, 0.8, 0.4], paused: false),
        ),
      ),
    );

    await tester.pumpWidget(
      themed(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: RecordWave(levels: [0.7, 0.3, 0.9], paused: false),
        ),
      ),
    );
    final frames = await tester.pumpAndSettle();

    expect(find.byType(RecordWave), findsOneWidget);
    expect(frames, lessThanOrEqualTo(3));
  });
}

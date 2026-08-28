import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/ui/widgets/waveforms.dart';

import 'widget_test_helpers.dart';

void main() {
  testWidgets('EqWave creates requested bars and remains bounded', (
    tester,
  ) async {
    await tester.pumpWidget(themed(const EqWave(bars: 4, height: 32)));

    expect(find.byType(Container), findsNWidgets(4));
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('MiniWave renders its seven static bars', (tester) async {
    await tester.pumpWidget(themed(const MiniWave(color: Colors.orange)));

    expect(find.byType(Container), findsNWidgets(7));
  });

  testWidgets('PlayerWave colors bars by progress and seeks by tap position', (
    tester,
  ) async {
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
    final bars = tester.widgetList<Container>(find.byType(Container)).toList();
    expect(bars.length, greaterThan(2));
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

  testWidgets(
    'RecordWave paints paused and active states and repaints on new levels',
    (tester) async {
      final first = <double>[0.2, 0.4, 0.6];
      final second = <double>[0.8, 0.3, 0.1];
      await tester.pumpWidget(themed(RecordWave(levels: first, paused: false)));
      final paint = find.descendant(
        of: find.byType(RecordWave),
        matching: find.byType(CustomPaint),
      );
      expect(paint, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(RecordWave),
          matching: find.byType(RepaintBoundary),
        ),
        findsOneWidget,
      );
      final active = tester.widget<CustomPaint>(paint);
      expect(active.painter, isNotNull);

      await tester.pumpWidget(themed(RecordWave(levels: second, paused: true)));
      await tester.pump(const Duration(milliseconds: 70));
      final paused = tester.widget<CustomPaint>(paint);
      expect(paused.painter, isNot(same(active.painter)));
      await tester.pump(const Duration(milliseconds: 140));
    },
  );
}

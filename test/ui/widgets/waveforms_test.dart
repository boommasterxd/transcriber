import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/ui/widgets/waveforms.dart';

import 'widget_test_helpers.dart';

void main() {
  _registerPlayerWaveTests();
  _registerRecordWaveTests();
}

void _registerPlayerWaveTests() {
  testWidgets('PlayerWave seeks by tap position and reaches both ends', (
    tester,
  ) async {
    final seeks = <double>[];
    await tester.pumpWidget(
      themed(
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: PlayerWave(
                progress: 0.5,
                label: 'Playback position',
                semanticFormatterCallback: (value) => value.toString(),
                onSeek: seeks.add,
              ),
            ),
          ),
        ),
      ),
    );

    final slider = tester.getRect(find.byType(Slider)).deflate(10);
    await tester.tapAt(slider.centerLeft);
    await tester.tapAt(slider.center + Offset(slider.width / 4, 0));
    await tester.tapAt(slider.centerRight - const Offset(0.01, 0));
    expect(seeks, [0, closeTo(0.75, 0.01), closeTo(1, 0.01)]);
  });

  testWidgets('EqWave stays still when reduced motion is active', (
    tester,
  ) async {
    final dispatcher = tester.platformDispatcher;
    addTearDown(dispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(themed(const EqWave()));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    dispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    await tester.pump();
    expect(find.byType(EqWave), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
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

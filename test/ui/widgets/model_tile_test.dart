import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/ui/widgets/model_tile.dart';

import 'widget_test_helpers.dart';

void main() {
  _registerModelTileTests();
  _registerSelectionTest();
  _registerDownloadTest();
  _registerProgressTest();
}

void _registerModelTileTests() {
  testWidgets('ModelTile displays content, leading widget, badge and taps', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      themed(
        ModelTile(
          title: 'Whisper Base',
          subtitle: '74 MB',
          leading: const Icon(Icons.mic),
          leadingColor: Colors.red,
          badge: const Text('Recommended'),
          trailing: const Icon(Icons.check),
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Whisper Base'), findsOneWidget);
    expect(find.text('74 MB'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);
    await tester.tap(find.text('Whisper Base'));
    expect(tapped, isTrue);
  });
}

void _registerSelectionTest() {
  testWidgets('ModelTile omits bottom border for last item', (tester) async {
    await tester.pumpWidget(
      themed(
        const ModelTile(
          title: 'Model',
          subtitle: 'Local',
          isLast: true,
          trailing: SizedBox.shrink(),
        ),
      ),
    );

    final tile = tester.widget<Container>(find.byType(Container).first);
    expect((tile.decoration! as BoxDecoration).border, isNull);
  });
}

void _registerDownloadTest() {
  testWidgets('SelectionIndicator renders distinct selected states', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        const Row(
          children: [
            SelectionIndicator(selected: false),
            SelectionIndicator(selected: true),
          ],
        ),
      ),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
    final containers = tester.widgetList<Container>(find.byType(Container));
    expect(containers.length, greaterThanOrEqualTo(2));
  });
}

void _registerProgressTest() {
  testWidgets('DownloadChip displays download action and invokes callback', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      themed(DownloadChip(label: 'Get', onTap: () => tapped = true)),
    );

    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    expect(find.text('Get'), findsOneWidget);
    await tester.tap(find.text('Get'));
    expect(tapped, isTrue);
  });

  testWidgets('ProgressRing displays a percentage and handles zero progress', (
    tester,
  ) async {
    await tester.pumpWidget(themed(const ProgressRing(progress: 0)));
    expect(find.text('0'), findsOneWidget);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      isNull,
    );

    await tester.pumpWidget(themed(const ProgressRing(progress: 0.625)));
    expect(find.text('63'), findsOneWidget);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      0.625,
    );
  });
}

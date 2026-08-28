import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/ui/widgets/surfaces.dart';

import 'widget_test_helpers.dart';

void main() {
  testWidgets('SurfaceCard applies padding, radius and optional clipping', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        const SurfaceCard(
          radius: 12,
          clip: true,
          padding: EdgeInsets.all(8),
          child: Text('Card'),
        ),
      ),
    );

    final card = tester.widget<Container>(find.byType(Container).first);
    expect(card.padding, const EdgeInsets.all(8));
    expect(card.clipBehavior, Clip.antiAlias);
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(12));
    expect(find.text('Card'), findsOneWidget);
  });

  testWidgets('SectionLabel uppercases text and uses supplied padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(const SectionLabel('audio files', padding: EdgeInsets.all(3))),
    );

    expect(find.text('AUDIO FILES'), findsOneWidget);
    final padding = tester.widget<Padding>(find.byType(Padding));
    expect(padding.padding, const EdgeInsets.all(3));
  });

  testWidgets('FadeEdges only shows bottom fade when content overflows', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        Scaffold(
          body: SizedBox(
            height: 100,
            child: FadeEdges(
              builder: (context, controller) => ListView.builder(
                controller: controller,
                itemCount: 10,
                itemBuilder: (context, index) =>
                    SizedBox(height: 40, child: Text('Item $index')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final opacities = tester
        .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
        .toList();
    expect(opacities, hasLength(2));
    expect(opacities[0].opacity, 0);
    expect(opacities[1].opacity, 1);

    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pump(const Duration(milliseconds: 200));
    final scrolled = tester
        .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
        .toList();
    expect(scrolled[0].opacity, 1);
    expect(scrolled[1].opacity, 1);

    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pump(const Duration(milliseconds: 200));
    final atEnd = tester
        .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
        .toList();
    expect(atEnd[1].opacity, 0);
  });
}

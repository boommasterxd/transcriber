import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/ui/widgets/surfaces.dart';

import 'widget_test_helpers.dart';

void main() {
  testWidgets('SectionLabel displays uppercase section text', (tester) async {
    await tester.pumpWidget(themed(const SectionLabel('audio files')));

    expect(find.text('AUDIO FILES'), findsOneWidget);
  });
}

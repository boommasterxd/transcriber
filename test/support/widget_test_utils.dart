import 'package:flutter_test/flutter_test.dart';

extension BoundedWidgetPumping on WidgetTester {
  Future<void> pumpUntilSettled() async {
    await pumpAndSettle(
      const Duration(milliseconds: 16),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
  }
}

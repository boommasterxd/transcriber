import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/remote/remote_api_client.dart';

void main() {
  group('RemoteModelInfo.display', () {
    test('uses a non-empty provider label', () {
      const model = RemoteModelInfo(id: 'model-id', label: 'Friendly name');
      expect(model.display, 'Friendly name');
    });

    test('falls back to the identifier for null and empty labels', () {
      expect(const RemoteModelInfo(id: 'one').display, 'one');
      expect(const RemoteModelInfo(id: 'two', label: '').display, 'two');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:transcriber/services/app_version_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cases = [
    ('2.4.1', '17', '2.4.1+17'),
    (' 3.0.0 ', ' 42 ', '3.0.0+42'),
    ('1.0.0', ' ', '1.0.0'),
  ];
  for (final (version, build, expected) in cases) {
    test('reads installed version $expected', () async {
      _packageVersion(version, build);
      expect(await const AppVersionService().load(), expected);
    });
  }
  test('rejects missing package version instead of inventing one', () async {
    _packageVersion(' ', '7');
    await expectLater(
      const AppVersionService().load(),
      throwsA(isA<FormatException>()),
    );
  });
}

void _packageVersion(String version, String build) {
  PackageInfo.setMockInitialValues(
    appName: 'Transcriber',
    packageName: 'test.transcriber',
    version: version,
    buildNumber: build,
    buildSignature: '',
  );
}

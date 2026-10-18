import 'package:flutter_test/flutter_test.dart';

import 'git_fixture.dart';

const _providerAssets = [
  'assets/images/providers/openai.png',
  'assets/images/providers/openai_dark.png',
  'assets/images/providers/gemini.png',
];

void main() {
  late GitFixture fixture;
  setUp(() async {
    fixture = await GitFixture.create();
    await fixture.write({
      for (final asset in _providerAssets) asset: 'original image',
      'lib/ui/widgets/provider_logo.dart': fixtureSource('logo', 1),
      'lib/logo_consumer.dart': "export 'ui/widgets/provider_logo.dart';\n",
      'test/logo_test.dart': "import '../lib/logo_consumer.dart';\n",
    });
    fixture.base = await fixture.commit();
  });
  tearDown(() => fixture.dispose());

  for (final asset in _providerAssets) {
    test('selects transitive widget consumers for $asset', () async {
      final plan = await fixture.plan({asset: 'changed image'});
      expect(plan['mode'], 'selected');
      expect(plan['tests'], ['test/logo_test.dart']);
      expect(plan['affectedSources'], isEmpty);
    });
  }

  test(
    'combines asset and source consumers with direct source coverage',
    () async {
      final plan = await fixture.plan({
        _providerAssets.first: 'changed image',
        'lib/first.dart': fixtureSource('first', 2),
      });
      expect(plan['mode'], 'selected');
      expect(plan['tests'], ['test/first_test.dart', 'test/logo_test.dart']);
      expect(plan['affectedSources'], ['lib/first.dart']);
    },
  );

  test('falls back when a known asset is deleted', () async {
    await fixture.remove(_providerAssets.first);
    final plan = await fixture.plan({});
    expect(plan['mode'], 'full');
  });

  test('falls back when a known asset is renamed to an unknown path', () async {
    await fixture.git([
      'mv',
      _providerAssets.first,
      'assets/images/providers/replacement.png',
    ]);
    final plan = await fixture.plan({});
    expect(plan['mode'], 'full');
  });

  test('falls back for an unknown asset', () async {
    final plan = await fixture.plan({'assets/unknown.png': 'new image'});
    expect(plan['mode'], 'full');
  });

  test('falls back for a missing asset owner in a mixed change', () async {
    await fixture.remove('lib/ui/widgets/provider_logo.dart');
    await fixture.remove('lib/logo_consumer.dart');
    await fixture.remove('test/logo_test.dart');
    fixture.base = await fixture.commit();
    final plan = await fixture.plan({
      _providerAssets.first: 'changed image',
      'lib/first.dart': fixtureSource('first', 3),
    });
    expect(plan['mode'], 'full');
  });

  test('falls back for an untested asset owner in a mixed change', () async {
    await fixture.remove('test/logo_test.dart');
    fixture.base = await fixture.commit();
    final plan = await fixture.plan({
      _providerAssets.first: 'changed image',
      'lib/first.dart': fixtureSource('first', 4),
    });
    expect(plan['mode'], 'full');
  });
}

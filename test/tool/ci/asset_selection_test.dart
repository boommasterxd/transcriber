import 'package:test/test.dart';

import 'git_fixture.dart';

void main() {
  test(
    'selects consumers of a mapped asset and falls back on removal',
    () async {
      final fixture = await GitFixture.create();
      addTearDown(fixture.dispose);
      const asset = 'assets/images/providers/openai.png';
      await fixture.write({
        asset: 'synthetic image',
        'lib/ui/widgets/provider_logo.dart': fixtureSource('logo', 1),
        'test/logo_test.dart':
            "import '../lib/ui/widgets/provider_logo.dart';\n",
      });
      fixture.base = await fixture.commit();

      final edit = await fixture.plan({asset: 'changed synthetic image'});
      expect(edit['mode'], 'selected');
      expect(edit['tests'], ['test/logo_test.dart']);

      fixture.base = edit['head']! as String;
      await fixture.remove(asset);
      expect((await fixture.plan({}))['mode'], 'full');
    },
  );
}

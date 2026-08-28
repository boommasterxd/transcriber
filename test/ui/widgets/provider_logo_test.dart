import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/ui/widgets/provider_logo.dart';

import 'widget_test_helpers.dart';

void main() {
  for (final provider in RemoteProviderId.values) {
    testWidgets('${provider.name} uses its bundled provider asset', (
      tester,
    ) async {
      await tester.pumpWidget(themed(ProviderLogo(provider: provider)));

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<AssetImage>());
      expect(
        (image.image as AssetImage).assetName,
        'assets/images/providers/${provider == RemoteProviderId.openai ? 'openai' : 'gemini'}.png',
      );
    });
  }
}

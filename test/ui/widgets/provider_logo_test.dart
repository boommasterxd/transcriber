import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/ui/widgets/provider_logo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _testThemeAssets();
  _testFramelessLayout();
  _testAssetTransparency();
}

void _testThemeAssets() {
  testWidgets('uses the black OpenAI mark in light mode', (tester) async {
    await tester.pumpWidget(
      _themed(
        const ProviderLogo(provider: RemoteProviderId.openai),
        Brightness.light,
      ),
    );

    expect(_assetName(tester), 'assets/images/providers/openai.png');
  });

  testWidgets('uses the white OpenAI mark in dark mode', (tester) async {
    await tester.pumpWidget(
      _themed(
        const ProviderLogo(provider: RemoteProviderId.openai),
        Brightness.dark,
      ),
    );

    expect(_assetName(tester), 'assets/images/providers/openai_dark.png');
  });

  for (final brightness in Brightness.values) {
    testWidgets('uses the Gemini mark in ${brightness.name} mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        _themed(
          const ProviderLogo(provider: RemoteProviderId.google),
          brightness,
        ),
      );

      expect(_assetName(tester), 'assets/images/providers/gemini.png');
    });
  }
}

void _testFramelessLayout() {
  testWidgets('renders the mark at the requested size without a frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      _themed(
        const ProviderLogo(provider: RemoteProviderId.google, size: 34),
        Brightness.light,
      ),
    );

    final box = tester.widget<SizedBox>(
      find.descendant(
        of: find.byType(ProviderLogo),
        matching: find.byType(SizedBox),
      ),
    );
    expect(box.width, 34);
    expect(box.height, 34);
    expect(
      find.descendant(
        of: find.byType(ProviderLogo),
        matching: find.byType(Container),
      ),
      findsNothing,
    );
  });
}

void _testAssetTransparency() {
  for (final assetPath in <String>[
    'assets/images/providers/openai.png',
    'assets/images/providers/openai_dark.png',
    'assets/images/providers/gemini.png',
  ]) {
    test('$assetPath has a transparent background', () async {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      final pixels = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      expect(pixels, isNotNull);
      expect(_cornerAlphaValues(frame.image, pixels!), everyElement(0));
      expect(_hasVisiblePixel(pixels), isTrue);

      frame.image.dispose();
      codec.dispose();
    });
  }
}

Widget _themed(Widget child, Brightness brightness) => MaterialApp(
  theme: ThemeData(brightness: brightness),
  home: child,
);

String _assetName(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image));
  expect(image.image, isA<AssetImage>());
  return (image.image as AssetImage).assetName;
}

bool _hasVisiblePixel(ByteData pixels) {
  for (
    var alphaOffset = 3;
    alphaOffset < pixels.lengthInBytes;
    alphaOffset += 4
  ) {
    if (pixels.getUint8(alphaOffset) > 0) {
      return true;
    }
  }
  return false;
}

List<int> _cornerAlphaValues(ui.Image image, ByteData pixels) {
  final rowLength = image.width * 4;
  final lastRowStart = (image.height - 1) * rowLength;
  return <int>[
    pixels.getUint8(3),
    pixels.getUint8(rowLength - 1),
    pixels.getUint8(lastRowStart + 3),
    pixels.getUint8(lastRowStart + rowLength - 1),
  ];
}

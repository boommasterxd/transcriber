import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../data/models/remote_provider.dart';

/// Compact local brand mark for a supported cloud provider.
class ProviderLogo extends StatelessWidget {
  const ProviderLogo({super.key, required this.provider, this.size = 38});

  final RemoteProviderId provider;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.29),
          border: Border.all(color: palette.line2),
        ),
        child: Image.asset(
          _assetPath(provider),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  static String _assetPath(RemoteProviderId provider) {
    return provider == RemoteProviderId.openai
        ? 'assets/images/providers/openai.png'
        : 'assets/images/providers/gemini.png';
  }
}

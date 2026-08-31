import 'package:flutter/material.dart';

import '../../data/models/remote_provider.dart';

/// Compact local brand mark for a supported cloud provider.
class ProviderLogo extends StatelessWidget {
  const ProviderLogo({super.key, required this.provider, this.size = 38});

  final RemoteProviderId provider;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          _assetPath(provider, Theme.of(context).brightness),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  static String _assetPath(RemoteProviderId provider, Brightness brightness) {
    if (provider == RemoteProviderId.google) {
      return 'assets/images/providers/gemini.png';
    }
    return brightness == Brightness.dark
        ? 'assets/images/providers/openai_dark.png'
        : 'assets/images/providers/openai.png';
  }
}

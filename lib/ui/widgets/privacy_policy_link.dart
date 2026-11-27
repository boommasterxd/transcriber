import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_palette.dart';
import '../../state/settings_controller.dart';

/// Opens the app's policy in an external browser only after user activation.
class PrivacyPolicyLink extends ConsumerWidget {
  const PrivacyPolicyLink({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final fileName = strings.isDe
        ? 'privacy-policy.md'
        : 'privacy-policy-en.md';
    final policyUri = Uri.https(
      'github.com',
      '/boommasterxd/transcriber/blob/main/docs/$fileName',
    );
    return MergeSemantics(
      child: Semantics(
        link: true,
        linkUrl: policyUri,
        child: TextButton(
          isSemanticButton: false,
          onPressed: () =>
              _openPolicy(context, policyUri, strings.openPrivacyPolicyFailed),
          style: TextButton.styleFrom(
            foregroundColor: context.palette.accentDeep,
            minimumSize: const Size(48, 48),
          ),
          child: Text(
            strings.privacyPolicy,
            style: const TextStyle(decoration: TextDecoration.underline),
          ),
        ),
      ),
    );
  }

  Future<void> _openPolicy(
    BuildContext context,
    Uri policyUri,
    String failureMessage,
  ) async {
    try {
      if (await launchUrl(policyUri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } on PlatformException {
      // Show the same recovery message when Android cannot open a browser.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(failureMessage)));
  }
}

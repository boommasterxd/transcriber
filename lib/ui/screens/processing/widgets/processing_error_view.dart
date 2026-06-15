import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../widgets/buttons.dart';

/// Error state shown when processing fails (network, missing model, API error).
class ProcessingErrorView extends StatelessWidget {
  const ProcessingErrorView({
    super.key,
    required this.error,
    required this.strings,
    required this.isModelMissing,
    required this.onRetry,
    required this.onClose,
    required this.onOpenSettings,
  });

  final Object error;
  final AppStrings strings;
  final bool isModelMissing;
  final VoidCallback onRetry;
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(color: palette.coralSoft, borderRadius: BorderRadius.circular(24)),
                child: Icon(Icons.error_outline_rounded, color: palette.coralInk, size: 34),
              ),
              const SizedBox(height: 20),
              Text(
                isModelMissing ? strings.modelMissingTitle : strings.errorTitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: palette.ink),
              ),
              const SizedBox(height: 10),
              Text(
                isModelMissing ? strings.modelMissingBody : error.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.5, color: palette.muted),
              ),
              const SizedBox(height: 28),
              if (isModelMissing)
                PillButton(label: strings.goToSettings, icon: Icons.settings_outlined, onTap: onOpenSettings)
              else
                PillButton(label: strings.retry, icon: Icons.refresh_rounded, onTap: onRetry),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: onClose,
                child: Text(
                  strings.dismiss,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: palette.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

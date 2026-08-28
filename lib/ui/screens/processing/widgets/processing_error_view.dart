import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../services/service_exceptions.dart';
import '../../../widgets/buttons.dart';

enum ProcessingErrorLayout { screen, sheet }

class ProcessingErrorPresentation {
  const ProcessingErrorPresentation({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.dismissLabel,
    required this.opensSettings,
  });

  factory ProcessingErrorPresentation.resolve(
    Object error,
    AppStrings strings,
  ) {
    final opensSettings = error is MissingApiKeyException;
    return ProcessingErrorPresentation(
      title: opensSettings ? strings.keyMissing : strings.errorTitle,
      body: opensSettings ? strings.connectFirst : error.toString(),
      actionLabel: opensSettings ? strings.goToSettings : strings.retry,
      dismissLabel: strings.dismiss,
      opensSettings: opensSettings,
    );
  }

  final String title;
  final String body;
  final String actionLabel;
  final String dismissLabel;
  final bool opensSettings;
}

class ProcessingErrorActions {
  const ProcessingErrorActions({
    required this.onRetry,
    required this.onClose,
    required this.onOpenSettings,
  });

  final VoidCallback onRetry;
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;

  VoidCallback actionFor(ProcessingErrorPresentation presentation) {
    return presentation.opensSettings ? onOpenSettings : onRetry;
  }
}

/// Full-screen wrapper for a failed processing run.
class ProcessingErrorView extends StatelessWidget {
  const ProcessingErrorView({
    super.key,
    required this.presentation,
    required this.actions,
  });

  final ProcessingErrorPresentation presentation;
  final ProcessingErrorActions actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 34),
            child: ProcessingErrorContent(
              presentation: presentation,
              actions: actions,
              layout: ProcessingErrorLayout.screen,
            ),
          ),
        ),
      ),
    );
  }
}

class ProcessingErrorContent extends StatelessWidget {
  const ProcessingErrorContent({
    super.key,
    required this.presentation,
    required this.actions,
    required this.layout,
  });

  final ProcessingErrorPresentation presentation;
  final ProcessingErrorActions actions;
  final ProcessingErrorLayout layout;

  bool get _isScreen => layout == ProcessingErrorLayout.screen;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ErrorIcon(size: _isScreen ? 76 : 72),
        SizedBox(height: _isScreen ? 20 : 16),
        _ErrorMessage(presentation: presentation, layout: layout),
        SizedBox(height: _isScreen ? 28 : 22),
        PillButton(
          label: presentation.actionLabel,
          icon: _isScreen ? _actionIcon : null,
          height: _isScreen ? 56 : 52,
          onTap: actions.actionFor(presentation),
        ),
        SizedBox(height: _isScreen ? 14 : 6),
        _DismissAction(
          label: presentation.dismissLabel,
          onTap: actions.onClose,
          layout: layout,
        ),
      ],
    );
  }

  IconData get _actionIcon => presentation.opensSettings
      ? Icons.settings_outlined
      : Icons.refresh_rounded;
}

class _DismissAction extends StatelessWidget {
  const _DismissAction({
    required this.label,
    required this.onTap,
    required this.layout,
  });

  final String label;
  final VoidCallback onTap;
  final ProcessingErrorLayout layout;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: layout == ProcessingErrorLayout.screen ? 14.5 : null,
      fontWeight: FontWeight.w600,
      color: context.palette.muted,
    );
    if (layout == ProcessingErrorLayout.sheet) {
      return TextButton(
        onPressed: onTap,
        child: Text(label, style: style),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Text(label, style: style),
    );
  }
}

class _ErrorIcon extends StatelessWidget {
  const _ErrorIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.coralSoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(
        Icons.error_outline_rounded,
        color: palette.coralInk,
        size: size == 76 ? 34 : 32,
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.presentation, required this.layout});

  final ProcessingErrorPresentation presentation;
  final ProcessingErrorLayout layout;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isScreen = layout == ProcessingErrorLayout.screen;
    return Column(
      children: [
        Text(
          presentation.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isScreen ? 20 : 18,
            fontWeight: FontWeight.w800,
            color: palette.ink,
          ),
        ),
        SizedBox(height: isScreen ? 10 : 8),
        if (isScreen && !presentation.opensSettings)
          _ScrollableErrorBody(body: presentation.body)
        else
          Text(
            presentation.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: isScreen ? 1.5 : 1.45,
              color: palette.muted,
            ),
          ),
      ],
    );
  }
}

class _ScrollableErrorBody extends StatelessWidget {
  const _ScrollableErrorBody({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.chip,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            body,
            style: TextStyle(fontSize: 13, height: 1.45, color: palette.body),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../widgets/surfaces.dart';
import 'onboarding_status_row.dart';

/// Requests microphone access from the app's activity for keyboard dictation.
class KeyboardMicrophoneStep extends StatefulWidget {
  const KeyboardMicrophoneStep({required this.strings, super.key});

  final AppStrings strings;

  @override
  State<KeyboardMicrophoneStep> createState() => _KeyboardMicrophoneStepState();
}

class _KeyboardMicrophoneStepState extends State<KeyboardMicrophoneStep>
    with WidgetsBindingObserver {
  PermissionStatus? _permission;
  bool _requesting = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (_requesting) return;
    final revision = ++_revision;
    final permission = await _readStatus();
    if (!mounted || revision != _revision) return;
    // Android reports permanent denial only when requesting permission.
    if (permission.isDenied && _permission?.isPermanentlyDenied == true) return;
    setState(() => _permission = permission);
  }

  Future<PermissionStatus> _readStatus() async {
    try {
      return await Permission.microphone.status;
    } on PlatformException {
      return PermissionStatus.denied;
    }
  }

  Future<void> _request() async {
    if (_requesting) return;
    _revision++;
    setState(() => _requesting = true);
    try {
      final permission = await Permission.microphone.request();
      if (mounted) setState(() => _permission = permission);
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(widget.strings.errorTitle)));
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permission = _permission;
    if (permission == null) return const SizedBox.shrink();
    final strings = widget.strings;
    final subtitle = switch (permission) {
      PermissionStatus.granted => strings.keyboardMicGranted,
      PermissionStatus.permanentlyDenied => strings.keyboardMicMissing,
      _ => strings.keyboardMicDenied,
    };
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: OnboardingStatusRow(
              icon: Icons.mic_none_rounded,
              title: strings.keyboardMicTitle,
              subtitle: subtitle,
              trailing: permission.isGranted
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: context.palette.mint,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          if (!permission.isGranted) ...[
            const SizedBox(height: 10),
            FilledButton.tonal(
              onPressed: _requesting
                  ? null
                  : permission.isPermanentlyDenied
                  ? openAppSettings
                  : _request,
              child: Text(
                permission.isPermanentlyDenied
                    ? strings.micPermissionSettings
                    : strings.keyboardMicEnable,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

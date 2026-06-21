import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../state/providers.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/surfaces.dart';

/// Onboarding step that explains, in plain language, why the app asks for the
/// microphone and notification permissions. Tapping "Enable" triggers the real
/// system permission dialogs right here, so the user never has to hunt through
/// settings later.
class OnboardingPermissionsStep extends ConsumerStatefulWidget {
  const OnboardingPermissionsStep({super.key});

  @override
  ConsumerState<OnboardingPermissionsStep> createState() => _OnboardingPermissionsStepState();
}

class _OnboardingPermissionsStepState extends ConsumerState<OnboardingPermissionsStep>
    with AutomaticKeepAliveClientMixin {
  bool _micGranted = false;
  bool _notifGranted = false;
  bool _requesting = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _request() async {
    if (_requesting) return;
    setState(() => _requesting = true);

    // Microphone: the record package surfaces the OS dialog on demand and
    // returns whether access ended up granted.
    var mic = _micGranted;
    try {
      mic = await ref.read(audioRecorderProvider).hasPermission();
    } catch (_) {}

    // Notifications: needed so the background processing service can show its
    // progress notification (Android 13+ prompts for this).
    var notif = _notifGranted;
    try {
      final res = await FlutterForegroundTask.requestNotificationPermission();
      notif = res == NotificationPermission.granted;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _micGranted = mic;
      _notifGranted = notif;
      _requesting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final allGranted = _micGranted && _notifGranted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PermCard(
          icon: Icons.mic_none_rounded,
          title: t.obPermMicT,
          subtitle: t.obPermMicS,
          granted: _micGranted,
        ),
        const SizedBox(height: 12),
        _PermCard(
          icon: Icons.notifications_none_rounded,
          title: t.obPermNotifT,
          subtitle: t.obPermNotifS,
          granted: _notifGranted,
        ),
        const SizedBox(height: 20),
        if (allGranted)
          Container(
            height: 52,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: palette.mint),
                const SizedBox(width: 8),
                Text(
                  t.obPermGranted,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.mint),
                ),
              ],
            ),
          )
        else
          PillButton(
            label: t.obPermEnable,
            icon: _requesting ? null : Icons.lock_open_rounded,
            height: 52,
            onTap: _requesting ? () {} : _request,
          ),
      ],
    );
  }
}

class _PermCard extends StatelessWidget {
  const _PermCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: palette.accentSoft2, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 18, color: palette.accent),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.ink)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12.5, height: 1.4, color: palette.muted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            granted ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 22,
            color: granted ? palette.mint : palette.faint,
          ),
        ],
      ),
    );
  }
}

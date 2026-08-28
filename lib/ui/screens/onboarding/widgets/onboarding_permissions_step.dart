import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/surfaces.dart';
import 'onboarding_status_row.dart';

/// True when microphone access required for in-app recording is granted.
class OnboardingPermissionsReady extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final onboardingPermissionsReadyProvider =
    NotifierProvider<OnboardingPermissionsReady, bool>(
      OnboardingPermissionsReady.new,
    );

/// Onboarding step that explains, in plain language, why the app needs the
/// microphone permission and requests it inline. Handles
/// the user declining (explains it's required) and a permanent denial (points
/// them to the system settings and opens that page for them).
class OnboardingPermissionsStep extends ConsumerStatefulWidget {
  const OnboardingPermissionsStep({super.key});

  @override
  ConsumerState<OnboardingPermissionsStep> createState() =>
      _OnboardingPermissionsStepState();
}

class _OnboardingPermissionsStepState
    extends ConsumerState<OnboardingPermissionsStep>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  PermissionStatus? _mic;
  bool _busy = false;
  bool _attempted = false;

  @override
  bool get wantKeepAlive => true;

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
    // Returning from the system settings page: re-read the (possibly changed)
    // status so the UI and the wizard gate update right away.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  bool get _micOk => _mic?.isGranted ?? false;
  bool get _allOk => _micOk;

  // Permanently denied (Android's "don't ask again", reached after a couple of
  // refusals): the system dialog won't show anymore, so we must send the user
  // to the app settings instead.
  bool get _blocked => !_micOk && (_mic?.isPermanentlyDenied ?? false);

  void _syncGate() {
    ref.read(onboardingPermissionsReadyProvider.notifier).set(_allOk);
  }

  Future<void> _refresh() async {
    final mic = await Permission.microphone.status;
    if (!mounted) return;
    setState(() {
      _mic = mic;
    });
    _syncGate();
  }

  Future<void> _request() async {
    setState(() {
      _busy = true;
      _attempted = true;
    });
    var mic = _mic;
    if (!(mic?.isGranted ?? false)) mic = await Permission.microphone.request();
    if (!mounted) return;
    setState(() {
      _mic = mic;
      _busy = false;
    });
    _syncGate();
  }

  // The resume callback re-reads the status when the user comes back.
  Future<void> _openSettings() => openAppSettings();

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin
    final palette = context.palette;
    final t = ref.watch(stringsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PermCard(
          icon: Icons.mic_none_rounded,
          title: t.obPermMicT,
          subtitle: t.obPermMicS,
          granted: _micOk,
        ),
        const SizedBox(height: 16),
        if (_allOk)
          _GrantedRow(label: t.obPermGranted)
        else if (_blocked) ...[
          _Note(text: t.obPermBlockedNote),
          const SizedBox(height: 12),
          PillButton(
            label: t.obPermOpenSettings,
            icon: Icons.settings_outlined,
            height: 52,
            onTap: _openSettings,
          ),
        ] else ...[
          if (_attempted) ...[
            _Note(text: t.obPermDeniedNote),
            const SizedBox(height: 12),
          ],
          PillButton(
            label: t.obPermEnable,
            icon: _busy ? null : Icons.lock_open_rounded,
            height: 52,
            onTap: _busy ? () {} : _request,
          ),
        ],
        if (!_allOk) ...[
          const SizedBox(height: 12),
          Text(
            t.obPermRequiredHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.4, color: palette.muted),
          ),
        ],
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = palette.coralInk;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: palette.coralSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrantedRow extends StatelessWidget {
  const _GrantedRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 52,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, size: 18, color: palette.mint),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: palette.mint,
            ),
          ),
        ],
      ),
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
      child: OnboardingStatusRow(
        icon: icon,
        title: title,
        subtitle: subtitle,
        trailing: Icon(
          granted ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 22,
          color: granted ? palette.mint : palette.faint,
        ),
      ),
    );
  }
}

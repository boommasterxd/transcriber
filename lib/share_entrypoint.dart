import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_bootstrap.dart';
import 'ui/screens/share/share_overlay_sheet.dart';
import 'ui/screens/share/widgets/transcriber_app_shell.dart';

/// Channel shared with the native [ShareActivity] (translucent): hands over the
/// cached path of the shared audio and lets us finish the activity (returning
/// the user to the app they shared from).
const _channel = MethodChannel('app/share');

/// Bootstraps and renders the share overlay over a transparent window. Called
/// from `shareMain` in main.dart (which is the actual Dart entrypoint).
Future<void> runShareEntrypoint({
  Future<AppBootstrapData> Function()? loadBootstrap,
}) => runBootstrappedApp(app: const _ShareApp(), loadBootstrap: loadBootstrap);

class _ShareApp extends StatelessWidget {
  const _ShareApp();

  @override
  Widget build(BuildContext context) {
    return const TranscriberAppShell(transparent: true, home: _ShareHost());
  }
}

class _ShareHost extends ConsumerStatefulWidget {
  const _ShareHost();

  @override
  ConsumerState<_ShareHost> createState() => _ShareHostState();
}

class _ShareHostState extends ConsumerState<_ShareHost> {
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  /// Loads the shared path, then presents the overlay as a real modal bottom
  /// sheet, so it slides up from the bottom and supports drag-to-dismiss, just
  /// like the in-app overlay. Finishing the activity returns to the source app.
  Future<void> _open() async {
    if (_opened) return;
    _opened = true;
    String? path;
    try {
      path = await _channel.invokeMethod<String>('getInitialSharedPath');
    } catch (_) {
      path = null;
    }
    if (!mounted) return;
    if (path == null || path.trim().isEmpty) {
      _finish();
      return;
    }
    await presentShareSheet(
      context: context,
      audioPath: path,
      fileName: path.split('/').last,
    );
    // Sheet dismissed (saved, closed, dragged or scrim-tapped) → close the
    // translucent activity and return to the app the audio was shared from.
    _finish();
  }

  void _finish() => _channel.invokeMethod('finish');

  @override
  Widget build(BuildContext context) {
    // The sheet itself is presented as a modal route above; the page is just a
    // transparent surface so the source app shows through behind the scrim.
    return const Scaffold(backgroundColor: Colors.transparent);
  }
}

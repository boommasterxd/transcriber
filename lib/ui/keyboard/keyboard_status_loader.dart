import 'package:flutter/material.dart';

import '../../services/dictation/dictation_platform.dart';

typedef KeyboardStatusActions = ({
  VoidCallback refresh,
  Future<void> Function() enable,
  Future<void> Function() choose,
});

typedef KeyboardStatusContentBuilder =
    Widget Function(
      BuildContext context,
      KeyboardStatus? status,
      KeyboardStatusActions actions,
    );

/// Keeps Android input-method status current across system settings round trips.
class KeyboardStatusLoader extends StatefulWidget {
  const KeyboardStatusLoader({
    super.key,
    required this.platform,
    required this.builder,
  });

  final KeyboardSettingsPlatform platform;
  final KeyboardStatusContentBuilder builder;

  @override
  State<KeyboardStatusLoader> createState() => _KeyboardStatusLoaderState();
}

class _KeyboardStatusLoaderState extends State<KeyboardStatusLoader>
    with WidgetsBindingObserver {
  late Future<KeyboardStatus> _status = widget.platform.status();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    if (mounted) {
      setState(() {
        _status = widget.platform.status();
      });
    }
  }

  Future<void> _enable() async {
    await widget.platform.openInputMethodSettings();
    _refresh();
  }

  Future<void> _choose() async {
    await widget.platform.showInputMethodPicker();
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<KeyboardStatus>(
    future: _status,
    builder: (context, snapshot) => widget.builder(context, snapshot.data, (
      refresh: _refresh,
      enable: _enable,
      choose: _choose,
    )),
  );
}

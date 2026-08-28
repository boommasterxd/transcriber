import 'package:flutter/material.dart';

/// App-wide messenger key so any layer can show a toast/snackbar without a
/// local BuildContext (e.g. model download/delete confirmations).
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Shows a short floating toast. No-op if the messenger isn't mounted.
void showAppToast(String message, {bool isError = false}) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: Duration(seconds: isError ? 4 : 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

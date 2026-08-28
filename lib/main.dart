import 'app.dart';
import 'app_bootstrap.dart';
import 'share_entrypoint.dart';

/// Entry point for the translucent ShareActivity (the see-through share
/// overlay). Defined here in the main library, not in share_entrypoint.dart,
/// because Flutter resolves a named Dart entrypoint against the root library in
/// AOT/release builds; a named entrypoint in another file is unreliable there.
@pragma('vm:entry-point')
Future<void> shareMain() => runShareEntrypoint();

Future<void> main() => bootstrapApplication();

Future<void> bootstrapApplication({
  Future<AppBootstrapData> Function()? loadBootstrap,
}) => runBootstrappedApp(
  app: const TranscriberApp(),
  loadBootstrap: loadBootstrap,
);

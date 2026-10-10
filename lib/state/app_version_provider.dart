import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_version_service.dart';

/// Cached for the application lifetime because package metadata cannot change.
final appVersionProvider = FutureProvider<String>(
  (ref) => const AppVersionService().load(),
);

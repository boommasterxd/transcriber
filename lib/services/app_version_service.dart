import 'package:package_info_plus/package_info_plus.dart';

/// Reads the installed package version, including release build overrides.
class AppVersionService {
  const AppVersionService();

  Future<String> load() async {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.trim();
    if (version.isEmpty) {
      throw const FormatException('Missing package version.');
    }
    final build = info.buildNumber.trim();
    return build.isEmpty ? version : '$version+$build';
  }
}

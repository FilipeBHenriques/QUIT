import 'dart:io';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';

class AppService {
  /// Returns a list of apps available to block
  static Future<List<AppInfo>> getApps() async {
    if (Platform.isAndroid) {
      // Android: get installed apps
      final installedApps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false, // Only user apps
        excludeNonLaunchableApps: true, // Only apps that can be launched
        withIcon: true, // Set to true to include icons
      );

      // Fix return: Map installedApps to AppInfo
      return installedApps.map<AppInfo>((app) => app).toList();
    } else if (Platform.isIOS) {
      // iOS: cannot get installed apps, return placeholder/recommended list
      return [];
    } else {
      // Other platforms
      return [];
    }
  }
}

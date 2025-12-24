import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_stats/usage_stats.dart';

class AppBlockingService {
  static const platform = MethodChannel('com.quit.app/service');
  static Timer? _monitoringTimer;
  static bool _isMonitoring = false;
  static Function(String)? _onBlockedAppDetected;

  /// Start monitoring foreground apps with foreground service
  static Future<void> startMonitoring(
    Function(String) onBlockedAppDetected,
  ) async {
    if (_isMonitoring) return;

    _onBlockedAppDetected = onBlockedAppDetected;
    _isMonitoring = true;

    if (Platform.isAndroid) {
      // Check permissions first
      bool? hasPermission = await UsageStats.checkUsagePermission();
      bool hasOverlay = await hasOverlayPermission();

      if (hasPermission != true || !hasOverlay) {
        print('❌ Missing permissions');
        _isMonitoring = false;
        return;
      }

      // Get current blocked apps list
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> blockedApps = prefs.getStringList('blocked_apps') ?? [];

      print(
        '📋 Starting monitoring service with ${blockedApps.length} blocked apps',
      );
      print('📋 Blocked apps: $blockedApps');

      // Start foreground service and SEND the blocked apps list
      try {
        await platform.invokeMethod('startMonitoringService', {
          'blockedApps': blockedApps,
        });
        print('✅ Foreground monitoring service started with blocked apps');
      } catch (e) {
        print('❌ Error starting monitoring service: $e');
      }

      // Also run in-app monitoring for when app is open
      _monitoringTimer = Timer.periodic(const Duration(seconds: 1), (
        timer,
      ) async {
        await _checkForegroundApp();
      });
    }
  }

  /// Stop monitoring
  static Future<void> stopMonitoring() async {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;
    _onBlockedAppDetected = null;

    if (Platform.isAndroid) {
      try {
        await platform.invokeMethod('stopMonitoringService');
        print('✅ Monitoring service stopped');
      } catch (e) {
        print('❌ Error stopping monitoring service: $e');
      }
    }
  }

  /// Update the blocked apps list in the running service
  static Future<void> updateBlockedApps(List<String> blockedApps) async {
    if (!Platform.isAndroid) return;

    try {
      print('📋 Updating service with ${blockedApps.length} blocked apps');
      await platform.invokeMethod('updateBlockedApps', {
        'blockedApps': blockedApps,
      });
      print('✅ Service updated with new blocked apps list');
    } catch (e) {
      print('❌ Error updating blocked apps: $e');
    }
  }

  /// Check if a blocked app is currently in the foreground
  static Future<void> _checkForegroundApp() async {
    try {
      String? foregroundPackage = await getCurrentForegroundApp();
      if (foregroundPackage == null) return;

      // Skip if it's our own app
      if (foregroundPackage == 'com.example.quit' ||
          foregroundPackage.contains('com.example.quit')) {
        await _hideOverlay();
        return;
      }

      // Check if this app is blocked
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> blockedApps = prefs.getStringList('blocked_apps') ?? [];

      if (blockedApps.contains(foregroundPackage)) {
        print('🚫 BLOCKED APP DETECTED: $foregroundPackage');
        await _showOverlay(foregroundPackage);
        _onBlockedAppDetected?.call(foregroundPackage);
      } else {
        await _hideOverlay();
      }
    } catch (e) {
      print('❌ Error checking foreground app: $e');
    }
  }

  /// Check if usage stats permission is granted
  static Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return false;
    return await UsageStats.checkUsagePermission() ?? false;
  }

  /// Request usage stats permission (opens settings)
  static Future<void> requestPermission() async {
    if (Platform.isAndroid) {
      await UsageStats.grantUsagePermission();
    }
  }

  /// Show overlay on top of blocked app
  static Future<void> _showOverlay(String packageName) async {
    if (!Platform.isAndroid) return;

    try {
      const platform = MethodChannel('com.quit.app/overlay');
      await platform.invokeMethod('showOverlay', {'packageName': packageName});
      print('✅ Overlay shown for: $packageName');
    } catch (e) {
      print('❌ Error showing overlay: $e');
    }
  }

  /// Hide overlay
  static Future<void> _hideOverlay() async {
    if (!Platform.isAndroid) return;

    try {
      const platform = MethodChannel('com.quit.app/overlay');
      await platform.invokeMethod('hideOverlay');
    } catch (e) {
      // Ignore errors when hiding
    }
  }

  /// Check if overlay permission is granted
  static Future<bool> hasOverlayPermission() async {
    if (!Platform.isAndroid) return false;

    try {
      const platform = MethodChannel('com.quit.app/permission');
      final result = await platform.invokeMethod('checkOverlayPermission');
      return result as bool? ?? false;
    } catch (e) {
      print('❌ Error checking overlay permission: $e');
      return false;
    }
  }

  /// Request overlay permission
  static Future<void> requestOverlayPermission() async {
    if (!Platform.isAndroid) return;

    try {
      const platform = MethodChannel('com.quit.app/permission');
      await platform.invokeMethod('requestOverlayPermission');
    } catch (e) {
      print('❌ Error requesting overlay permission: $e');
    }
  }

  /// Get the current foreground app package name
  static Future<String?> getCurrentForegroundApp() async {
    if (!Platform.isAndroid) return null;

    try {
      DateTime now = DateTime.now();
      DateTime start = now.subtract(const Duration(seconds: 5));
      List<UsageInfo> stats = await UsageStats.queryUsageStats(start, now);

      if (stats.isEmpty) return null;

      stats.sort((a, b) {
        dynamic aTime = a.lastTimeUsed;
        dynamic bTime = b.lastTimeUsed;

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        if (aTime is DateTime && bTime is DateTime) {
          return bTime.compareTo(aTime);
        }

        if (aTime is String && bTime is String) {
          try {
            DateTime aDate = DateTime.parse(aTime);
            DateTime bDate = DateTime.parse(bTime);
            return bDate.compareTo(aDate);
          } catch (e) {
            return bTime.compareTo(aTime);
          }
        }

        if (aTime is int && bTime is int) {
          return bTime.compareTo(aTime);
        }

        return bTime.toString().compareTo(aTime.toString());
      });

      return stats.first.packageName;
    } catch (e) {
      print('❌ Error getting foreground app: $e');
      return null;
    }
  }

  /// Unblock an app
  static Future<void> unblockApp(String packageName) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> blockedApps = prefs.getStringList('blocked_apps') ?? [];
      blockedApps.remove(packageName);
      await prefs.setStringList('blocked_apps', blockedApps);

      // Update the service with new list
      await updateBlockedApps(blockedApps);

      // Hide overlay immediately
      await _hideOverlay();

      print('✅ App unblocked: $blockedApps');
    } catch (e) {
      print('❌ Error unblocking app: $e');
    }
  }
}

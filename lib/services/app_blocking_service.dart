import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_stats/usage_stats.dart';

class AppBlockingService {
  static const _monitoringChannel = MethodChannel('com.quit.app/monitoring');
  static const _overlayChannel = MethodChannel('com.quit.app/overlay');
  static const _permissionChannel = MethodChannel('com.quit.app/permission');

  static bool _isMonitoring = false;
  static Function(String)? _onBlockedAppDetected;

  /// Start monitoring foreground apps using native background service
  static Future<void> startMonitoring(
    Function(String) onBlockedAppDetected,
  ) async {
    if (_isMonitoring) return;

    _onBlockedAppDetected = onBlockedAppDetected;
    _isMonitoring = true;

    if (Platform.isAndroid) {
      // Check permission first
      bool? hasPermission = await UsageStats.checkUsagePermission();
      if (hasPermission != true) {
        print('❌ Usage permission not granted');
        _isMonitoring = false;
        return;
      }

      // Setup method channel listener for unblock events from overlay
      _setupMethodChannelListener();

      // Get current blocked apps list
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> blockedApps = prefs.getStringList('blocked_apps') ?? [];

      // Start the native background monitoring service
      try {
        await _monitoringChannel.invokeMethod('startMonitoring', {
          'blockedApps': blockedApps,
        });
        print(
          '✅ Native monitoring service started with ${blockedApps.length} blocked apps',
        );
      } catch (e) {
        print('❌ Error starting monitoring service: $e');
        _isMonitoring = false;
      }
    }
  }

  /// Setup method channel to listen for unblock events from overlay
  static void _setupMethodChannelListener() {
    _overlayChannel.setMethodCallHandler((call) async {
      if (call.method == 'unblockedApp') {
        final packageName = call.arguments['packageName'] as String?;
        if (packageName != null) {
          print('📱 Received unblock event from overlay for: $packageName');
          await unblockApp(packageName);
        }
      }
    });
  }

  /// Stop monitoring - stops the native background service
  static Future<void> stopMonitoring() async {
    _onBlockedAppDetected = null;
    _isMonitoring = false;

    if (Platform.isAndroid) {
      try {
        await _monitoringChannel.invokeMethod('stopMonitoring');
        print('✅ Native monitoring service stopped');
      } catch (e) {
        print('❌ Error stopping monitoring service: $e');
      }
    }
  }

  /// Update blocked apps list in the background service
  static Future<void> updateBlockedApps(List<String> blockedApps) async {
    if (!Platform.isAndroid) return;

    try {
      await _monitoringChannel.invokeMethod('updateBlockedApps', {
        'blockedApps': blockedApps,
      });
      print('✅ Updated blocked apps in background service: $blockedApps');
    } catch (e) {
      print('❌ Error updating blocked apps: $e');
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

  /// Hide overlay
  static Future<void> _hideOverlay() async {
    if (!Platform.isAndroid) return;

    try {
      await _overlayChannel.invokeMethod('hideOverlay');
      print('✅ Overlay hidden');
    } catch (e) {
      print('Error hiding overlay: $e');
    }
  }

  /// Public method to unblock app and hide overlay
  static Future<void> unblockApp(String packageName) async {
    try {
      print('🔓 Unblocking app: $packageName');

      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> blockedApps = prefs.getStringList('blocked_apps') ?? [];
      blockedApps.remove(packageName);
      await prefs.setStringList('blocked_apps', blockedApps);

      // Update the background service with new list
      await updateBlockedApps(blockedApps);

      // Hide overlay immediately
      await _hideOverlay();

      print('✅ App unblocked and overlay hidden: $packageName');
    } catch (e) {
      print('Error unblocking app: $e');
    }
  }

  /// Check if overlay permission is granted
  static Future<bool> hasOverlayPermission() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _permissionChannel.invokeMethod(
        'checkOverlayPermission',
      );
      return result as bool? ?? false;
    } catch (e) {
      print('Error checking overlay permission: $e');
      return false;
    }
  }

  /// Request overlay permission
  static Future<void> requestOverlayPermission() async {
    if (!Platform.isAndroid) return;

    try {
      await _permissionChannel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      print('Error requesting overlay permission: $e');
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

        if (aTime is DateTime && bTime is DateTime)
          return bTime.compareTo(aTime);
        if (aTime is String && bTime is String) {
          try {
            DateTime aDate = DateTime.parse(aTime);
            DateTime bDate = DateTime.parse(bTime);
            return bDate.compareTo(aDate);
          } catch (e) {
            return bTime.compareTo(aTime);
          }
        }
        if (aTime is int && bTime is int) return bTime.compareTo(aTime);

        return bTime.toString().compareTo(aTime.toString());
      });
      return stats.first.packageName;
    } catch (e) {
      print('Error getting foreground app: $e');
      return null;
    }
  }
}

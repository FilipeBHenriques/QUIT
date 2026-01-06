import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_stats/usage_stats.dart';

class AppBlockingService {
  static Timer? _monitoringTimer;
  static bool _isMonitoring = false;
  static Function(String)? _onBlockedAppDetected;
  static String? _currentlyBlockedApp;

  /// Start monitoring foreground apps
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
        // Permission not granted, will need to request it
        _isMonitoring = false;
        return;
      }

      // Setup method channel listener for unblock events from overlay
      _setupMethodChannelListener();

      // Start periodic monitoring - check every 1 second for faster detection
      _monitoringTimer = Timer.periodic(const Duration(seconds: 1), (
        timer,
      ) async {
        await _checkForegroundApp();
      });
    }
  }

  /// Setup method channel to listen for unblock events from overlay
  static void _setupMethodChannelListener() {
    const platform = MethodChannel('com.quit.app/overlay');
    platform.setMethodCallHandler((call) async {
      if (call.method == 'unblockedApp') {
        final packageName = call.arguments['packageName'] as String?;
        if (packageName != null) {
          print('📱 Received unblock event from overlay for: $packageName');
          await unblockApp(packageName);
        }
      }
    });
  }

  /// Stop monitoring
  static void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;
    _onBlockedAppDetected = null;
    _currentlyBlockedApp = null;
  }

  /// Check if a blocked app is currently in the foreground
  static Future<void> _checkForegroundApp() async {
    try {
      DateTime now = DateTime.now();
      DateTime start = now.subtract(const Duration(seconds: 5));
      List<UsageInfo> stats = await UsageStats.queryUsageStats(start, now);

      if (stats.isEmpty) return;

      // Sort by last time used to get the most recent app
      stats.sort((a, b) {
        dynamic aTime = a.lastTimeUsed;
        dynamic bTime = b.lastTimeUsed;

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        if (aTime is DateTime && bTime is DateTime) return bTime.compareTo(aTime);
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

      String? foregroundPackage = stats.first.packageName;
      if (foregroundPackage == null) return;

      // Skip own app
      if (foregroundPackage == 'com.example.quit' ||
          foregroundPackage.contains('com.example.quit')) {
        return;
      }

      // Check if this app is blocked
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> blockedApps = prefs.getStringList('blocked_apps') ?? [];

      print(
        '🔍 Checking app: $foregroundPackage, Blocked: ${blockedApps.contains(foregroundPackage)}',
      );

      if (blockedApps.contains(foregroundPackage)) {
        // Only show overlay if it's a new blocked app
        if (_currentlyBlockedApp != foregroundPackage) {
          _currentlyBlockedApp = foregroundPackage;
          print('🚫 BLOCKED APP DETECTED: $foregroundPackage');

          // Show overlay
          await _showOverlay(foregroundPackage);

          // Notify callback
          _onBlockedAppDetected?.call(foregroundPackage);
        }
      } else {
        // App is not blocked, clear current blocked app and hide overlay
        if (_currentlyBlockedApp != null) {
          _currentlyBlockedApp = null;
          await _hideOverlay();
        }
      }
    } catch (e) {
      print('Error checking foreground app: $e');
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
      String appName = packageName;

      const platform = MethodChannel('com.quit.app/overlay');
      await platform.invokeMethod('showOverlay', {
        'packageName': packageName,
        'appName': appName,
      });
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

      // Clear currently blocked app
      _currentlyBlockedApp = null;

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
      const platform = MethodChannel('com.quit.app/permission');
      final result = await platform.invokeMethod('checkOverlayPermission');
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
      const platform = MethodChannel('com.quit.app/permission');
      await platform.invokeMethod('requestOverlayPermission');
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

        if (aTime is DateTime && bTime is DateTime) return bTime.compareTo(aTime);
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
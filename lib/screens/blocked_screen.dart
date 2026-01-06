import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BlockedScreen extends StatefulWidget {
  final String blockedPackageName;
  final VoidCallback? onUnblocked;

  const BlockedScreen({
    super.key,
    required this.blockedPackageName,
    this.onUnblocked,
  });

  @override
  State<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends State<BlockedScreen> {
  String? _appName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAppName();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _loadAppName() async {
    try {
      List<AppInfo> apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        excludeNonLaunchableApps: true,
        withIcon: false,
      );

      AppInfo? app = apps.firstWhere(
        (app) => app.packageName == widget.blockedPackageName,
        orElse: () => apps.first,
      );

      setState(() {
        _appName = app.name;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _appName = widget.blockedPackageName;
        _loading = false;
      });
    }
  }

  Future<void> _unblockApp() async {
    print('🟢 Unblock button pressed for: ${widget.blockedPackageName}');

    // Remove from blocked apps list
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> blockedApps = prefs.getStringList('blocked_apps') ?? [];
    blockedApps.remove(widget.blockedPackageName);

    // CRITICAL: Force save and wait
    await prefs.remove('blocked_apps');
    await Future.delayed(Duration(milliseconds: 100));
    bool saved = await prefs.setStringList('blocked_apps', blockedApps);
    await prefs.commit(); // Force commit

    print('🟢 Saved to SharedPreferences: $saved');
    print('🟢 New list: $blockedApps');

    // Update the background monitoring service
    try {
      const monitoringChannel = MethodChannel('com.quit.app/monitoring');
      await monitoringChannel.invokeMethod('updateBlockedApps', {
        'blockedApps': blockedApps,
      });
      print('🟢 Background service updated');
    } catch (e) {
      print('❌ Error updating background service: $e');
    }

    // Hide the overlay
    try {
      const platform = MethodChannel('com.quit.app/overlay');
      await platform.invokeMethod('hideOverlay');
      print('🟢 Overlay hidden');
    } catch (e) {
      print('❌ Error hiding overlay: $e');
    }

    // Call callback
    if (mounted) {
      widget.onUnblocked?.call();
      print('🟢 Callback called');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.block, size: 100, color: Colors.red),
                  const SizedBox(height: 32),
                  const Text(
                    'App Blocked!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const CircularProgressIndicator()
                  else
                    Text(
                      _appName ?? widget.blockedPackageName,
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 48),
                  const Text(
                    'This app has been blocked.\nYou cannot access it right now.',
                    style: TextStyle(fontSize: 16, color: Colors.white60),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: _unblockApp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text(
                      'Unblock This App',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BlockedScreen extends StatefulWidget {
  const BlockedScreen({super.key});

  @override
  State<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends State<BlockedScreen> {
  static const blockedAppChannel = MethodChannel('com.quit.app/blocked_app');
  static const navigationChannel = MethodChannel('com.quit.app/navigation');
  static const monitoringChannel = MethodChannel('com.quit.app/monitoring');

  String? _blockedPackageName;
  String? _appName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedAppInfo();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _loadBlockedAppInfo() async {
    try {
      final info = await blockedAppChannel.invokeMethod('getBlockedAppInfo');
      final packageName = info['packageName'] as String?;
      final appName = info['appName'] as String?;

      setState(() {
        _blockedPackageName = packageName;
        _appName = appName ?? packageName;
        _loading = false;
      });

      print('📦 Blocked app info: $packageName - $appName');
    } catch (e) {
      print('❌ Error loading blocked app info: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _unblockApp() async {
    if (_blockedPackageName == null) return;

    print('🟢 Unblock button pressed for: $_blockedPackageName');

    // Remove from blocked apps list
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> blockedApps = prefs.getStringList('blocked_apps') ?? [];
    blockedApps.remove(_blockedPackageName);

    // Save
    await prefs.setStringList('blocked_apps', blockedApps);
    print('🟢 New blocked apps list: $blockedApps');

    // Update the background monitoring service
    try {
      await monitoringChannel.invokeMethod('updateBlockedApps', {
        'blockedApps': blockedApps,
      });
      print('🟢 Background service updated');
    } catch (e) {
      print('❌ Error updating background service: $e');
    }

    // Go to home screen
    _closeActivity();
  }

  Future<void> _closeActivity() async {
    print('🔴 Close button pressed - returning to home');
    try {
      await navigationChannel.invokeMethod('goHome');
    } catch (e) {
      print('❌ Error launching home: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Close button at top right
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: _closeActivity,
                          ),
                        ),
                        const Spacer(),
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
                        Text(
                          _appName ?? _blockedPackageName ?? 'Unknown App',
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
                        const Spacer(),
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

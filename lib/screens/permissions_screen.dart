import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/neon_palette.dart';

class _PermissionItem {
  final String key;
  final String title;
  final String description;
  final IconData icon;

  const _PermissionItem({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
  });
}

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.quit.app/permissions');

  Map<String, bool> _status = {};
  bool _loading = true;

  static const _permissions = [
    _PermissionItem(
      key: 'usageStats',
      title: 'Usage Access',
      description:
          'Lets QUIT detect which app is in the foreground so it can block it in real time.',
      icon: Icons.bar_chart_rounded,
    ),
    _PermissionItem(
      key: 'accessibility',
      title: 'Accessibility Service',
      description:
          'Required to intercept app launches and block websites in your browser.',
      icon: Icons.accessibility_new_rounded,
    ),
    _PermissionItem(
      key: 'overlay',
      title: 'Display Over Apps',
      description:
          'Shows the blocking screen on top of blocked apps and websites.',
      icon: Icons.layers_rounded,
    ),
    _PermissionItem(
      key: 'battery',
      title: 'Battery Optimization',
      description:
          'Prevents Android from killing the monitoring service in the background.',
      icon: Icons.battery_charging_full_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    try {
      final result =
          await _channel.invokeMapMethod<String, bool>('checkAll');
      if (!mounted) return;
      setState(() {
        _status = result ?? {};
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = {};
          _loading = false;
        });
      }
    }
  }

  Future<void> _openSettings(String key) async {
    final methodMap = {
      'usageStats': 'openUsageStats',
      'accessibility': 'openAccessibility',
      'overlay': 'openOverlay',
      'battery': 'openBattery',
    };
    final method = methodMap[key];
    if (method == null) return;
    try {
      await _channel.invokeMethod(method);
    } catch (_) {}
  }

  bool get _allGranted =>
      _permissions.every((p) => _status[p.key] == true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeonPalette.bg,
      body: Column(
        children: [
          // Custom AppBar-style header
          SafeArea(
            bottom: false,
            child: Container(
              height: 56,
              color: NeonPalette.bg,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: NeonPalette.textMuted,
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'PERMISSIONS',
                        style: TextStyle(
                          color: NeonPalette.text,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ),
                  // Balance the leading icon so the title stays truly centered
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          // Thin divider
          Container(
            height: 0.5,
            color: NeonPalette.border,
          ),
          // Body content
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: NeonPalette.violet,
                      strokeWidth: 1.5,
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    children: [
                      ..._permissions.map((p) => _buildCard(p)),
                      if (_allGranted) ...[
                        const SizedBox(height: 8),
                        _buildAllGrantedBox(),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(_PermissionItem item) {
    final granted = _status[item.key] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: NeonPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: granted
              ? NeonPalette.border
              : NeonPalette.rose.withValues(alpha: 0.18),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              item.icon,
              size: 22,
              color: granted ? NeonPalette.mint : NeonPalette.rose,
            ),
          ),
          const SizedBox(width: 12),
          // Title + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: NeonPalette.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: const TextStyle(
                    color: NeonPalette.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Badge or button
          if (granted)
            _buildGrantedBadge()
          else
            GestureDetector(
              onTap: () => _openSettings(item.key),
              child: _buildOpenButton(),
            ),
        ],
      ),
    );
  }

  Widget _buildGrantedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: NeonPalette.mint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: NeonPalette.mint.withValues(alpha: 0.30),
          width: 0.5,
        ),
      ),
      child: const Text(
        'GRANTED',
        style: TextStyle(
          color: NeonPalette.mint,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildOpenButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: NeonPalette.rose.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: NeonPalette.rose.withValues(alpha: 0.45),
          width: 0.5,
        ),
      ),
      child: const Text(
        'OPEN \u2192',
        style: TextStyle(
          color: NeonPalette.rose,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAllGrantedBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: NeonPalette.mint.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: NeonPalette.mint.withValues(alpha: 0.22),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shield_rounded,
            size: 18,
            color: NeonPalette.mint,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'All permissions are active. QUIT is running.',
              style: TextStyle(
                color: NeonPalette.mint,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

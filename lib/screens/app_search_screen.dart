import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:quit/theme/neon_palette.dart';
import 'package:quit/widgets/app_icon_widget.dart';
import 'package:quit/widgets/neon_switch.dart';

const Color _kSearchAccent = Color(0xFFEF4444);
const Color _kSearchText = NeonPalette.text;

class AppSearchScreen extends StatefulWidget {
  final List<AppInfo> installedApps;
  final Set<String> blockedApps;
  final Future<void> Function(String packageName, bool blocked) onToggleAppBlock;

  const AppSearchScreen({
    super.key,
    required this.installedApps,
    required this.blockedApps,
    required this.onToggleAppBlock,
  });

  @override
  State<AppSearchScreen> createState() => _AppSearchScreenState();
}

class _AppSearchScreenState extends State<AppSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  late Set<String> _blockedAppsLocal;

  @override
  void initState() {
    super.initState();
    _blockedAppsLocal = Set<String>.from(widget.blockedApps);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleApp(String packageName, bool blocked) async {
    await widget.onToggleAppBlock(packageName, blocked);
    if (!mounted) return;

    setState(() {
      if (blocked) {
        _blockedAppsLocal.add(packageName);
      } else {
        _blockedAppsLocal.remove(packageName);
      }
    });
  }

  void _closeSearch() {
    Navigator.of(context).pop(Set<String>.from(_blockedAppsLocal));
  }

  @override
  Widget build(BuildContext context) {
    final filteredApps = widget.installedApps.where((app) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return app.name.toLowerCase().contains(q) ||
          app.packageName.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        final aBlocked = _blockedAppsLocal.contains(a.packageName);
        final bBlocked = _blockedAppsLocal.contains(b.packageName);
        if (aBlocked && !bBlocked) return -1;
        if (!aBlocked && bBlocked) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return Scaffold(
      backgroundColor: NeonPalette.bg,
      resizeToAvoidBottomInset: true,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _closeSearch();
        },
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _closeSearch,
                      icon: const Icon(Icons.arrow_back, color: _kSearchText),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Search Apps',
                      style: TextStyle(
                        color: _kSearchText,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: _kSearchText),
                  cursorColor: _kSearchAccent,
                  decoration: InputDecoration(
                    hintText: 'Type app name or package...',
                    hintStyle: const TextStyle(color: NeonPalette.textMuted),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: NeonPalette.textMuted,
                    ),
                    filled: true,
                    fillColor: NeonPalette.surfaceSoft,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: NeonPalette.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: _kSearchAccent,
                        width: 1.6,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: filteredApps.isEmpty
                    ? const Center(
                        child: Text(
                          'No apps found',
                          style: TextStyle(color: _kSearchText),
                        ),
                      )
                    : ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: filteredApps.length,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 2),
                        itemBuilder: (context, index) {
                          final app = filteredApps[index];
                          final isBlocked = _blockedAppsLocal.contains(
                            app.packageName,
                          );

                          return Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: NeonPalette.border),
                              borderRadius: BorderRadius.circular(12),
                              color: NeonPalette.surface,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: NeonPalette.surfaceSoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(child: AppIconWidget(app: app)),
                              ),
                              title: Text(
                                app.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: _kSearchText,
                                ),
                              ),
                              subtitle: Text(
                                app.packageName,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: NeonPalette.textMuted,
                                ),
                              ),
                              trailing: NeonSwitch(
                                value: isBlocked,
                                onChanged: (value) {
                                  _toggleApp(app.packageName, value);
                                },
                                activeColor: _kSearchAccent,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

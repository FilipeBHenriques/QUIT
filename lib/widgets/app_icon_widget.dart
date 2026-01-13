import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

class AppIconWidget extends StatelessWidget {
  final AppInfo app;

  const AppIconWidget({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    if (app.icon != null && app.icon!.isNotEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            app.icon!,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultIcon();
            },
          ),
        ),
      );
    }
    return _buildDefaultIcon();
  }

  Widget _buildDefaultIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.android, color: Colors.white, size: 32),
    );
  }
}

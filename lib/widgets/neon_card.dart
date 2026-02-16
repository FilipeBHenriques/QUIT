import 'package:shadcn_flutter/shadcn_flutter.dart';

class NeonCard extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double glowOpacity;
  final EdgeInsets? padding;

  const NeonCard({
    super.key,
    required this.child,
    this.glowColor = const Color(0xFF06B6D4),
    this.glowOpacity = 0.3,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedContainer(
      borderRadius: BorderRadius.circular(16),
      // Pure black background as requested, only border glows.
      backgroundColor: const Color(0xFF18181B),
      borderColor: glowColor,
      borderWidth: 1.5,
      boxShadow: [
        BoxShadow(
          color: glowColor.withOpacity(glowOpacity),
          blurRadius: 6,
          spreadRadius: 0,
        ),
      ],
      padding: padding,
      child: child,
    );
  }
}

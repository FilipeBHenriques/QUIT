// NeonSwitch
import 'package:shadcn_flutter/shadcn_flutter.dart';

class NeonSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  const NeonSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = const Color(0xFFEF4444),
  });

  @override
  Widget build(BuildContext context) {
    // If shadcn_flutter does not provide its own Switch, decorate using OutlinedContainer for neon effect.
    return OutlinedContainer(
      borderRadius: BorderRadius.circular(20),
      borderColor: value ? activeColor : const Color(0xFF6B7280),
      borderWidth: 1.5,
      boxShadow: value
          ? [
              BoxShadow(
                color: activeColor.withOpacity(0.5),
                blurRadius: 9,
                spreadRadius: 2,
              ),
            ]
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      backgroundColor: Colors.transparent,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.white,

        inactiveThumbColor: const Color(0xFF6B7280),
      ),
    );
  }
}

// NeonProgressBar
import 'package:shadcn_flutter/shadcn_flutter.dart';

class NeonProgressBar extends StatelessWidget {
  final double value;
  final double max;
  final Color color;

  const NeonProgressBar({
    super.key,
    required this.value,
    this.max = 100,
    this.color = const Color(0xFFEF4444),
  });

  @override
  Widget build(BuildContext context) {
    return Progress(
      progress: (value / max).clamp(0.0, 1.0),
      backgroundColor: const Color(0xFF1F2937),
      color: color,
    );
  }
}

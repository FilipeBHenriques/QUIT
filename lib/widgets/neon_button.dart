// NeonButton
import 'package:shadcn_flutter/shadcn_flutter.dart';

class NeonButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final Color color;
  final EdgeInsetsGeometry padding;

  const NeonButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.color = const Color(0xFFEF4444),
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Button(
      onPressed: onPressed,
      style: ButtonVariance.outline.copyWith(
        decoration: (context, states, decoration) =>
            decoration.copyWithIfBoxDecoration(
              color: color,
              border: Border.all(
                color: color,
                width: 1.5,
              ), // invisible since matches bg
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.45),
                  blurRadius: 17,
                  spreadRadius: 0,
                ),
              ],
            ),
        textStyle: (context, states, style) =>
            style?.copyWith(color: Colors.white, fontWeight: FontWeight.w600) ??
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        padding: (context, states, defaultPadding) => padding,
      ),
      child: Text(text),
    );
  }
}

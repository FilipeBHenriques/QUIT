// NeonButton
import 'package:shadcn_flutter/shadcn_flutter.dart';

class NeonButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final Color color;
  final Color textColor;
  final Color? borderColor;
  final double glowOpacity;
  final double borderRadius;
  final double? fontSize;
  final FontWeight fontWeight;
  final double? letterSpacing;
  final EdgeInsetsGeometry padding;

  const NeonButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.color = const Color(0xFFEF4444),
    this.textColor = Colors.white,
    this.borderColor,
    this.glowOpacity = 0.45,
    this.borderRadius = 16,
    this.fontSize,
    this.fontWeight = FontWeight.w700,
    this.letterSpacing,
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
              border: Border.all(color: borderColor ?? color, width: 1.5),
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(glowOpacity),
                  blurRadius: 17,
                  spreadRadius: 0,
                ),
              ],
            ),
        textStyle: (context, states, style) =>
            style?.copyWith(
              color: textColor,
              fontWeight: fontWeight,
              fontSize: fontSize,
              letterSpacing: letterSpacing,
            ) ??
            TextStyle(
              color: textColor,
              fontWeight: fontWeight,
              fontSize: fontSize,
              letterSpacing: letterSpacing,
            ),
        padding: (context, states, defaultPadding) => padding,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}

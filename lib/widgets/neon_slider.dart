// NeonSlider (Material, neon "glow" flavor, but with subtle effect)
import 'package:flutter/material.dart';

class NeonSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final Color activeColor;

  const NeonSlider({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 120,
    this.divisions,
    this.label,
    this.onChanged,
    this.onChangeEnd,
    this.activeColor = const Color(0xFFEF4444),
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        activeTrackColor: activeColor.withOpacity(0.90),
        inactiveTrackColor: activeColor.withOpacity(0.10),
        thumbColor: activeColor,
        overlayColor: activeColor.withOpacity(0.12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18.0),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: activeColor.withOpacity(0.05),
              blurRadius: 6,
              spreadRadius: 0.5,
            ),
          ],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: label,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ),
    );
  }
}

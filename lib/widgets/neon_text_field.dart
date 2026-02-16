// NeonTextField
import 'package:shadcn_flutter/shadcn_flutter.dart';

class NeonTextField extends StatelessWidget {
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final Widget? leading;

  const NeonTextField({
    super.key,
    this.placeholder,
    this.onChanged,
    this.controller,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      placeholder: placeholder == null ? null : Text(placeholder!),

      style: const TextStyle(color: Colors.white),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF374151)),
      ),
    );
  }
}

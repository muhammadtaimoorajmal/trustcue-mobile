import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool multiline;
  final int? minLines;
  final int? maxLines;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.enabled = true,
    this.multiline = false,
    this.minLines,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      enabled: enabled,
      minLines: multiline ? (minLines ?? 3) : 1,
      maxLines: multiline ? maxLines : 1,
      keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        errorText: errorText,
        helperMaxLines: 5,
        errorMaxLines: 5,
        border: const OutlineInputBorder(),
        alignLabelWithHint: multiline,
      ),
    );
  }
}

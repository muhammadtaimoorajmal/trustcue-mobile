import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final String? counterText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool multiline;
  final int? minLines;
  final int? maxLines;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.counterText,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.enabled = true,
    this.multiline = false,
    this.minLines,
    this.maxLines,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      enabled: enabled,
      obscureText: obscureText,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      minLines: multiline ? (minLines ?? 3) : 1,
      maxLines: multiline ? maxLines : 1,
      keyboardType:
          keyboardType ??
          (multiline ? TextInputType.multiline : TextInputType.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        errorText: errorText,
        counterText: counterText,
        suffixIcon: suffixIcon,
        helperMaxLines: 5,
        errorMaxLines: 5,
        border: const OutlineInputBorder(),
        alignLabelWithHint: multiline,
      ),
    );
  }
}

import 'package:flutter/material.dart';

enum _AppButtonVariant { primary, secondary }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final _AppButtonVariant _variant;

  const AppButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  }) : _variant = _AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  }) : _variant = _AppButtonVariant.secondary;

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null;
    final bool canPress = !isDisabled && !isLoading;
    final theme = Theme.of(context);

    Widget child = Text(label, textAlign: TextAlign.center);

    if (isLoading) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _variant == _AppButtonVariant.primary
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: child),
        ],
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Flexible(child: child),
        ],
      );
    } else {
      // For proper wrapping when text is large
      child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Flexible(child: child)],
      );
    }

    final buttonStyle = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size(48, 48)),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );

    return Semantics(
      button: true,
      enabled: canPress,
      label: isLoading ? '$label, loading' : null,
      excludeSemantics: isLoading,
      child: _variant == _AppButtonVariant.primary
          ? FilledButton(
              onPressed: canPress ? onPressed : null,
              style: buttonStyle,
              child: child,
            )
          : OutlinedButton(
              onPressed: canPress ? onPressed : null,
              style: buttonStyle,
              child: child,
            ),
    );
  }
}

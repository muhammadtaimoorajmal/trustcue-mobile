import 'package:flutter/material.dart';

class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color caution;
  final Color cautionForeground;
  final Color success;
  final Color successForeground;
  final Color border;

  const AppSemanticColors({
    required this.caution,
    required this.cautionForeground,
    required this.success,
    required this.successForeground,
    required this.border,
  });

  @override
  ThemeExtension<AppSemanticColors> copyWith({
    Color? caution,
    Color? cautionForeground,
    Color? success,
    Color? successForeground,
    Color? border,
  }) {
    return AppSemanticColors(
      caution: caution ?? this.caution,
      cautionForeground: cautionForeground ?? this.cautionForeground,
      success: success ?? this.success,
      successForeground: successForeground ?? this.successForeground,
      border: border ?? this.border,
    );
  }

  @override
  ThemeExtension<AppSemanticColors> lerp(
    covariant ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      caution: Color.lerp(caution, other.caution, t)!,
      cautionForeground: Color.lerp(
        cautionForeground,
        other.cautionForeground,
        t,
      )!,
      success: Color.lerp(success, other.success, t)!,
      successForeground: Color.lerp(
        successForeground,
        other.successForeground,
        t,
      )!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

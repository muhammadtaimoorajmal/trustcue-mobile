import 'package:flutter/material.dart';

abstract class AppColors {
  // Brand Anchors
  static const Color deepNavy = Color(0xFF0A2540);
  static const Color lightSurface = Color(0xFFF8F9FA);
  static const Color darkSurface = Color(0xFF121212);

  // Light Theme Specifics
  static const Color primaryActionLight = Color(0xFF00695C);
  static const Color primaryActionForegroundLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF111111);
  static const Color textSecondaryLight = Color(0xFF555555);
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color cardSurfaceLight = Color(0xFFFFFFFF);

  // Dark Theme Specifics
  static const Color primaryActionDark = Color(0xFF4DB6AC);
  static const Color primaryActionForegroundDark = Color(0xFF0A2540);
  static const Color textPrimaryDark = Color(0xFFEEEEEE);
  static const Color textSecondaryDark = Color(0xFFAAAAAA);
  static const Color borderDark = Color(0xFF333333);
  static const Color cardSurfaceDark = Color(0xFF1E1E1E);

  // Semantic (Shared/Similar)
  static const Color cautionLight = Color(0xFFFFB300);
  static const Color cautionDark = Color(0xFFFFCA28);
  static const Color cautionForeground = Color(0xFF332200);

  static const Color errorLight = Color(0xFFD32F2F);
  static const Color errorDark = Color(0xFFEF5350);
  static const Color errorForegroundLight = Color(0xFFFFFFFF);
  static const Color errorForegroundDark = Color(0xFF000000);

  static const Color successLight = Color(0xFF388E3C);
  static const Color successDark = Color(0xFF66BB6A);
}

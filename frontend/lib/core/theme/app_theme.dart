import 'package:flutter/material.dart';
import 'package:trustcue_mobile/core/theme/app_colors.dart';
import 'package:trustcue_mobile/core/theme/app_semantic_colors.dart';

abstract class AppTheme {
  static const _bodySize = 16.0;
  static const _supportingSize = 14.0;

  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return TextTheme(
      headlineLarge: TextStyle(
        color: primary,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        color: primary,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      headlineSmall: TextStyle(
        color: primary,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        color: primary,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(
        color: primary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: primary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: primary, fontSize: _bodySize, height: 1.5),
      bodyMedium: TextStyle(
        color: secondary,
        fontSize: _supportingSize,
        height: 1.4,
      ),
      bodySmall: TextStyle(color: secondary, fontSize: 12, height: 1.4),
      labelLarge: TextStyle(
        color: primary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: TextStyle(
        color: primary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        color: secondary,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryActionLight,
      brightness: Brightness.light,
      primary: AppColors.primaryActionLight,
      onPrimary: AppColors.primaryActionForegroundLight,
      surface: AppColors.lightSurface,
      onSurface: AppColors.textPrimaryLight,
      error: AppColors.errorLight,
      onError: AppColors.errorForegroundLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightSurface,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.deepNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: _buildTextTheme(
        AppColors.textPrimaryLight,
        AppColors.textSecondaryLight,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.cardSurfaceLight,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryActionLight,
        foregroundColor: AppColors.primaryActionForegroundLight,
      ),
      extensions: const [
        AppSemanticColors(
          caution: AppColors.cautionLight,
          cautionForeground: AppColors.cautionForeground,
          success: AppColors.successLight,
          successForeground: Colors.white,
          border: AppColors.borderLight,
        ),
      ],
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryActionDark,
      brightness: Brightness.dark,
      primary: AppColors.primaryActionDark,
      onPrimary: AppColors.primaryActionForegroundDark,
      surface: AppColors.darkSurface,
      onSurface: AppColors.textPrimaryDark,
      error: AppColors.errorDark,
      onError: AppColors.errorForegroundDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkSurface,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(
          0xFF05121F,
        ), // Slightly darker navy for dark mode
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: _buildTextTheme(
        AppColors.textPrimaryDark,
        AppColors.textSecondaryDark,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.cardSurfaceDark,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryActionDark,
        foregroundColor: AppColors.primaryActionForegroundDark,
      ),
      extensions: const [
        AppSemanticColors(
          caution: AppColors.cautionDark,
          cautionForeground: AppColors.cautionForeground,
          success: AppColors.successDark,
          successForeground: Colors.black,
          border: AppColors.borderDark,
        ),
      ],
    );
  }
}

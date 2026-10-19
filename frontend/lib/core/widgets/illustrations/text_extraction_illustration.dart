import 'package:flutter/material.dart';
import 'package:trustcue_mobile/core/theme/app_colors.dart';

/// A code-native vector illustration depicting on-device image/OCR text extraction.
///
/// Fully offline, resolution-independent, and adapts dynamically to light/dark theme.
class TextExtractionIllustration extends StatelessWidget {
  const TextExtractionIllustration({
    super.key,
    this.width = 200,
    this.height = 120,
    this.semanticsLabel =
        'Illustration of on-device text extraction from a screenshot',
  });

  final double width;
  final double height;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: semanticsLabel,
      image: true,
      child: CustomPaint(
        size: Size(width, height),
        painter: _TextExtractionPainter(isDark: isDark),
      ),
    );
  }
}

class _TextExtractionPainter extends CustomPainter {
  _TextExtractionPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Document / phone screenshot frame
    final frameRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.15, h * 0.08, w * 0.70, h * 0.84),
      const Radius.circular(12),
    );

    final frameBg = Paint()
      ..color = isDark ? const Color(0xFF16202C) : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(frameRect, frameBg);

    final frameBorder = Paint()
      ..color = isDark ? const Color(0xFF2C3E55) : const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(frameRect, frameBorder);

    // Corner brackets indicating OCR focus (Teal)
    final bracketPaint = Paint()
      ..color = isDark
          ? AppColors.primaryActionDark
          : AppColors.primaryActionLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final bLen = w * 0.08;
    // Top-left bracket
    canvas.drawLine(
      Offset(w * 0.22, h * 0.20),
      Offset(w * 0.22 + bLen, h * 0.20),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(w * 0.22, h * 0.20),
      Offset(w * 0.22, h * 0.20 + bLen),
      bracketPaint,
    );

    // Top-right bracket
    canvas.drawLine(
      Offset(w * 0.78, h * 0.20),
      Offset(w * 0.78 - bLen, h * 0.20),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(w * 0.78, h * 0.20),
      Offset(w * 0.78, h * 0.20 + bLen),
      bracketPaint,
    );

    // Bottom-left bracket
    canvas.drawLine(
      Offset(w * 0.22, h * 0.80),
      Offset(w * 0.22 + bLen, h * 0.80),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(w * 0.22, h * 0.80),
      Offset(w * 0.22, h * 0.80 - bLen),
      bracketPaint,
    );

    // Bottom-right bracket
    canvas.drawLine(
      Offset(w * 0.78, h * 0.80),
      Offset(w * 0.78 - bLen, h * 0.80),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(w * 0.78, h * 0.80),
      Offset(w * 0.78, h * 0.80 - bLen),
      bracketPaint,
    );

    // Scan line beam across center
    final scanLinePaint = Paint()
      ..color =
          (isDark ? AppColors.primaryActionDark : AppColors.primaryActionLight)
              .withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(w * 0.20, h * 0.50),
      Offset(w * 0.80, h * 0.50),
      scanLinePaint,
    );

    // Subtle scan beam gradient glow
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          (isDark ? AppColors.primaryActionDark : AppColors.primaryActionLight)
              .withValues(alpha: 0.25),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(w * 0.20, h * 0.40, w * 0.60, h * 0.10));
    canvas.drawRect(
      Rect.fromLTWH(w * 0.20, h * 0.40, w * 0.60, h * 0.10),
      glowPaint,
    );

    // Extracted text blocks below beam
    final textPaint = Paint()
      ..color = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)
      ..style = PaintingStyle.fill;

    // Line 1
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.28, h * 0.58, w * 0.44, h * 0.05),
        const Radius.circular(3),
      ),
      textPaint,
    );

    // Line 2
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.28, h * 0.66, w * 0.36, h * 0.05),
        const Radius.circular(3),
      ),
      textPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TextExtractionPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

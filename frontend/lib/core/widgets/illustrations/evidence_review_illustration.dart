import 'package:flutter/material.dart';
import 'package:trustcue_mobile/core/theme/app_colors.dart';

/// A code-native vector illustration depicting message review with highlighted evidence.
///
/// Fully offline, resolution-independent, and adapts dynamically to light/dark theme.
class EvidenceReviewIllustration extends StatelessWidget {
  const EvidenceReviewIllustration({
    super.key,
    this.width = 200,
    this.height = 120,
    this.semanticsLabel = 'Illustration of a message with highlighted evidence',
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
        painter: _EvidenceReviewPainter(isDark: isDark),
      ),
    );
  }
}

class _EvidenceReviewPainter extends CustomPainter {
  _EvidenceReviewPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background card / message bubble
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.84, h * 0.84),
      const Radius.circular(16),
    );

    final cardBgPaint = Paint()
      ..color = isDark ? const Color(0xFF1E2836) : const Color(0xFFE8EEF5)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(cardRect, cardBgPaint);

    final cardBorderPaint = Paint()
      ..color = isDark ? const Color(0xFF2C3E55) : const Color(0xFFD0DCEB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(cardRect, cardBorderPaint);

    // Sender avatar circle
    final avatarCenter = Offset(w * 0.22, h * 0.28);
    final avatarRadius = h * 0.12;
    final avatarPaint = Paint()
      ..color = isDark
          ? AppColors.primaryActionDark.withValues(alpha: 0.3)
          : AppColors.primaryActionLight.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(avatarCenter, avatarRadius, avatarPaint);

    final avatarIconPaint = Paint()
      ..color = isDark
          ? AppColors.primaryActionDark
          : AppColors.primaryActionLight
      ..style = PaintingStyle.fill;
    canvas.drawCircle(avatarCenter, avatarRadius * 0.5, avatarIconPaint);

    // Sender header bar
    final headerPaint = Paint()
      ..color = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.38, h * 0.24, w * 0.32, h * 0.08),
        const Radius.circular(4),
      ),
      headerPaint,
    );

    // Regular message line 1
    final textLinePaint = Paint()
      ..color = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.16, h * 0.46, w * 0.68, h * 0.07),
        const Radius.circular(3),
      ),
      textLinePaint,
    );

    // Highlighted evidence segment (Caution Amber)
    final highlightRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.16, h * 0.58, w * 0.52, h * 0.10),
      const Radius.circular(4),
    );
    final highlightPaint = Paint()
      ..color = isDark
          ? AppColors.cautionDark.withValues(alpha: 0.35)
          : AppColors.cautionLight.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(highlightRect, highlightPaint);

    final highlightBorder = Paint()
      ..color = isDark ? AppColors.cautionDark : AppColors.cautionLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(highlightRect, highlightBorder);

    // Underline / cue lens indicator
    final cueCircleCenter = Offset(w * 0.74, h * 0.63);
    final cueCirclePaint = Paint()
      ..color = isDark ? AppColors.cautionDark : AppColors.cautionLight
      ..style = PaintingStyle.fill;
    canvas.drawCircle(cueCircleCenter, h * 0.06, cueCirclePaint);

    final cueInnerPaint = Paint()
      ..color = isDark ? const Color(0xFF0E283F) : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(cueCircleCenter, h * 0.035, cueInnerPaint);

    // Trailing message line
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.16, h * 0.74, w * 0.40, h * 0.06),
        const Radius.circular(3),
      ),
      textLinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _EvidenceReviewPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

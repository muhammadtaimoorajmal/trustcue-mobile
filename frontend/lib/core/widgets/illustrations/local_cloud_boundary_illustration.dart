import 'package:flutter/material.dart';
import 'package:trustcue_mobile/core/theme/app_colors.dart';

/// A code-native vector illustration showing the explicit separation between
/// private on-device local analysis and optional consented cloud assistance.
///
/// Fully offline, resolution-independent, and adapts dynamically to light/dark theme.
class LocalCloudBoundaryIllustration extends StatelessWidget {
  const LocalCloudBoundaryIllustration({
    super.key,
    this.width = 240,
    this.height = 120,
    this.semanticsLabel = 'Illustration showing private on-device analysis separated from optional cloud features',
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
        painter: _LocalCloudBoundaryPainter(isDark: isDark),
      ),
    );
  }
}

class _LocalCloudBoundaryPainter extends CustomPainter {
  _LocalCloudBoundaryPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // LEFT: On-Device Sandbox Box
    final deviceRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.05, h * 0.12, w * 0.38, h * 0.76),
      const Radius.circular(12),
    );

    final deviceBg = Paint()
      ..color = isDark ? const Color(0xFF13202E) : const Color(0xFFE6EFF7)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(deviceRect, deviceBg);

    final deviceBorder = Paint()
      ..color = isDark
          ? AppColors.primaryActionDark
          : AppColors.primaryActionLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(deviceRect, deviceBorder);

    // On-device Shield / Lock Emblem
    final shieldCenter = Offset(w * 0.24, h * 0.44);
    final shieldRadius = h * 0.18;
    final shieldPaint = Paint()
      ..color =
          (isDark ? AppColors.primaryActionDark : AppColors.primaryActionLight)
              .withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(shieldCenter, shieldRadius, shieldPaint);

    final checkPaint = Paint()
      ..color = isDark
          ? AppColors.primaryActionDark
          : AppColors.primaryActionLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final checkPath = Path()
      ..moveTo(shieldCenter.dx - 8, shieldCenter.dy)
      ..lineTo(shieldCenter.dx - 2, shieldCenter.dy + 6)
      ..lineTo(shieldCenter.dx + 8, shieldCenter.dy - 6);
    canvas.drawPath(checkPath, checkPaint);

    // Mini local indicator bar below shield
    final localBarPaint = Paint()
      ..color = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, h * 0.72, w * 0.24, h * 0.05),
        const Radius.circular(2),
      ),
      localBarPaint,
    );

    // CENTER: Privacy Separation Boundary (Dotted Line & Keyhole Gate)
    final boundaryX = w * 0.49;
    final dottedPaint = Paint()
      ..color = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw vertical dotted line
    double curY = h * 0.15;
    while (curY < h * 0.85) {
      if (curY < h * 0.40 || curY > h * 0.60) {
        canvas.drawLine(
          Offset(boundaryX, curY),
          Offset(boundaryX, curY + 4),
          dottedPaint,
        );
      }
      curY += 8;
    }

    // Lock gate node in center of boundary
    final gateCenter = Offset(boundaryX, h * 0.50);
    final gateBg = Paint()
      ..color = isDark ? const Color(0xFF0E283F) : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(gateCenter, 11, gateBg);

    final gateBorder = Paint()
      ..color = isDark ? AppColors.cautionDark : AppColors.cautionLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(gateCenter, 11, gateBorder);

    // Small lock icon inside gate
    final lockPaint = Paint()
      ..color = isDark ? AppColors.cautionDark : AppColors.cautionLight
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(gateCenter.dx, gateCenter.dy + 2),
        width: 8,
        height: 6,
      ),
      lockPaint,
    );
    final shacklePaint = Paint()
      ..color = isDark ? AppColors.cautionDark : AppColors.cautionLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(gateCenter.dx, gateCenter.dy - 1),
        width: 6,
        height: 6,
      ),
      3.14159,
      3.14159,
      false,
      shacklePaint,
    );

    // RIGHT: Cloud AI Outline (Optional)
    final cloudBg = Paint()
      ..color = isDark ? const Color(0xFF1E2836) : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.fill;

    final cloudBorder = Paint()
      ..color = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Stylized cloud path
    final cloudPath = Path();
    final cx = w * 0.76;
    final cy = h * 0.50;
    cloudPath.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + 4),
          width: w * 0.32,
          height: h * 0.38,
        ),
        const Radius.circular(16),
      ),
    );
    canvas.drawPath(cloudPath, cloudBg);
    canvas.drawPath(cloudPath, cloudBorder);

    // Cloud sparkles/stars (subtle AI hint)
    final sparklePaint = Paint()
      ..color = isDark
          ? AppColors.primaryActionDark
          : AppColors.primaryActionLight
      ..style = PaintingStyle.fill;

    final s1 = Offset(cx - 10, cy - 2);
    canvas.drawCircle(s1, 2.5, sparklePaint);
    final s2 = Offset(cx + 8, cy + 6);
    canvas.drawCircle(s2, 2.0, sparklePaint);
    final s3 = Offset(cx + 12, cy - 8);
    canvas.drawCircle(s3, 3.0, sparklePaint);
  }

  @override
  bool shouldRepaint(covariant _LocalCloudBoundaryPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

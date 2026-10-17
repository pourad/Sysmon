// ════════════════════════════════════════════════════════════════════════════
// widgets/gauge.dart  —  گیج نیم‌دایره با درصد وسطش (قبلاً کلاس Gauge با tk.Canvas)
//
// استفاده:
//   GaugeWidget(pct: 63, warn: 70, crit: 85, size: 110)
//
// رنگ خودکار: زیر warn سبز، بین warn و crit زرد، بالای crit قرمز.
// برای عوض کردن ضخامت یا شکل کمان، _GaugePainter پایین رو ویرایش کن.
// ════════════════════════════════════════════════════════════════════════════
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config.dart';

class GaugeWidget extends StatelessWidget {
  const GaugeWidget({
    super.key,
    required this.pct,
    required this.warn,
    required this.crit,
    this.size = 110,
  });

  final double pct; // 0 تا 100
  final int warn;
  final int crit;
  final double size; // عرض گیج

  @override
  Widget build(BuildContext context) {
    final color = colorForValue(pct, warn, crit);
    return SizedBox(
      width: size,
      height: size / 2 + 24,
      child: Stack(
        children: [
          // کمان‌ها
          Positioned.fill(child: CustomPaint(painter: _GaugePainter(pct, color))),
          // عدد درصد
          Positioned(
            left: 0,
            right: 0,
            top: size / 2 - 8,
            child: Center(
              child: Text(
                '${pct.toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.pct, this.color);

  final double pct;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 10.0;
    final rect = Rect.fromLTWH(pad, pad, size.width - 2 * pad, size.width - 2 * pad);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 // ضخامت کمان
      ..strokeCap = StrokeCap.round
      ..color = AppColors.border2;

    // کمان پس‌زمینه: از چپ (180°) تا راست، از بالا
    canvas.drawArc(rect, math.pi, math.pi, false, track);

    // کمان رنگی به اندازه‌ی درصد
    final sweep = math.pi * pct.clamp(0.0, 100.0).toDouble() / 100;
    if (sweep > 0) {
      canvas.drawArc(rect, math.pi, sweep, false, track..color = color);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.pct != pct || old.color != color;
}

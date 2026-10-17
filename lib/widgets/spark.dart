// ════════════════════════════════════════════════════════════════════════════
// widgets/spark.dart  —  نمودار خطی کوچیک (قبلاً کلاس Spark)
//
// استفاده:
//   SparkWidget(data: monitor.cpuHistory, color: AppColors.ok, height: 80)
//
// maxValue = بالاترین عدد محور عمودی. برای درصد 100 (پیش‌فرض)،
// برای شبکه یک عدد بزرگ‌تر بده.
// ════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

class SparkWidget extends StatelessWidget {
  const SparkWidget({
    super.key,
    required this.data,
    required this.color,
    this.height = 80,
    this.maxValue = 100,
  });

  final List<double> data;
  final Color color;
  final double height;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SparkPainter(data, color, maxValue)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.data, this.color, this.maxValue);

  final List<double> data;
  final Color color;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final w = size.width;
    final h = size.height;

    double yOf(double v) =>
        h - 4 - (v / maxValue).clamp(0.0, 1.0).toDouble() * (h - 8);

    final line = Path();
    for (var i = 0; i < data.length; i++) {
      final x = i * (w - 1) / (data.length - 1);
      final y = yOf(data[i]);
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }

    // ناحیه‌ی کم‌رنگ زیر خط
    final area = Path.from(line)
      ..lineTo(w - 1, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withAlpha(40));

    // خط اصلی
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  // لیست داده درجا تغییر می‌کنه، پس همیشه دوباره بکش
  @override
  bool shouldRepaint(_SparkPainter old) => true;
}

// ════════════════════════════════════════════════════════════════════════════
// temp_tracker.dart  —  دمای یک قطعه رو لحظه‌ای دنبال می‌کنه و
// کمترین (min) ، بیشترین (max) و میانگین (avg) رو از لحظه‌ی باز شدن برنامه
// (یا آخرین Reset) نگه می‌داره.
// ════════════════════════════════════════════════════════════════════════════
import 'config.dart';

class TempTracker {
  TempTracker(this.id, this.label);

  final String id; // 'cpu' / 'gpu' / 'ssd'  (کلید توی JSON بک‌اند)
  final String label; // اسمی که توی صفحه نشون داده می‌شه

  double? current; // دمای الان (null = سنسور نداریم)
  double? min;
  double? max;
  double _sum = 0;
  int _count = 0;
  final List<double> history = []; // برای نمودار

  double? get avg => _count == 0 ? null : _sum / _count;

  /// هر tick یک بار صدا زده می‌شه
  void add(double? v) {
    current = v;
    if (v == null) return;
    min = (min == null || v < min!) ? v : min;
    max = (max == null || v > max!) ? v : max;
    _sum += v;
    _count++;
    history.add(v);
    if (history.length > kHistoryLen) history.removeAt(0);
  }

  void reset() {
    min = null;
    max = null;
    _sum = 0;
    _count = 0;
    history.clear();
  }
}

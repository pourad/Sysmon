// ════════════════════════════════════════════════════════════════════════════
// pages/temps_page.dart  —  دمای CPU / GPU / SSD  (لحظه‌ای + min / avg / max)
//
// ساختار صفحه:
//   ۱) سه کارت: دمای الان (بزرگ) + MIN / AVG / MAX
//   ۲) نمودار تاریخچه‌ی هر سه قطعه
//   ۳) اگه سنسوری پیدا نشد: راهنمای فعال کردنش
//
// داده‌ها از monitor.temps میاد (کلاس TempTracker توی temp_tracker.dart).
// ════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../config.dart';
import '../controller.dart';
import '../stats.dart';
import '../temp_tracker.dart';
import '../widgets/common.dart';
import '../widgets/spark.dart';

class TempsPage extends StatelessWidget {
  const TempsPage({super.key});

  /// رنگ دما: سبز / زرد / قرمز بر اساس kTempLimits (توی config.dart)
  Color _color(TempTracker t, double? v) {
    if (v == null) return AppColors.text3;
    final lim = kTempLimits[t.id]!;
    return colorForValue(v, lim[0], lim[1]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final Stats? s = monitor.stats;
        final trackers = monitor.temps.values.toList();
        final anyMissing = s != null && trackers.any((t) => t.current == null);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageTitle(
                'Temperatures',
                trailing: AppButton(
                  label: 'Reset min / avg / max',
                  icon: Icons.restart_alt,
                  color: AppColors.border2,
                  textColor: AppColors.text2,
                  onPressed: () => monitor.resetTempStats(),
                ),
              ),

              // سه کارت کنار هم
              CardRow(children: [
                for (final t in trackers) _tempCard(t, s?.tempSources[t.id]),
              ]),
              const SizedBox(height: 12),

              _historyCard(trackers),

              if (anyMissing) ...[
                const SizedBox(height: 12),
                _helpCard(s),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── کارت یک قطعه ──────────────────────────────────────────────────────────
  Widget _tempCard(TempTracker t, String? source) {
    final cur = t.current;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(t.label, style: AppText.caption),
          const SizedBox(height: 6),
          Text(
            cur == null ? 'N/A' : '${cur.toStringAsFixed(0)} °C',
            style: TextStyle(
                fontSize: 30, fontWeight: FontWeight.bold, color: _color(t, cur)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _mini('MIN', t.min),
              _mini('AVG', t.avg),
              _mini('MAX', t.max),
            ],
          ),
          const SizedBox(height: 8),
          Text(source == null ? '' : 'Source: $source', style: AppText.caption),
        ],
      ),
    );
  }

  /// یک ستون کوچیک: «MIN» بالا و عدد پایین
  Widget _mini(String label, double? v) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: AppText.caption),
          const SizedBox(height: 2),
          Text(v == null ? '—' : '${v.toStringAsFixed(1)}°', style: AppText.mono),
        ],
      ),
    );
  }

  // ── نمودار تاریخچه ────────────────────────────────────────────────────────
  Widget _historyCard(List<TempTracker> trackers) {
    return AppCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Text('Temperature history — last $kHistoryLen readings (0–100 °C)',
                style: AppText.caption),
          ),
          for (final t in trackers) ...[
            _historyRow(t),
            const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }

  Widget _historyRow(TempTracker t) {
    final color = _color(t, t.current);
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 8),
          child: SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.label, style: AppText.caption),
                const SizedBox(height: 2),
                Text(
                  t.current == null ? 'N/A' : '${t.current!.toStringAsFixed(0)}°',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SparkWidget(
              data: t.history, color: color, height: 60, maxValue: 100),
        ),
      ],
    );
  }

  // ── راهنما وقتی سنسوری پیدا نشده ──────────────────────────────────────────
  Widget _helpCard(Stats s) {
    final names = monitor.temps.values
        .where((t) => t.current == null)
        .map((t) => t.label)
        .join(', ');
    final text = s.lhmReachable
        ? 'LibreHardwareMonitor is connected, but it has no reading for: $names.\n'
            'Run it as Administrator (needed to read CPU sensors).'
        : 'No reading for: $names.\n'
            'Windows does not give programs these sensors directly. To enable them:\n'
            '  1. Run LibreHardwareMonitor as Administrator\n'
            '  2. Options → Remote Web Server → Run\n'
            '  3. Keep it open — this page fills in within a few seconds.';
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.warn),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppText.small)),
        ],
      ),
    );
  }
}

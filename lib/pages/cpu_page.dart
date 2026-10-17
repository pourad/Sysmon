// ════════════════════════════════════════════════════════════════════════════
// pages/cpu_page.dart  —  جزئیات CPU
// ════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../config.dart';
import '../controller.dart';
import '../stats.dart';
import '../widgets/common.dart';
import '../widgets/gauge.dart';
import '../widgets/spark.dart';

class CpuPage extends StatelessWidget {
  const CpuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final Stats? s = monitor.stats;
        final st = monitor.settings;
        final h = monitor.cpuHistory;
        final avg = h.isEmpty ? 0.0 : h.reduce((a, b) => a + b) / h.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageTitle('CPU Detail'),

              // گیج بزرگ + اطلاعات
              CardRow(children: [
                AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text('Usage', style: AppText.caption),
                      const SizedBox(height: 8),
                      GaugeWidget(
                          pct: s?.cpu ?? 0,
                          warn: st.cpuWarn,
                          crit: st.cpuCrit,
                          size: 140),
                      const SizedBox(height: 8),
                      Text('1-min avg: ${avg.toStringAsFixed(1)}%',
                          style: AppText.small),
                    ],
                  ),
                ),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      InfoRow('Frequency',
                          s == null ? '—' : '${s.freq.toStringAsFixed(0)} MHz'),
                      InfoRow('Cores (logical)', s == null ? '—' : '${s.logicalCores}'),
                      InfoRow('Cores (physical)', s == null ? '—' : '${s.physicalCores}'),
                      InfoRow('Processes', s == null ? '—' : '${s.procs}'),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // نمودار تاریخچه
              AppCard(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(4, 0, 4, 6),
                      child: Text('CPU history', style: AppText.caption),
                    ),
                    SparkWidget(data: h, color: AppColors.ok, height: 100),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // نوار هر هسته
              AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Per-core usage', style: AppText.caption),
                    const SizedBox(height: 6),
                    if (s != null)
                      for (var i = 0; i < s.cpuPerCore.length; i++)
                        _coreRow(i, s.cpuPerCore[i], st.cpuWarn, st.cpuCrit),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _coreRow(int index, double v, int warn, int crit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('C$index', textAlign: TextAlign.right, style: AppText.caption),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: BarMeter(fraction: v / 100, color: colorForValue(v, warn, crit)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text('${v.toStringAsFixed(0)}%', style: AppText.small),
          ),
        ],
      ),
    );
  }
}

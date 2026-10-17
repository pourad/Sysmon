// ════════════════════════════════════════════════════════════════════════════
// pages/ram_page.dart  —  جزئیات RAM + پروسه‌هایی که بیشترین RAM رو می‌خورن
// ════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../config.dart';
import '../controller.dart';
import '../stats.dart';
import '../widgets/common.dart';
import '../widgets/gauge.dart';
import '../widgets/spark.dart';

class RamPage extends StatelessWidget {
  const RamPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final Stats? s = monitor.stats;
        final st = monitor.settings;

        String gb(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)} GB';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageTitle('RAM Detail'),
              CardRow(children: [
                AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text('Usage', style: AppText.caption),
                      const SizedBox(height: 8),
                      GaugeWidget(
                          pct: s?.ramPct ?? 0,
                          warn: st.ramWarn,
                          crit: st.ramCrit,
                          size: 140),
                    ],
                  ),
                ),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      InfoRow('Total', gb(s?.ramTotal), labelWidth: 100),
                      InfoRow('Used', gb(s?.ramUsed), labelWidth: 100),
                      InfoRow('Available', gb(s?.ramAvail), labelWidth: 100),
                      InfoRow('Swap Used', gb(s?.swapUsed), labelWidth: 100),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(4, 0, 4, 6),
                      child: Text('RAM history', style: AppText.caption),
                    ),
                    SparkWidget(
                        data: monitor.ramHistory, color: AppColors.blue, height: 100),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // بیشترین مصرف RAM
              AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Top processes by RAM', style: AppText.caption),
                    const SizedBox(height: 6),
                    for (final p in monitor.topProcs) _procRow(p),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _procRow(ProcInfo p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 170,
            child: Text(p.name, overflow: TextOverflow.ellipsis, style: AppText.small),
          ),
          Expanded(child: BarMeter(fraction: p.pct / 10, color: AppColors.blue, height: 5)),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: Text('${p.pct.toStringAsFixed(1)}%', style: AppText.small),
          ),
        ],
      ),
    );
  }
}

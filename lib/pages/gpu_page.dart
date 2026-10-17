// ════════════════════════════════════════════════════════════════════════════
// pages/gpu_page.dart  —  جزئیات GPU
// ════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../config.dart';
import '../controller.dart';
import '../stats.dart';
import '../widgets/common.dart';
import '../widgets/gauge.dart';
import '../widgets/spark.dart';

class GpuPage extends StatelessWidget {
  const GpuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final Stats? s = monitor.stats;
        final st = monitor.settings;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageTitle('GPU Detail'),
              CardRow(children: [
                AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text('GPU Usage', style: AppText.caption),
                      const SizedBox(height: 8),
                      GaugeWidget(
                          pct: s?.gpu ?? 0,
                          warn: st.gpuWarn,
                          crit: st.gpuCrit,
                          size: 140),
                    ],
                  ),
                ),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      InfoRow('Temperature',
                          s?.gpuTemp == null ? '—' : '${s!.gpuTemp} °C',
                          labelWidth: 120),
                      InfoRow('Memory Used',
                          s?.gpuMemUsed == null
                              ? '—'
                              : '${s!.gpuMemUsed!.toStringAsFixed(1)} GB',
                          labelWidth: 120),
                      InfoRow('Memory Total',
                          s?.gpuMemTotal == null
                              ? '—'
                              : '${s!.gpuMemTotal!.toStringAsFixed(1)} GB',
                          labelWidth: 120),
                      InfoRow('Fan Speed',
                          s == null
                              ? '—'
                              : (s.gpuFan == null ? 'N/A' : '${s.gpuFan}%'),
                          labelWidth: 120),
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
                      child: Text('GPU history', style: AppText.caption),
                    ),
                    SparkWidget(
                        data: monitor.gpuHistory, color: AppColors.warn, height: 100),
                  ],
                ),
              ),
              if (s != null && !s.gpuAvailable)
                Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text(
                    'pynvml not available — install with:  pip install pynvml',
                    style: TextStyle(fontSize: 12, color: AppColors.crit),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

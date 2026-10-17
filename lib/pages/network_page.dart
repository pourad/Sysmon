// ════════════════════════════════════════════════════════════════════════════
// pages/network_page.dart  —  سرعت دانلود / آپلود
// ════════════════════════════════════════════════════════════════════════════
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config.dart';
import '../controller.dart';
import '../stats.dart';
import '../widgets/common.dart';
import '../widgets/spark.dart';

class NetworkPage extends StatelessWidget {
  const NetworkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final Stats? s = monitor.stats;

        // مقیاس نمودار شبکه: بزرگ‌ترین عدد تاریخچه (حداقل 10 Mbps)
        final all = [...monitor.netDownHistory, ...monitor.netUpHistory];
        final top = all.fold<double>(10, (a, b) => math.max(a, b));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageTitle('Network Detail'),
              CardRow(children: [
                _speedCard('▼  DOWNLOAD', AppColors.blue, s?.netDown),
                _speedCard('▲  UPLOAD', AppColors.ok, s?.netUp),
              ]),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(4, 0, 4, 6),
                      child: Text('Download (blue) / Upload (green) — last 60s',
                          style: AppText.caption),
                    ),
                    SparkWidget(
                        data: monitor.netDownHistory,
                        color: AppColors.blue,
                        height: 70,
                        maxValue: top),
                    const SizedBox(height: 2),
                    SparkWidget(
                        data: monitor.netUpHistory,
                        color: AppColors.ok,
                        height: 70,
                        maxValue: top),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    InfoRow('Total Downloaded',
                        s == null ? '—' : '${s.netTotalDown.toStringAsFixed(2)} GB',
                        labelWidth: 160),
                    InfoRow('Total Uploaded',
                        s == null ? '—' : '${s.netTotalUp.toStringAsFixed(2)} GB',
                        labelWidth: 160),
                    InfoRow('Active Interface', s?.netIface ?? '—', labelWidth: 160),
                    InfoRow(
                        'Packets Sent/Recv',
                        s == null
                            ? '—'
                            : '${fmtInt(s.packetsSent)} / ${fmtInt(s.packetsRecv)}',
                        labelWidth: 160),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _speedCard(String title, Color color, double? mbps) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 11, color: color)),
          const SizedBox(height: 6),
          Text(
            (mbps ?? 0).toStringAsFixed(1),
            style: TextStyle(
                fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.text1),
          ),
          const SizedBox(height: 4),
          Text('Mbps', style: AppText.caption),
        ],
      ),
    );
  }
}

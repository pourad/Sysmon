// ════════════════════════════════════════════════════════════════════════════
// pages/dashboard_page.dart  —  صفحه‌ی اصلی
//
// ساختار صفحه از بالا به پایین (هر بخش یک تابع جداست، پایین‌تر پیداش می‌کنی):
//   _topBar()      تیتر + ساعت + Live
//   _sparkCard()   سه نمودار CPU / GPU / RAM
//   گیج‌ها         سه کارت گیج
//   کارت‌های آمار  CPU Freq / GPU Temp / RAM Used / Disk W
//   _watchCard()   نظارت روی پروسه
//   ⭐ جای دکمه‌ی خودت (آخر لیست children)
//
// ListenableBuilder یعنی: «هر وقت monitor عوض شد، این بخش رو دوباره بساز».
// ════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../config.dart';
import '../controller.dart';
import '../stats.dart';
import '../widgets/common.dart';
import '../widgets/gauge.dart';
import '../widgets/spark.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // کنترلر کادر متن (برای خوندن چیزی که کاربر تایپ کرده)
  final _procCtrl = TextEditingController();

  @override
  void dispose() {
    _procCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final Stats? s = monitor.stats; // قبل از اولین پاسخ null هست
        final st = monitor.settings;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBar(),
              const SizedBox(height: 12),
              _sparkCard(s),
              const SizedBox(height: 12),

              // سه گیج کنار هم
              CardRow(children: [
                _gaugeCard('CPU', s?.cpu ?? 0, st.cpuWarn, st.cpuCrit),
                _gaugeCard('GPU', s?.gpu ?? 0, st.gpuWarn, st.gpuCrit),
                _gaugeCard('RAM', s?.ramPct ?? 0, st.ramWarn, st.ramCrit),
              ]),
              const SizedBox(height: 12),

              // چهار کارت آمار
              CardRow(children: [
                StatCard(
                    label: 'CPU Freq',
                    value: s == null ? '—' : '${s.freq.toStringAsFixed(0)} MHz'),
                StatCard(
                    label: 'GPU Temp',
                    value: s?.gpuTemp == null ? 'N/A' : '${s!.gpuTemp} °C'),
                StatCard(
                    label: 'RAM Used',
                    value: s == null ? '—' : '${s.ramUsed.toStringAsFixed(1)} GB'),
                StatCard(
                    label: 'Disk W',
                    value: s == null ? '—' : '${s.diskWrite.toStringAsFixed(1)} MB/s'),
              ]),
              const SizedBox(height: 12),

              _watchCard(),

              // ┌──────────────────────────────────────────────────────────┐
              // │ ⭐ دکمه‌ی خودت رو این پایین اضافه کن. مثال:               │
              // │                                                          │
              // │   const SizedBox(height: 12),                            │
              // │   AppButton(                                             │
              // │     label: 'پاک کردن لاگ',                                │
              // │     icon: Icons.delete,                                  │
              // │     onPressed: () => monitor.clearEvents(),              │
              // │   ),                                                     │
              // └──────────────────────────────────────────────────────────┘
            ],
          ),
        );
      },
    );
  }

  // ── بخش‌ها ────────────────────────────────────────────────────────────────

  Widget _topBar() {
    final clock = DateTime.now().toString().substring(11, 19);
    final live = monitor.connected;
    return Row(
      children: [
        Text('Dashboard', style: AppText.title),
        const Spacer(),
        Text(clock, style: AppText.caption),
        const SizedBox(width: 12),
        Text(
          live ? '● Live' : '● Offline',
          style: TextStyle(fontSize: 12, color: live ? AppColors.ok : AppColors.crit),
        ),
      ],
    );
  }

  Widget _sparkCard(Stats? s) {
    return AppCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Text('⚠ last 60s', style: AppText.caption),
          ),
          _sparkRow('CPU', s == null ? '—' : '${s.cpu.toStringAsFixed(0)}%',
              monitor.cpuHistory, AppColors.ok, 80),
          const SizedBox(height: 2),
          _sparkRow('GPU', s?.gpu == null ? 'N/A' : '${s!.gpu!.toStringAsFixed(0)}%',
              monitor.gpuHistory, AppColors.warn, 60),
          const SizedBox(height: 2),
          _sparkRow('RAM', s == null ? '—' : '${s.ramPct.toStringAsFixed(0)}%',
              monitor.ramHistory, AppColors.blue, 60),
        ],
      ),
    );
  }

  /// یک ردیف: اسم + مقدار فعلی (سمت چپ) و نمودار (سمت راست)
  Widget _sparkRow(String name, String value, List<double> data, Color color,
      double height) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 8),
          child: SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppText.caption),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ),
        Expanded(child: SparkWidget(data: data, color: color, height: height)),
      ],
    );
  }

  Widget _gaugeCard(String name, double pct, int warn, int crit) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(name, style: AppText.caption),
          const SizedBox(height: 6),
          GaugeWidget(pct: pct, warn: warn, crit: crit, size: 100),
        ],
      ),
    );
  }

  Widget _watchCard() {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          Text('Watch process:', style: AppText.small),
          SizedBox(
            width: 170,
            child: TextField(
              controller: _procCtrl,
              style: AppText.mono,
              decoration: inputDecoration('name or PID'),
              onSubmitted: (v) => monitor.setWatch(v), // Enter = Watch
            ),
          ),
          AppButton(label: 'Watch', onPressed: () => monitor.setWatch(_procCtrl.text)),
          Text(monitor.watchText,
              style: TextStyle(fontSize: 12, color: monitor.watchColor)),
          // دکمه‌ی ✕ فقط وقتی نظارت فعاله دیده می‌شه
          if (monitor.isWatching)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              color: AppColors.text3,
              hoverColor: AppColors.crit.withAlpha(40),
              onPressed: () {
                monitor.clearWatch();
                _procCtrl.clear();
              },
            ),
        ],
      ),
    );
  }
}

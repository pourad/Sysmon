// ════════════════════════════════════════════════════════════════════════════
// widgets/net_test_card.dart  —  کارت «Internet quality test» توی صفحه‌ی Network
//
//   [Start test]   (•) Quick  ( ) Full
//   ━━━━━━━━━━━━━━━━ 48%   Download 10 MB (2/6)
//   [Download] [Upload] [Latency] [Jitter] [Loaded ↓] [Loaded ↑] [UDP loss]
//   Network quality:  Streaming · Gaming · Video calls · Browsing
//
// منطق: net_quality.dart  ←  بک‌اند: backend/netquality.py
// ════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../config.dart';
import '../net_quality.dart';
import 'common.dart';

class NetTestCard extends StatelessWidget {
  const NetTestCard({super.key});

  // ── کمک‌ها ────────────────────────────────────────────────────────────────
  String _n(dynamic v, {int d = 1}) => v is num ? v.toStringAsFixed(d) : '—';

  /// سطح کیفیت (0 تا 4) → رنگ
  Color _levelColor(int lvl) {
    if (lvl >= 3) return AppColors.ok;
    if (lvl == 2) return AppColors.warn;
    return AppColors.crit;
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: netQuality,
      builder: (context, _) {
        final running = netQuality.running;
        final res = netQuality.result;
        // موقع تست: مقدارهای لحظه‌ای ؛ بعد از تست: نتیجه‌ی نهایی
        final Map<String, dynamic> m =
            running ? netQuality.live : (res ?? netQuality.live);
        final showMetrics = running || res != null;

        return AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Internet quality test', style: AppText.small),
              const SizedBox(height: 4),
              Text(
                  'Speed, delay and stability — measured the same way as Cloudflare\'s speed test.',
                  style: AppText.caption),
              const SizedBox(height: 12),

              // دکمه‌ی شروع / لغو + انتخاب حالت
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  AppButton(
                    label: running ? 'Cancel' : 'Start test',
                    icon: running ? Icons.stop : Icons.speed,
                    color: running ? AppColors.crit : AppColors.blue,
                    onPressed:
                        running ? () => netQuality.cancel() : () => netQuality.start(),
                  ),
                  _modeButton('Quick', 'quick', '≈ 25 s · up to ~100 MB', running),
                  _modeButton('Full', 'full', '≈ 1 min · up to ~1 GB on very fast lines', running),
                ],
              ),

              // نوار پیشرفت
              if (running) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: BarMeter(
                          fraction: netQuality.progress,
                          color: AppColors.blue,
                          height: 8),
                    ),
                    const SizedBox(width: 10),
                    Text('${(netQuality.progress * 100).round()}%',
                        style: AppText.small),
                  ],
                ),
                const SizedBox(height: 6),
                Text(netQuality.phase, style: AppText.caption),
              ],

              // خطا / لغو
              if (!running && netQuality.message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(netQuality.message,
                    style: TextStyle(
                        fontSize: 12,
                        color: netQuality.state == 'error'
                            ? AppColors.crit
                            : AppColors.text2)),
              ],

              // عددها
              if (showMetrics) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _tile('DOWNLOAD', _n(m['download_mbps']), 'Mbps'),
                    _tile('UPLOAD', _n(m['upload_mbps']), 'Mbps'),
                    _tile('LATENCY', _n(m['latency_ms']), 'ms'),
                    _tile('JITTER', _n(m['jitter_ms']), 'ms'),
                    _tile('LOADED  ▼', _n(m['loaded_down_ms']), 'ms'),
                    _tile('LOADED  ▲', _n(m['loaded_up_ms']), 'ms'),
                    _tile('UDP LOSS', _n(m['loss_pct'], d: 1), '%'),
                  ],
                ),
              ],

              // امتیاز کاربردها
              if (!running && res != null) ..._scores(res),
            ],
          ),
        );
      },
    );
  }

  // ── بخش‌ها ────────────────────────────────────────────────────────────────
  Widget _modeButton(String label, String value, String hint, bool disabled) {
    final selected = netQuality.mode == value;
    return Tooltip(
      message: hint,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: disabled ? null : () => netQuality.setMode(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.navActive : Colors.transparent,
            border: Border.all(color: selected ? AppColors.blue : AppColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: selected ? AppColors.text1 : AppColors.text2)),
              Text(hint, style: AppText.caption),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(String label, String value, String unit) {
    return Container(
      width: 138,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.border2,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.caption),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppText.value),
              const SizedBox(width: 4),
              Text(unit, style: AppText.caption),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _scores(Map<String, dynamic> res) {
    final scores = (res['scores'] as Map?)?.cast<String, dynamic>() ?? {};
    const names = {
      'streaming': 'Streaming',
      'gaming': 'Gaming',
      'video_calls': 'Video calls',
      'browsing': 'Web browsing',
    };
    final chips = <Widget>[];
    names.forEach((key, title) {
      final s = scores[key];
      if (s is! Map) return;
      final lvl = (s['level'] as num?)?.toInt() ?? 0;
      final color = _levelColor(lvl);
      chips.add(Container(
        width: 138,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: color.withAlpha(120)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.caption),
            const SizedBox(height: 4),
            Text(_cap((s['label'] as String?) ?? ''),
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text('limited by ${s['limit']}', style: AppText.caption),
          ],
        ),
      ));
    });

    final warnings = (res['warnings'] as List?)?.cast<dynamic>() ?? const [];
    final usedMb =
        (((res['bytes_down'] as num?) ?? 0) + ((res['bytes_up'] as num?) ?? 0)) / 1e6;
    final server = res['server'];

    return [
      const SizedBox(height: 16),
      Text('Network quality', style: AppText.small),
      const SizedBox(height: 8),
      Wrap(spacing: 10, runSpacing: 10, children: chips),
      const SizedBox(height: 12),
      if (warnings.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(warnings.join(' · '),
              style: TextStyle(fontSize: 11, color: AppColors.warn)),
        ),
      Text(
        '${_cap('${res['mode']}')} test · ${res['duration_s']} s · '
        '${usedMb.toStringAsFixed(0)} MB used'
        '${server != null ? ' · Cloudflare $server' : ''} · ${res['finished_at']}',
        style: AppText.caption,
      ),
      const SizedBox(height: 2),
      Text(
          'Ratings are estimates based on SysMon\'s own thresholds. UDP loss is measured against 1.1.1.1.',
          style: AppText.caption),
    ];
  }
}

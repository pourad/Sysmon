// ════════════════════════════════════════════════════════════════════════════
// pages/settings_page.dart  —  تنظیمات آستانه‌ها و لاگ
//
// نکته: اسلایدرها روی یک «پیش‌نویس» (draft) کار می‌کنن و فقط وقتی
// Apply & Save رو بزنی به برنامه اعمال می‌شن (مثل برنامه‌ی قبلی).
// ════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../config.dart';
import '../controller.dart';
import '../gaming.dart';
import '../widgets/common.dart';
import '../widgets/update_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // کپی از تنظیمات فعلی؛ اسلایدرها این رو تغییر می‌دن
  Settings draft = monitor.settings.copy();
  GamingSettings gDraft = monitor.gaming.copy(); // پیش‌نویس آستانه‌های حالت گیمینگ

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder: با عوض شدن تم، این صفحه هم رنگ‌هاش رو آپدیت کنه
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) => _content(),
    );
  }

  Widget _content() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageTitle('Settings'),

          // ── حالت گیمینگ ───────────────────────────────────────────────────
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sports_esports, size: 18, color: AppColors.blue),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Gaming mode', style: AppText.body)),
                    // سوییچ فوراً اعمال می‌شه (بدون Apply)
                    Switch(
                      value: monitor.gaming.enabled,
                      activeTrackColor: AppColors.ok,
                      onChanged: (v) => monitor.setGamingEnabled(v),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    'While you play, SysMon uses the higher limits below instead of the normal '
                    'alert thresholds, so a heavy game does not cause false alarms or fill the log. '
                    'Alerts are not switched off: crossing these limits still shows a banner.',
                    style: AppText.caption),
                const SizedBox(height: 10),
                Text('Limits in gaming mode (%)', style: AppText.small),
                const SizedBox(height: 6),
                _slider('CPU warn (gaming)', gDraft.cpuWarn, 10, 100, (v) => gDraft.cpuWarn = v),
                _slider('CPU critical (gaming)', gDraft.cpuCrit, 10, 100, (v) => gDraft.cpuCrit = v),
                _slider('RAM warn (gaming)', gDraft.ramWarn, 10, 100, (v) => gDraft.ramWarn = v),
                _slider('RAM critical (gaming)', gDraft.ramCrit, 10, 100, (v) => gDraft.ramCrit = v),
                _slider('GPU warn (gaming)', gDraft.gpuWarn, 10, 100, (v) => gDraft.gpuWarn = v),
                _slider('GPU critical (gaming)', gDraft.gpuCrit, 10, 100, (v) => gDraft.gpuCrit = v),
                const SizedBox(height: 4),
                Text(
                    'In gaming mode only the critical limits are written to the log, and GPU '
                    'temperature is logged from ${kLogGpuTemp + kGamingLogTempBonus} °C instead of $kLogGpuTemp °C.',
                    style: AppText.caption),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── آستانه‌های هشدار ─────────────────────────────────────────────
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alert thresholds (%)', style: AppText.small),
                const SizedBox(height: 6),
                _slider('CPU warn', draft.cpuWarn, 10, 100, (v) => draft.cpuWarn = v),
                _slider('CPU critical', draft.cpuCrit, 10, 100, (v) => draft.cpuCrit = v),
                _slider('RAM warn', draft.ramWarn, 10, 100, (v) => draft.ramWarn = v),
                _slider('RAM critical', draft.ramCrit, 10, 100, (v) => draft.ramCrit = v),
                _slider('GPU warn', draft.gpuWarn, 10, 100, (v) => draft.gpuWarn = v),
                _slider('GPU critical', draft.gpuCrit, 10, 100, (v) => draft.gpuCrit = v),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── لاگ ──────────────────────────────────────────────────────────
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Logging', style: AppText.small),
                const SizedBox(height: 6),
                _slider('Log when CPU >', draft.logCpu, 1, 100, (v) => draft.logCpu = v),
                _slider('Log when GPU >', draft.logGpu, 1, 100, (v) => draft.logGpu = v),
                _slider('Alert cooldown (s)', draft.cooldown, 1, 100, (v) => draft.cooldown = v),
                _slider('Refresh interval (s)', draft.intervalSec, 1, 100,
                    (v) => draft.intervalSec = v),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton(
                label: 'Apply & Save',
                color: AppColors.ok,
                textColor: AppColors.bg,
                onPressed: () {
                  monitor.applySettings(draft);
                  monitor.applyGaming(gDraft);
                },
              ),
              // ⭐ برگشت به تنظیمات پیش‌فرض: هم اسلایدرها هم برنامه ریست می‌شن
              AppButton(
                label: 'Reset to defaults',
                icon: Icons.restore,
                color: AppColors.border2,
                textColor: AppColors.text2,
                onPressed: _confirmReset, // اول می‌پرسه «مطمئنی؟»
              ),
            ],
          ),

          // ── آپدیت ────────────────────────────────────────────────────────
          const SizedBox(height: 24),
          // عمداً بدون const تا با عوض شدن تم (تیره/روشن) رنگش هم آپدیت بشه
          UpdateCard(),
        ],
      ),
    );
  }

  /// پنجره‌ی تأیید قبل از ریست. فقط اگه کاربر Reset رو بزنه ریست انجام می‌شه.
  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Reset to defaults?', style: AppText.title),
        content: Text(
          'All the settings you changed will be lost and the default values will be restored.',
          style: AppText.small,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // false = انصراف
            child: Text('Cancel', style: TextStyle(color: AppColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), // true = تأیید
            child: Text('Reset', style: TextStyle(color: AppColors.crit)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      monitor.resetSettings();
      setState(() {
        draft = Settings();
        gDraft = monitor.gaming.copy();
      });
    }
  }

  /// یک اسلایدر. setter می‌گه مقدار جدید توی کدوم فیلد draft ذخیره بشه.
  Widget _slider(String label, int value, int min, int max, void Function(int) setter) {
    return LabeledSlider(
      label: label,
      value: value,
      min: min,
      max: max,
      onChanged: (v) => setState(() => setter(v)),
    );
  }
}

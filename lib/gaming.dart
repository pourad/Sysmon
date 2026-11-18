// ════════════════════════════════════════════════════════════════════════════
// gaming.dart  —  تنظیمات «حالت گیمینگ»
//
// وقتی روشنه، به‌جای آستانه‌های عادی (Settings ← Alert thresholds) از این آستانه‌های
// بالاتر استفاده می‌شه تا یک بازی سنگین (که RAM و CPU رو زیاد مصرف می‌کنه) هشدار
// الکی و لاگ اضافه تولید نکنه. هشدارها خاموش نمی‌شن: اگه مصرف از همین حدها هم رد بشه،
// بنر هشدار میاد.
//
// کنترلر (controller.dart) این رو نگه می‌داره و با monitor.active آستانه‌ی «فعلی» رو می‌ده.
// ════════════════════════════════════════════════════════════════════════════

class GamingSettings {
  bool enabled; // حالت گیمینگ روشنه؟
  int cpuWarn, cpuCrit;
  int ramWarn, ramCrit;
  int gpuWarn, gpuCrit; // بازی‌ها GPU رو تا ۱۰۰٪ می‌برن، پس پیش‌فرض عملاً هشداری نمی‌ده

  GamingSettings({
    this.enabled = false,
    this.cpuWarn = 90,
    this.cpuCrit = 97,
    this.ramWarn = 90,
    this.ramCrit = 96,
    this.gpuWarn = 98,
    this.gpuCrit = 100,
  });

  GamingSettings copy() => GamingSettings(
        enabled: enabled,
        cpuWarn: cpuWarn,
        cpuCrit: cpuCrit,
        ramWarn: ramWarn,
        ramCrit: ramCrit,
        gpuWarn: gpuWarn,
        gpuCrit: gpuCrit,
      );
}

/// توی حالت گیمینگ، دمای GPU برای ثبت توی لاگ این‌قدر بالاتر از حد عادی (kLogGpuTemp) می‌شه
/// (کارت گرافیک زیر بار بازی طبیعیه که داغ‌تر باشه)
const int kGamingLogTempBonus = 7;

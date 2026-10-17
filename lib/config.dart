// ════════════════════════════════════════════════════════════════════════════
// config.dart  —  همه‌ی تنظیمات ثابت، رنگ‌ها و استایل متن‌ها اینجاست.
// اگه می‌خوای رنگ یا فونت کل برنامه رو عوض کنی، فقط همین فایل رو تغییر بده.
// ════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

/// آدرس بک‌اند پایتون.
///  • ویندوز/مک/لینوکس (دسکتاپ):  http://127.0.0.1:8765
///  • امولاتور اندروید:           http://10.0.2.2:8765
///  • گوشی واقعی: آی‌پی کامپیوتر (مثلاً http://192.168.1.5:8765)
///    و توی بک‌اند HOST رو "0.0.0.0" کن.
const String kBaseUrl = 'http://127.0.0.1:8765';

const String kAppVersion = '1.0.0';

/// ریپازیتوری گیت‌هاب برای آپدیت: 'نام‌کاربری/نام‌ریپو' (باید public باشه)
const String kGithubRepo = 'pourad/Sysmon';

/// چند نمونه توی نمودارها نگه داشته بشه (هر نمونه = یک tick)
const int kHistoryLen = 60;

/// اگه دمای GPU از این بیشتر شد توی فایل لاگ ثبت می‌شه
const int kLogGpuTemp = 80;

/// حد هشدار و بحرانی دما (°C) برای هر قطعه: [warn, crit]
/// رنگ دما (سبز / زرد / قرمز) از روی همین عددها تعیین می‌شه.
const Map<String, List<int>> kTempLimits = {
  'cpu': [75, 90],
  'gpu': [75, 85],
  'ssd': [55, 70],
};

/// صفحه‌های برنامه. ترتیب این‌ها = ترتیب منوی کناری.
enum AppTab { dashboard, cpu, gpu, ram, network, temps, log, settings }

// ── تم (تیره / روشن) ─────────────────────────────────────────────────────────
class AppTheme {
  /// true = تیره ، false = روشن. با monitor.toggleTheme() عوض می‌شه.
  static final ValueNotifier<bool> dark = ValueNotifier<bool>(true);
  static bool get isDark => dark.value;
}

// ── رنگ‌ها ───────────────────────────────────────────────────────────────────
// هر رنگ دو مقدار داره:  _p(رنگِ تیره, رنگِ روشن)
// برای عوض کردن یک رنگ، همون خط رو ویرایش کن.
// (فرمول هگزا: #D3DAD9  →  Color(0xFFD3DAD9) )
class AppColors {
  static Color _p(Color dark, Color light) => AppTheme.isDark ? dark : light;

   static Color get bg => _p(const Color(0xFF102151), const Color(0xFFD3DAD9)); // پس‌زمینه‌ی کل برنامه
  static Color get card => _p(const Color(0xFF1B2442), const Color(0xFFF3F6F6)); // کارت‌ها
  static Color get border => _p(const Color(0xFF30363D), const Color(0xFFB4BFBE));
  static Color get border2 => _p(const Color(0xFF21262D), const Color(0xFFE1E7E6));
  static Color get text1 => _p(const Color(0xFFE6EDF3), const Color(0xFF1B1F23)); // متن اصلی
  static Color get text2 => _p(const Color(0xFF8B949E), const Color(0xFF57606A)); // متن کم‌رنگ‌تر
  static Color get text3 => _p(const Color(0xFFE6EDF3), const Color(0xFF8C959F)); // متن خیلی کم‌رنگ
  static Color get ok => _p(const Color(0xFF3FB950), const Color(0xFF1A7F37)); // سبز
  static Color get warn => _p(const Color(0xFFD29922), const Color.fromARGB(255, 255, 202, 96)); // زرد
  static Color get crit => _p(const Color(0xFFF85149), const Color(0xFFCF222E)); // قرمز
  static Color get blue => _p(const Color(0xFF7965C1), const Color(0xFF0969DA));
  static Color get navActive => _p(const Color(0xFF21262D), const Color(0xFFE1E7E6));
}

/// بر اساس مقدار، رنگ سبز / زرد / قرمز برمی‌گردونه
Color colorForValue(double v, int warn, int crit) {
  if (v >= crit) return AppColors.crit;
  if (v >= warn) return AppColors.warn;
  return AppColors.ok;
}

// ── استایل متن‌ها ────────────────────────────────────────────────────────────
class AppText {
  static TextStyle get title =>
      TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text1);
  static TextStyle get body => TextStyle(fontSize: 13, color: AppColors.text1);
  static TextStyle get small => TextStyle(fontSize: 12, color: AppColors.text2);
  static TextStyle get caption => TextStyle(fontSize: 11, color: AppColors.text3);
  static TextStyle get value =>
      TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text1);
  static TextStyle get mono =>
      TextStyle(fontSize: 13, color: AppColors.text1, fontFamily: 'monospace');
}

// ── تنظیمات قابل‌تغییر توسط کاربر (صفحه‌ی Settings) ──────────────────────────
class Settings {
  int cpuWarn, cpuCrit;
  int ramWarn, ramCrit;
  int gpuWarn, gpuCrit;
  int logCpu, logRam, logGpu; // بالاتر از این عدد توی فایل لاگ ثبت می‌شه
  int cooldown; // حداقل فاصله‌ی دو هشدار (ثانیه)
  int intervalSec; // هر چند ثانیه آمار گرفته بشه

  Settings({
    this.cpuWarn = 70,
    this.cpuCrit = 85,
    this.ramWarn = 70,
    this.ramCrit = 85,
    this.gpuWarn = 70,
    this.gpuCrit = 85,
    this.logCpu = 80,
    this.logRam = 80, // توی برنامه‌ی قبلی اسلایدر نداشت
    this.logGpu = 80,
    this.cooldown = 30,
    this.intervalSec = 1,
  });

  Settings copy() => Settings(
        cpuWarn: cpuWarn,
        cpuCrit: cpuCrit,
        ramWarn: ramWarn,
        ramCrit: ramCrit,
        gpuWarn: gpuWarn,
        gpuCrit: gpuCrit,
        logCpu: logCpu,
        logRam: logRam,
        logGpu: logGpu,
        cooldown: cooldown,
        intervalSec: intervalSec,
      );
}

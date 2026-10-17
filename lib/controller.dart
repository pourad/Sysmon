// ════════════════════════════════════════════════════════════════════════════
// controller.dart  —  «مغز» برنامه. هیچ ظاهری اینجا نیست، فقط منطق.
//
// کارهایی که می‌کنه:
//   • هر چند ثانیه از بک‌اند آمار می‌گیره (_tick)
//   • تاریخچه‌ی نمودارها رو نگه می‌داره
//   • هشدار و بنر و لاگ رو مدیریت می‌کنه
//   • نظارت روی پروسه (Watch) رو انجام می‌ده
//
// هر وقت چیزی توی این کلاس عوض بشه و notifyListeners() صدا زده بشه،
// همه‌ی صفحه‌هایی که به `monitor` گوش می‌دن خودشون دوباره ساخته می‌شن.
//
// ⭐ برای اضافه کردن یک کار جدید به دکمه‌ات:
//    1) یک تابع توی همین کلاس بنویس
//    2) آخرش notifyListeners() بزن
//    3) توی دکمه بنویس:  onPressed: () => monitor.اسمتابع()
// ════════════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'api.dart';
import 'config.dart';
import 'stats.dart';
import 'temp_tracker.dart';

/// نوع پیام‌های لاگ (رنگشون توی صفحه‌ی Log فرق می‌کنه)
enum LogTag { info, ok, warn, crit, crash }

/// وضعیت نظارت بر پروسه (رنگ متنش از روی همین مشخص می‌شه)
enum WatchState { idle, ok, error }

class LogEvent {
  final String time;
  final String msg;
  final LogTag tag;
  LogEvent(this.time, this.msg, this.tag);
}

/// یک نمونه‌ی سراسری. توی هر صفحه می‌تونی بنویسی:  monitor.stats
final MonitorController monitor = MonitorController();

class MonitorController extends ChangeNotifier {
  final ApiService api = ApiService();

  // ── وضعیت (State) ─────────────────────────────────────────────────────────
  Settings settings = Settings(); // تنظیمات فعلی
  AppTab tab = AppTab.dashboard; // صفحه‌ی انتخاب‌شده
  Stats? stats; // آخرین آمار (قبل از اولین پاسخ null هست)
  bool connected = false; // به بک‌اند وصلیم؟
  List<ProcInfo> topProcs = []; // بیشترین مصرف RAM

  // تاریخچه برای نمودارها
  final List<double> cpuHistory = [];
  final List<double> ramHistory = [];
  final List<double> gpuHistory = [];
  final List<double> netDownHistory = [];
  final List<double> netUpHistory = [];

  // دمای قطعات (ترتیب = ترتیب کارت‌ها توی صفحه‌ی Temps)
  final Map<String, TempTracker> temps = {
    'cpu': TempTracker('cpu', 'CPU'),
    'gpu': TempTracker('gpu', 'GPU'),
    'ssd': TempTracker('ssd', 'SSD'),
  };

  // لاگ داخل برنامه
  final List<LogEvent> events = [];

  // بنر هشدار بالای صفحه
  String? bannerText;
  Color bannerColor = AppColors.warn;

  // نظارت بر پروسه
  int? watchedPid;
  String? watchedName;
  String watchText = 'Not watching.';
  WatchState watchState = WatchState.idle;
  // رنگ از روی وضعیت ساخته می‌شه تا با عوض شدن تم هم درست بمونه
  Color get watchColor {
    switch (watchState) {
      case WatchState.ok:
        return AppColors.ok;
      case WatchState.error:
        return AppColors.crit;
      case WatchState.idle:
        return AppColors.text3;
    }
  }

  bool get isWatching => watchedPid != null;

  // تم تیره / روشن
  bool get isDark => AppTheme.isDark;

  // ── داخلی ─────────────────────────────────────────────────────────────────
  Timer? _timer;
  Timer? _bannerTimer;
  bool _busy = false; // جلوگیری از دو درخواست هم‌زمان
  bool _failLogged = false;
  final Map<String, DateTime> _alertTs = {};

  // ══════════════════════════════════════════════════════════════════════════
  //  شروع / پایان
  // ══════════════════════════════════════════════════════════════════════════
  void start() {
    _restartTimer();
    Future.delayed(const Duration(milliseconds: 200), _tick);
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: settings.intervalSec), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bannerTimer?.cancel();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  تابع‌هایی که از دکمه‌ها صدا می‌زنی
  // ══════════════════════════════════════════════════════════════════════════

  /// ⭐ عوض کردن تم تیره/روشن (دکمه‌ی پایین منوی کناری)
  void toggleTheme() {
    AppTheme.dark.value = !AppTheme.dark.value; // خود MaterialApp رو آپدیت می‌کنه
    notifyListeners(); // بقیه‌ی صفحه‌ها رو آپدیت می‌کنه
  }

  /// صفر کردن min / avg / max دماها (دکمه‌ی Reset توی صفحه‌ی Temps)
  void resetTempStats() {
    for (final tracker in temps.values) {
      tracker.reset();
    }
    logEvent('Temperature min / avg / max reset.', LogTag.info);
  }

  /// عوض کردن صفحه
  void setTab(AppTab t) {
    tab = t;
    notifyListeners();
    if (t == AppTab.ram) _refreshTopProcs();
  }

  /// پاک کردن لاگ داخل برنامه (دکمه‌ی Clear)
  void clearEvents() {
    events.clear();
    notifyListeners();
  }

  /// باز کردن فایل monitor_log.txt (دکمه‌ی Open file)
  Future<void> openLogFile() async {
    try {
      await api.openLogFile();
    } catch (_) {}
  }

  /// ذخیره‌ی تنظیمات جدید (دکمه‌ی Apply & Save)
  void applySettings(Settings s) {
    settings = s.copy();
    _restartTimer();
    logEvent('Settings applied.', LogTag.ok);
    _fileLog('[SETTINGS] User updated thresholds.');
    notifyListeners();
  }

  /// برگشتن به تنظیمات پیش‌فرض (دکمه‌ی Reset to defaults)
  void resetSettings() {
    settings = Settings(); // یک نمونه‌ی تازه = همون مقدارهای پیش‌فرض config.dart
    _restartTimer();
    logEvent('Settings reset to defaults.', LogTag.info);
    _fileLog('[SETTINGS] User reset settings to defaults.');
    notifyListeners();
  }

  /// شروع نظارت روی پروسه (اسم یا PID)
  Future<void> setWatch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    try {
      final r = await api.setWatch(q);
      if (r['ok'] == true) {
        watchedPid = (r['pid'] as num).toInt();
        watchedName = r['name'] as String;
        watchText = 'Watching: $watchedName ($watchedPid)';
        watchState = WatchState.ok;
        logEvent('Watching: $watchedName (PID $watchedPid)', LogTag.ok);
        _fileLog('[WATCH] $watchedName PID $watchedPid');
      } else {
        watchedPid = null;
        watchedName = null;
        watchText = "'$q' not found.";
        watchState = WatchState.error;
      }
    } catch (_) {
      watchText = 'Backend not reachable.';
      watchState = WatchState.error;
    }
    notifyListeners();
  }

  /// توقف نظارت
  Future<void> clearWatch() async {
    if (watchedPid != null) {
      logEvent('Stopped watching: $watchedName (PID $watchedPid)', LogTag.info);
      _fileLog('[WATCH] Stopped watching: $watchedName (PID $watchedPid)');
    }
    watchedPid = null;
    watchedName = null;
    watchText = 'Not watching.';
    watchState = WatchState.idle;
    try {
      await api.clearWatch();
    } catch (_) {}
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ابزارهای داخلی
  // ══════════════════════════════════════════════════════════════════════════

  /// یک خط به لاگ داخل برنامه اضافه می‌کنه
  void logEvent(String msg, LogTag tag) {
    final t = DateTime.now().toString().substring(11, 19); // HH:MM:SS
    events.add(LogEvent(t, msg, tag));
    if (events.length > 500) events.removeAt(0);
    notifyListeners();
  }

  /// یک خط به فایل monitor_log.txt می‌نویسه (از طریق بک‌اند)
  void _fileLog(String msg) {
    api.writeLog(msg).catchError((_) {});
  }

  /// بنر بالای صفحه رو ۸ ثانیه نشون می‌ده
  void showBanner(String msg, Color color) {
    bannerText = msg;
    bannerColor = color;
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 8), () {
      bannerText = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void hideBanner() {
    _bannerTimer?.cancel();
    bannerText = null;
    notifyListeners();
  }

  void _push(List<double> list, double v) {
    list.add(v);
    if (list.length > kHistoryLen) list.removeAt(0);
  }

  /// جلوگیری از هشدارهای پشت‌سرهم (cooldown)
  bool _canAlert(String key) {
    final now = DateTime.now();
    final last = _alertTs[key];
    if (last == null || now.difference(last).inSeconds > settings.cooldown) {
      _alertTs[key] = now;
      return true;
    }
    return false;
  }

  void _alert(String msg) {
    showBanner(msg, AppColors.crit);
    logEvent(msg, LogTag.crit);
    _fileLog('[ALERT] $msg');
  }

  Future<void> _refreshTopProcs() async {
    try {
      topProcs = await api.fetchTopProcs();
      notifyListeners();
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  حلقه‌ی اصلی: هر چند ثانیه یک‌بار اجرا می‌شه
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    try {
      final s = await api.fetchStats();
      connected = true;
      _failLogged = false;
      stats = s;

      _push(cpuHistory, s.cpu);
      _push(ramHistory, s.ramPct);
      _push(gpuHistory, s.gpu ?? 0);
      _push(netDownHistory, math.min(s.netDown, 1000.0)); // سقف برای نمودار
      _push(netUpHistory, math.min(s.netUp, 1000.0));

      temps.forEach((id, tracker) => tracker.add(s.temps[id]));

      _checkAlerts(s);
      _checkWatch(s);
      if (tab == AppTab.ram) await _refreshTopProcs();
    } catch (e) {
      connected = false;
      if (!_failLogged) {
        _failLogged = true;
        logEvent('Backend not reachable — is monitor_backend.py running?',
            LogTag.warn);
      }
    }
    _busy = false;
    notifyListeners();
  }

  void _checkAlerts(Stats s) {
    final st = settings;
    final cpu = s.cpu;
    final ram = s.ramPct;
    final gpu = s.gpu ?? 0;

    if (cpu >= st.cpuCrit && _canAlert('cpu')) {
      _alert('CPU critical: ${cpu.toStringAsFixed(0)}%');
    } else if (cpu >= st.cpuWarn && _canAlert('cpu_w')) {
      logEvent('CPU warning: ${cpu.toStringAsFixed(0)}%', LogTag.warn);
    }

    if (ram >= st.ramCrit && _canAlert('ram')) {
      _alert('RAM critical: ${ram.toStringAsFixed(0)}%');
    }

    if (gpu > 0 && gpu >= st.gpuCrit && _canAlert('gpu')) {
      _alert('GPU critical: ${gpu.toStringAsFixed(0)}%');
    }

    // لاگ «فشار» توی فایل
    final reasons = <String>[];
    if (cpu >= st.logCpu) reasons.add('CPU=${cpu.toStringAsFixed(0)}%');
    if (ram >= st.logRam) reasons.add('RAM=${ram.toStringAsFixed(0)}%');
    if (gpu > 0 && gpu >= st.logGpu) reasons.add('GPU=${gpu.toStringAsFixed(0)}%');
    if (s.gpuTemp != null && s.gpuTemp! >= kLogGpuTemp) {
      reasons.add('GPU_T=${s.gpuTemp}°C');
    }
    if (reasons.isNotEmpty) _fileLog('[PRESSURE] ${reasons.join(', ')}');
  }

  /// اگه پروسه‌ای که نظارتش می‌کردیم بسته شده باشه
  void _checkWatch(Stats s) {
    if (watchedPid == null) return;
    final w = s.watch;
    if (w != null && !w.alive) {
      final msg = "CRASH: '$watchedName' (PID $watchedPid) closed.";
      watchText = '⚠  $msg';
      watchState = WatchState.error;
      showBanner(msg, AppColors.crit);
      logEvent(msg, LogTag.crash);
      _fileLog('[CRASH] $msg');
      watchedPid = null;
      watchedName = null;
      api.clearWatch().catchError((_) {});
    }
  }
}

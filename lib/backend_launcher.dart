// ════════════════════════════════════════════════════════════════════════════
// backend_launcher.dart  —  موقع اجرای نسخه‌ی .exe، بک‌اند پایتون رو خودش بالا میاره
// تا کاربر لازم نباشه کاری بکنه.
//
// • وقتی کنار برنامه پوشه‌ی  backend\monitor_backend.exe  باشه (بعد از build_release.bat)
//   اجراش می‌کنه.
// • موقع توسعه (flutter run) اون فایل نیست، پس هیچ کاری نمی‌کنه و تو خودت
//   python monitor_backend.py رو مثل قبل اجرا می‌کنی.
// • آرگومان --parent-pid باعث می‌شه با بسته شدن برنامه، بک‌اند هم خودش بسته بشه.
// ════════════════════════════════════════════════════════════════════════════
import 'dart:io';

class BackendLauncher {
  static Future<void> start() async {
    if (!Platform.isWindows) return;

    final appDir = File(Platform.resolvedExecutable).parent;
    final exe = File('${appDir.path}\\backend\\monitor_backend.exe');
    if (!exe.existsSync()) return; // حالت توسعه

    try {
      await Process.start(
        exe.path,
        ['--parent-pid', '$pid'], // pid = شماره‌ی پروسه‌ی همین برنامه
        workingDirectory: exe.parent.path,
        mode: ProcessStartMode.detached,
      );
    } catch (_) {
      // اگه اجرا نشد، برنامه Offline می‌مونه و توی Log پیغام می‌ده
    }
  }
}

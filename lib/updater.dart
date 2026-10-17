// ════════════════════════════════════════════════════════════════════════════
// updater.dart  —  بررسی و نصب آپدیت از GitHub Releases (بدون هیچ ظاهری)
//
// روش کار:
//   1) آخرین Release ریپازیتوری رو از GitHub می‌پرسه (check)
//   2) اگه شماره‌ی نسخه‌اش از kAppVersion بزرگ‌تر بود، فایل نصب‌کننده (.exe) رو
//      دانلود می‌کنه، سالم بودنش رو چک می‌کنه و اجراش می‌کنه (downloadAndInstall)
//   3) نصب‌کننده برنامه رو می‌بنده، نسخه‌ی جدید رو جایگزین می‌کنه و دوباره بازش می‌کنه
//
// ظاهرش توی widgets/update_card.dart است (توی صفحه‌ی Settings).
// راهنمای منتشر کردن آپدیت: BUILD.md ← «انتشار آپدیت»
// ════════════════════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

enum UpdateStatus { idle, checking, upToDate, available, downloading, installing, error }

/// اطلاعات نسخه‌ی جدیدی که پیدا شده
class UpdateInfo {
  UpdateInfo({
    required this.version,
    required this.notes,
    required this.assetName,
    required this.url,
    required this.size,
    required this.sha256,
  });

  final String version; // مثلاً v1.1.0
  final String notes; // توضیحات Release
  final String assetName; // اسم فایل نصب‌کننده
  final Uri url;
  final int size; // بایت (0 = نامعلوم)
  final String? sha256; // اگه GitHub بده، برای چک سالم بودن فایل
}

/// یک نمونه‌ی سراسری، مثل monitor
final Updater updater = Updater();

class Updater extends ChangeNotifier {
  UpdateStatus status = UpdateStatus.idle;
  String message = '';
  UpdateInfo? info;
  double progress = 0; // 0 تا 1 موقع دانلود

  bool get busy =>
      status == UpdateStatus.checking ||
      status == UpdateStatus.downloading ||
      status == UpdateStatus.installing;

  /// هنوز اسم ریپازیتوری رو توی config.dart ننوشتی؟
  bool get repoConfigured => !kGithubRepo.contains('YOUR_');

  void _set(UpdateStatus s, String msg) {
    status = s;
    message = msg;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ۱) بررسی نسخه‌ی جدید
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> check() async {
    if (busy) return;
    if (!repoConfigured) {
      _set(UpdateStatus.error, 'First set kGithubRepo in lib/config.dart.');
      return;
    }
    info = null;
    progress = 0;
    _set(UpdateStatus.checking, 'Checking for updates…');

    try {
      final r = await http.get(
        Uri.parse('https://api.github.com/repos/$kGithubRepo/releases/latest'),
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'SysMon-Updater',
        },
      ).timeout(const Duration(seconds: 15));

      if (r.statusCode == 404) {
        _set(UpdateStatus.error,
            'No release found. The repository must be public and have a published release.');
        return;
      }
      if (r.statusCode != 200) {
        _set(UpdateStatus.error, 'GitHub answered with error ${r.statusCode}.');
        return;
      }

      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final tag = (j['tag_name'] as String?) ?? '';

      if (!_isNewer(tag, kAppVersion)) {
        _set(UpdateStatus.upToDate, 'You have the latest version (v$kAppVersion).');
        return;
      }

      // فایل نصب‌کننده: اولین .exe ، و اگه اسمش «setup» داشت اون رو ترجیح بده
      Map<String, dynamic>? pick;
      for (final a in (j['assets'] as List?) ?? const []) {
        final m = a as Map<String, dynamic>;
        final name = ((m['name'] as String?) ?? '').toLowerCase();
        if (!name.endsWith('.exe')) continue;
        pick ??= m;
        if (name.contains('setup')) {
          pick = m;
          break;
        }
      }
      if (pick == null) {
        _set(UpdateStatus.error,
            'Version $tag exists, but its release has no .exe installer attached.');
        return;
      }

      var digest = pick['digest'] as String?;
      if (digest != null && digest.startsWith('sha256:')) {
        digest = digest.substring(7).toLowerCase();
      } else {
        digest = null;
      }

      var notes = ((j['body'] as String?) ?? '').trim();
      if (notes.length > 700) notes = '${notes.substring(0, 700)}…';

      info = UpdateInfo(
        version: tag,
        notes: notes,
        assetName: pick['name'] as String,
        url: Uri.parse(pick['browser_download_url'] as String),
        size: (pick['size'] as num?)?.toInt() ?? 0,
        sha256: digest,
      );
      _set(UpdateStatus.available,
          'Version $tag is available (you have v$kAppVersion).');
    } catch (e) {
      _set(UpdateStatus.error, 'Could not check for updates: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ۲) دانلود و نصب
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> downloadAndInstall() async {
    final i = info;
    if (i == null || status != UpdateStatus.available) return;

    if (!Platform.isWindows) {
      _set(UpdateStatus.error, 'Automatic install is only supported on Windows.');
      return;
    }
    // فقط از خود ریپازیتوری تو دانلود کن
    if (!i.url.toString().startsWith('https://github.com/$kGithubRepo/releases/download/')) {
      _set(UpdateStatus.error, 'Unexpected download address — update cancelled.');
      return;
    }

    progress = 0;
    _set(UpdateStatus.downloading, 'Downloading ${i.version}…');
    final client = http.Client();
    try {
      final dir = await Directory.systemTemp.createTemp('sysmon_update_');
      final file = File('${dir.path}\\${i.assetName}');

      final req = http.Request('GET', i.url)..headers['User-Agent'] = 'SysMon-Updater';
      final resp = await client.send(req);
      if (resp.statusCode != 200) {
        throw 'Download failed (error ${resp.statusCode}).';
      }

      final total = resp.contentLength ?? i.size;
      var received = 0;
      final sink = file.openWrite();
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          progress = received / total;
          notifyListeners();
        }
      }
      await sink.close();

      // چک سالم بودن فایل
      if (i.size > 0 && await file.length() != i.size) {
        throw 'The downloaded file is incomplete. Please try again.';
      }
      if (i.sha256 != null) {
        final digest = await sha256.bind(file.openRead()).first;
        if (digest.toString() != i.sha256) {
          throw 'Checksum mismatch — update cancelled for your safety.';
        }
      }

      // اجرای نصب‌کننده (با پنجره‌ی تأیید ویندوز). خود نصب‌کننده برنامه رو می‌بنده،
      // نسخه‌ی جدید رو نصب می‌کنه و دوباره بازش می‌کنه.
      _set(UpdateStatus.installing,
          'Installing — SysMon will close and restart by itself…');
      final path = file.path.replaceAll("'", "''");
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        "Start-Process -FilePath '$path' "
            "-ArgumentList '/SILENT','/CLOSEAPPLICATIONS','/FORCECLOSEAPPLICATIONS' "
            '-Verb RunAs -Wait',
      ]);

      // اگه به اینجا رسیدیم یعنی برنامه بسته نشد: یا کاربر پنجره‌ی ویندوز رو Cancel کرد
      // یا نصب‌کننده تموم شد ولی برنامه رو نبست.
      if (result.exitCode != 0) {
        throw 'The installer did not run (the Windows prompt was probably cancelled).';
      }
      _set(UpdateStatus.upToDate, 'Update installed. Please restart SysMon.');
    } catch (e) {
      info = null;
      _set(UpdateStatus.error, '$e');
    } finally {
      client.close();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  مقایسه‌ی شماره‌ی نسخه‌ها (v1.10.0 بزرگ‌تر از v1.9.0 حساب می‌شه)
  // ══════════════════════════════════════════════════════════════════════════
  List<int> _nums(String v) {
    final m = RegExp(r'\d+(\.\d+)*').firstMatch(v);
    if (m == null) return [];
    return m.group(0)!.split('.').map(int.parse).toList();
  }

  bool _isNewer(String remote, String local) {
    final a = _nums(remote);
    final b = _nums(local);
    if (a.isEmpty) return false;
    final n = math.max(a.length, b.length);
    for (var k = 0; k < n; k++) {
      final x = k < a.length ? a[k] : 0;
      final y = k < b.length ? b[k] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// net_quality.dart  —  کنترلر «تست کیفیت اینترنت» (بدون ظاهر)
//
// خود تست توی بک‌اند پایتون (netquality.py) انجام می‌شه. این‌جا فقط:
//   start()   شروع تست          cancel()  لغو تست
//   هر نیم ثانیه وضعیت رو می‌خونه (progress، سرعت لحظه‌ای، نتیجه‌ی نهایی)
//
// ظاهرش: widgets/net_test_card.dart (توی صفحه‌ی Network)
// ════════════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

/// یک نمونه‌ی سراسری، مثل monitor و updater
final NetQuality netQuality = NetQuality();

class NetQuality extends ChangeNotifier {
  String state = 'idle'; // idle / running / done / error / cancelled / unavailable
  String mode = 'quick'; // quick = سریع و کم‌حجم ، full = کامل (مثل Cloudflare)
  String phase = ''; // مثلاً «Download 10 MB (2/6)»
  double progress = 0; // 0 تا 1
  String message = ''; // متن خطا
  Map<String, dynamic> live = {}; // مقدارهای لحظه‌ای موقع تست
  Map<String, dynamic>? result; // آخرین نتیجه‌ی کامل (تا تست بعدی می‌مونه)

  Timer? _poll;

  bool get running => state == 'running';

  void setMode(String m) {
    if (running) return;
    mode = m;
    notifyListeners();
  }

  Future<void> start() async {
    if (running) return;
    try {
      final r = await http
          .post(Uri.parse('$kBaseUrl/nettest/start'), body: jsonEncode({'mode': mode}))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 404) {
        _fail('This backend has no network test. Update monitor_backend.py and add netquality.py next to it.');
        return;
      }
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      if (j['ok'] != true) {
        _fail((j['error'] as String?) ?? 'The test could not be started.');
        return;
      }
      state = 'running';
      phase = 'Starting…';
      progress = 0;
      live = {};
      message = '';
      notifyListeners();
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(milliseconds: 500), (_) => _refresh());
    } catch (_) {
      _fail('The backend is not reachable. Start it first.');
    }
  }

  Future<void> cancel() async {
    if (!running) return;
    try {
      await http
          .post(Uri.parse('$kBaseUrl/nettest/cancel'), body: '{}')
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
    await _refresh();
  }

  void _fail(String msg) {
    state = 'error';
    message = msg;
    notifyListeners();
  }

  Future<void> _refresh() async {
    try {
      final r = await http
          .get(Uri.parse('$kBaseUrl/nettest/status'))
          .timeout(const Duration(seconds: 4));
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      state = (j['state'] as String?) ?? state;
      phase = (j['phase'] as String?) ?? '';
      progress = ((j['progress'] as num?) ?? 0).toDouble();
      message = (j['message'] as String?) ?? '';
      live = (j['live'] as Map?)?.cast<String, dynamic>() ?? {};
      final res = j['result'];
      if (res is Map) result = res.cast<String, dynamic>();
      if (state != 'running') {
        _poll?.cancel();
        _poll = null;
      }
    } catch (_) {
      // یک پاسخ از دست رفت؛ نیم‌ثانیه‌ی بعد دوباره امتحان می‌کنیم
    }
    notifyListeners();
  }
}

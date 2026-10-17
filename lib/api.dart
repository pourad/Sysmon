// ════════════════════════════════════════════════════════════════════════════
// api.dart  —  تنها جایی که با بک‌اند پایتون حرف می‌زنیم.
// اگه بک‌اند یک آدرس جدید (endpoint) گرفت، تابعش رو اینجا اضافه کن.
// ════════════════════════════════════════════════════════════════════════════
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'stats.dart';

class ApiService {
  Uri _u(String path) => Uri.parse('$kBaseUrl$path');

  dynamic _decode(http.Response r) => jsonDecode(utf8.decode(r.bodyBytes));

  Future<Stats> fetchStats() async {
    final r = await http.get(_u('/stats')).timeout(const Duration(seconds: 5));
    return Stats.fromJson(_decode(r) as Map<String, dynamic>);
  }

  Future<List<ProcInfo>> fetchTopProcs() async {
    final r =
        await http.get(_u('/top-procs')).timeout(const Duration(seconds: 5));
    return (_decode(r) as List)
        .map((e) => ProcInfo(e['name'] as String, (e['pct'] as num).toDouble()))
        .toList();
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final r = await http
        .post(_u(path), body: jsonEncode(body))
        .timeout(const Duration(seconds: 5));
    return _decode(r) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setWatch(String query) =>
      _post('/watch', {'query': query});
  Future<void> clearWatch() => _post('/unwatch', {});
  Future<void> writeLog(String msg) => _post('/log', {'msg': msg});
  Future<void> openLogFile() => _post('/open-log', {});
}

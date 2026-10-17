// ════════════════════════════════════════════════════════════════════════════
// stats.dart  —  مدل داده. JSON که از پایتون میاد اینجا به یک شیء Dart تبدیل می‌شه.
// توی صفحه‌ها می‌نویسی:  s.cpu ،  s.ramUsed ،  s.gpuTemp  و ...
// ════════════════════════════════════════════════════════════════════════════

double _d(dynamic x) => (x as num).toDouble();
double? _dn(dynamic x) => x == null ? null : (x as num).toDouble();
int? _in(dynamic x) => x == null ? null : (x as num).toInt();

Map<String, double?> _tempMap(dynamic m) {
  final out = <String, double?>{};
  if (m is Map) m.forEach((k, v) => out[k as String] = _dn(v));
  return out;
}

Map<String, String?> _strMap(dynamic m) {
  final out = <String, String?>{};
  if (m is Map) m.forEach((k, v) => out[k as String] = v as String?);
  return out;
}

/// اطلاعات پروسه‌ای که داریم نظارتش می‌کنیم
class WatchInfo {
  final int pid;
  final String name;
  final bool alive;
  WatchInfo(this.pid, this.name, this.alive);
}

/// یک ردیف از «بیشترین مصرف RAM»
class ProcInfo {
  final String name;
  final double pct;
  ProcInfo(this.name, this.pct);
}

class Stats {
  final double cpu; // درصد کل CPU
  final List<double> cpuPerCore; // درصد هر هسته
  final double freq; // MHz
  final double ramPct; // درصد
  final double ramUsed, ramTotal, ramAvail, swapUsed; // GB
  final double diskWrite; // MB/s
  final double netDown, netUp; // Mbps
  final double netTotalDown, netTotalUp; // GB
  final String netIface;
  final int packetsSent, packetsRecv;
  final bool gpuAvailable;
  final double? gpu; // null یعنی GPU نداریم
  final int? gpuTemp;
  final double? gpuMemUsed, gpuMemTotal;
  final int? gpuFan;
  final int procs, physicalCores, logicalCores;
  final WatchInfo? watch;
  final Map<String, double?> temps; // {'cpu':..,'gpu':..,'ssd':..} — null = سنسور نداریم
  final Map<String, String?> tempSources; // از کجا خونده شده (NVML / LibreHardwareMonitor ...)
  final bool lhmReachable; // وب‌سرور LibreHardwareMonitor در دسترسه؟

  Stats({
    required this.cpu,
    required this.cpuPerCore,
    required this.freq,
    required this.ramPct,
    required this.ramUsed,
    required this.ramTotal,
    required this.ramAvail,
    required this.swapUsed,
    required this.diskWrite,
    required this.netDown,
    required this.netUp,
    required this.netTotalDown,
    required this.netTotalUp,
    required this.netIface,
    required this.packetsSent,
    required this.packetsRecv,
    required this.gpuAvailable,
    required this.gpu,
    required this.gpuTemp,
    required this.gpuMemUsed,
    required this.gpuMemTotal,
    required this.gpuFan,
    required this.procs,
    required this.physicalCores,
    required this.logicalCores,
    required this.watch,
    required this.temps,
    required this.tempSources,
    required this.lhmReachable,
  });

  factory Stats.fromJson(Map<String, dynamic> j) {
    final w = j['watch'];
    return Stats(
      cpu: _d(j['cpu']),
      cpuPerCore: (j['cpu_per_core'] as List).map((e) => _d(e)).toList(),
      freq: _d(j['freq']),
      ramPct: _d(j['ram_pct']),
      ramUsed: _d(j['ram_used']),
      ramTotal: _d(j['ram_total']),
      ramAvail: _d(j['ram_avail']),
      swapUsed: _d(j['swap_used']),
      diskWrite: _d(j['disk_write']),
      netDown: _d(j['net_down']),
      netUp: _d(j['net_up']),
      netTotalDown: _d(j['net_total_down']),
      netTotalUp: _d(j['net_total_up']),
      netIface: j['net_iface'] as String,
      packetsSent: (j['packets_sent'] as num).toInt(),
      packetsRecv: (j['packets_recv'] as num).toInt(),
      gpuAvailable: j['gpu_available'] as bool,
      gpu: _dn(j['gpu']),
      gpuTemp: _in(j['gpu_temp']),
      gpuMemUsed: _dn(j['gpu_mem_used']),
      gpuMemTotal: _dn(j['gpu_mem_total']),
      gpuFan: _in(j['gpu_fan']),
      procs: (j['procs'] as num).toInt(),
      physicalCores: _in(j['physical_cores']) ?? 0,
      logicalCores: _in(j['logical_cores']) ?? 0,
      temps: _tempMap(j['temps']),
      tempSources: _strMap(j['temp_sources']),
      lhmReachable: (j['lhm_reachable'] as bool?) ?? false,
      watch: w == null
          ? null
          : WatchInfo((w['pid'] as num).toInt(), w['name'] as String,
              w['alive'] as bool),
    );
  }
}

/// 1234567 → "1,234,567"
String fmtInt(int n) => n
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

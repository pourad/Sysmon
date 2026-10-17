"""
System Monitor - Backend (بدون هیچ رابط گرافیکی)

این فایل فقط داده‌ی سیستم (CPU / GPU / RAM / شبکه) رو جمع می‌کنه و
از طریق یک سرور کوچیک محلی (HTTP) به برنامه‌ی فلاتر می‌ده.
فلاتر مستقیم نمی‌تونه CPU و GPU رو بخونه، برای همین psutil و pynvml همین‌جا می‌مونن.

اجرا:
    pip install psutil pynvml
    python monitor_backend.py

آدرس‌ها:
    GET  /stats       -> همه‌ی آمار سیستم (JSON)
    GET  /top-procs   -> ۶ پروسه‌ای که بیشترین RAM رو دارن
    POST /watch       -> {"query": "chrome" یا "1234"}  شروع نظارت روی یک پروسه
    POST /unwatch     -> توقف نظارت
    POST /log         -> {"msg": "..."} یک خط به monitor_log.txt اضافه می‌کنه
    POST /open-log    -> فایل لاگ رو با برنامه‌ی پیش‌فرض سیستم باز می‌کنه
"""
import argparse
import datetime
import json
import os
import re
import subprocess
import sys
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import psutil

try:
    import pynvml
    pynvml.nvmlInit()
    GPU_AVAILABLE = True
except Exception:
    GPU_AVAILABLE = False

# ── تنظیمات ──────────────────────────────────────────────────────────────────
FROZEN = getattr(sys, "frozen", False)   # True وقتی با PyInstaller به .exe تبدیل شده
APP_DIR = os.path.dirname(os.path.abspath(sys.executable if FROZEN else __file__))

if FROZEN:
    # پوشه‌ی Program Files قابل‌نوشتن نیست، پس لاگ می‌ره توی %LOCALAPPDATA%\SysMon
    LOG_FILE = os.path.join(
        os.environ.get("LOCALAPPDATA") or os.path.expanduser("~"), "SysMon", "monitor_log.txt")
else:
    LOG_FILE = "monitor_log.txt"   # موقع توسعه مثل قبل کنار فایل
HOST = "127.0.0.1"   # اگه می‌خوای از گوشی وصل بشی بذار "0.0.0.0"
PORT = 8765

# آدرس سرور وب LibreHardwareMonitor (برای دمای CPU و SSD روی ویندوز)
# توی LibreHardwareMonitor:  Options → Remote Web Server → Run
LHM_URL = os.environ.get("LHM_URL", "http://localhost:8085/data.json")


def log_line(msg):
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    os.makedirs(os.path.dirname(os.path.abspath(LOG_FILE)), exist_ok=True)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(f"[{ts}] {msg}\n")


# ── نمونه‌بردار دقیق CPU (همون قبلی، بدون تغییر) ──────────────────────────────
# هر ۱ ثانیه یک‌بار در یک thread جدا میانگین واقعی CPU رو می‌گیره
# تا عددها به Task Manager ویندوز نزدیک باشن.
class CpuSampler:
    def __init__(self):
        self._cpu = 0.0
        self._percore = []
        self._lock = threading.Lock()
        self._running = True
        psutil.cpu_percent(interval=None)
        psutil.cpu_percent(interval=None, percpu=True)
        threading.Thread(target=self._loop, daemon=True).start()

    def _loop(self):
        while self._running:
            cpu = psutil.cpu_percent(interval=1.0)
            percore = psutil.cpu_percent(interval=None, percpu=True)
            with self._lock:
                self._cpu = cpu
                self._percore = percore

    def read(self):
        with self._lock:
            return self._cpu, list(self._percore)

    def stop(self):
        self._running = False


# ── دمای قطعات ───────────────────────────────────────────────────────────────
# ویندوز دمای CPU و SSD رو مستقیم به برنامه‌ها نمی‌ده. منبع‌ها به ترتیب:
#   GPU  : pynvml (کارت NVIDIA)           ← بدون نیاز به برنامه‌ی اضافه
#   همه  : psutil.sensors_temperatures()  ← فقط لینوکس
#   همه  : LibreHardwareMonitor (وب‌سرور) ← ویندوز؛ باید با Administrator اجرا بشه
_NO_PROXY = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def _parse_temp(text):
    """'45.0 °C' یا '45,0 °C' → 45.0 ؛ اگه دما نبود None"""
    m = re.match(r"^\s*(-?\d+(?:[.,]\d+)?)\s*\D{0,3}C\s*$", text or "")
    return float(m.group(1).replace(",", ".")) if m else None


def _kind_of(node):
    """این گره‌ی درخت LibreHardwareMonitor مربوط به کدوم قطعه‌ست؟ cpu / gpu / ssd / None"""
    img = (node.get("ImageURL") or "").lower()
    stem = img.rsplit("/", 1)[-1].rsplit(".", 1)[0]
    name = (node.get("Text") or "").lower()
    if stem == "cpu":
        return "cpu"
    if stem in ("nvidia", "ati", "amd", "gpu"):
        return "gpu"
    if stem in ("hdd", "ssd", "nvme"):
        return "ssd"
    if any(k in name for k in ("ryzen", "core i", "xeon", "threadripper")):
        return "cpu"
    if any(k in name for k in ("geforce", "radeon", "nvidia", "rtx", "gtx")):
        return "gpu"
    if "nvme" in name or "ssd" in name:
        return "ssd"
    return None


def _pick(kind, items):
    """از بین چند سنسور یک دمای «نماینده» برای قطعه انتخاب می‌کنه"""
    items = [(l, v) for l, v in items if -20 < v < 150]
    if not items:
        return None

    def first(*keys):
        for k in keys:
            for label, v in items:
                if k in label:
                    return v
        return None

    if kind == "cpu":
        v = first("package", "tctl", "tdie", "core max", "cpu")
        if v is not None:
            return v
        cores = [v for l, v in items if "core" in l]
        return max(cores) if cores else max(v for _, v in items)
    if kind == "gpu":
        v = first("gpu core", "core")
        return v if v is not None else items[0][1]
    # ssd: اگه چند SSD هست، داغ‌ترینش
    main = [v for l, v in items if l == "temperature" or l.startswith("composite")]
    return max(main) if main else max(v for _, v in items)


def parse_lhm(root):
    """درخت JSON وب‌سرور LibreHardwareMonitor → {'cpu': .., 'gpu': .., 'ssd': ..}"""
    found = {"cpu": [], "gpu": [], "ssd": []}

    def walk(node, kind):
        if kind is None:
            kind = _kind_of(node)
        children = node.get("Children") or []
        if not children and kind:
            label = (node.get("Text") or "").lower()
            val = _parse_temp(node.get("Value"))
            # «Distance to TjMax» هم °C داره ولی دما نیست
            if val is not None and "tjmax" not in label and "distance" not in label:
                found[kind].append((label, val))
        for ch in children:
            walk(ch, kind)

    walk(root, None)
    return {k: _pick(k, v) for k, v in found.items()}


def _psutil_temps():
    out = {"cpu": None, "gpu": None, "ssd": None}
    fn = getattr(psutil, "sensors_temperatures", None)  # روی ویندوز وجود نداره
    if fn is None:
        return out
    try:
        data = fn()
    except Exception:
        return out
    for name in ("coretemp", "k10temp", "zenpower", "cpu_thermal", "cpu-thermal"):
        entries = data.get(name)
        if entries:
            pkg = [e.current for e in entries
                   if (e.label or "").lower().startswith(("package", "tctl", "tdie"))]
            out["cpu"] = pkg[0] if pkg else max(e.current for e in entries)
            break
    for name in ("nvme", "drivetemp"):
        entries = data.get(name)
        if entries:
            comp = [e.current for e in entries
                    if (e.label or "").lower().startswith("composite")]
            out["ssd"] = max(comp) if comp else max(e.current for e in entries)
            break
    return out


class TempReader:
    """هر ۲ ثانیه در یک thread جدا دما رو می‌خونه تا /stats کند نشه"""

    def __init__(self):
        self._lock = threading.Lock()
        self._values = {"cpu": None, "gpu": None, "ssd": None}
        self._sources = {"cpu": None, "gpu": None, "ssd": None}
        self._lhm_ok = False
        threading.Thread(target=self._loop, daemon=True).start()

    def _poll(self):
        values = {"cpu": None, "gpu": None, "ssd": None}
        sources = {"cpu": None, "gpu": None, "ssd": None}
        for k, v in _psutil_temps().items():
            if v is not None:
                values[k], sources[k] = float(v), "psutil"
        lhm_ok = False
        try:
            with _NO_PROXY.open(LHM_URL, timeout=1.0) as r:
                root = json.loads(r.read().decode("utf-8", "replace"))
            lhm_ok = True
            for k, v in parse_lhm(root).items():
                if v is not None and values[k] is None:
                    values[k], sources[k] = v, "LibreHardwareMonitor"
        except Exception:
            pass
        return values, sources, lhm_ok

    def _loop(self):
        while True:
            try:
                values, sources, ok = self._poll()
                with self._lock:
                    self._values, self._sources, self._lhm_ok = values, sources, ok
            except Exception:
                pass
            time.sleep(2)

    def read(self):
        with self._lock:
            return dict(self._values), dict(self._sources), self._lhm_ok


# ── جمع‌آوری آمار ────────────────────────────────────────────────────────────
class Collector:
    def __init__(self):
        self.cpu_sampler = CpuSampler()
        self._lock = threading.Lock()
        self._disk_prev = psutil.disk_io_counters()
        self._disk_ts = time.time()
        self._net_prev = psutil.net_io_counters()
        self._net_ts = time.time()
        self._net_sent0 = self._net_prev.bytes_sent
        self._net_recv0 = self._net_prev.bytes_recv

    def collect(self):
        with self._lock:   # سرعت شبکه/دیسک نسبت به آخرین درخواست محاسبه می‌شه
            cpu, cpup = self.cpu_sampler.read()
            freq = psutil.cpu_freq()
            ram = psutil.virtual_memory()
            swap = psutil.swap_memory()
            now = time.time()

            # Disk write (MB/s)
            disk = psutil.disk_io_counters()
            dw = 0.0
            if disk is not None and self._disk_prev is not None:
                dt = max(now - self._disk_ts, 0.001)
                dw = (disk.write_bytes - self._disk_prev.write_bytes) / 1e6 / dt
            self._disk_prev = disk
            self._disk_ts = now

            # Network (Mbps)
            net = psutil.net_io_counters()
            net_dt = max(now - self._net_ts, 0.001)
            down = (net.bytes_recv - self._net_prev.bytes_recv) * 8 / 1e6 / net_dt
            up = (net.bytes_sent - self._net_prev.bytes_sent) * 8 / 1e6 / net_dt
            self._net_prev = net
            self._net_ts = now

        try:
            stats = psutil.net_if_stats()
            iface = next((n for n, s in stats.items()
                          if s.isup and n.lower() not in ("lo", "loopback")), "—")
        except Exception:
            iface = "—"

        gpu = gpu_temp = gpu_mem_used = gpu_mem_total = gpu_fan = None
        if GPU_AVAILABLE:
            try:
                h = pynvml.nvmlDeviceGetHandleByIndex(0)
                u = pynvml.nvmlDeviceGetUtilizationRates(h)
                m = pynvml.nvmlDeviceGetMemoryInfo(h)
                gpu = u.gpu
                gpu_temp = pynvml.nvmlDeviceGetTemperature(h, pynvml.NVML_TEMPERATURE_GPU)
                gpu_mem_used = m.used / 1e9
                gpu_mem_total = m.total / 1e9
                try:
                    gpu_fan = pynvml.nvmlDeviceGetFanSpeed(h)
                except Exception:
                    gpu_fan = None
            except Exception:
                pass

        temps, temp_sources, lhm_ok = temp_reader.read()
        if gpu_temp is not None:          # NVML دقیق‌تره، اولویت با اونه
            temps["gpu"] = float(gpu_temp)
            temp_sources["gpu"] = "NVML"

        return {
            "cpu": cpu,
            "cpu_per_core": cpup,
            "freq": freq.current if freq else 0,
            "ram_pct": ram.percent,
            "ram_used": ram.used / 1e9,
            "ram_total": ram.total / 1e9,
            "ram_avail": ram.available / 1e9,
            "swap_used": swap.used / 1e9,
            "disk_write": dw,
            "net_down": down,
            "net_up": up,
            "net_total_down": (net.bytes_recv - self._net_recv0) / 1e9,
            "net_total_up": (net.bytes_sent - self._net_sent0) / 1e9,
            "net_iface": iface,
            "packets_sent": net.packets_sent,
            "packets_recv": net.packets_recv,
            "gpu_available": GPU_AVAILABLE,
            "gpu": gpu,
            "gpu_temp": gpu_temp,
            "gpu_mem_used": gpu_mem_used,
            "gpu_mem_total": gpu_mem_total,
            "gpu_fan": gpu_fan,
            "procs": len(psutil.pids()),
            "physical_cores": psutil.cpu_count(logical=False),
            "logical_cores": psutil.cpu_count(logical=True),
            "temps": temps,
            "temp_sources": temp_sources,
            "lhm_reachable": lhm_ok,
            "watch": watcher.info(),
        }


def top_processes(n=6):
    items = []
    for p in psutil.process_iter(["name", "memory_percent"]):
        if p.info["memory_percent"] is not None and p.info["name"]:
            items.append({"name": p.info["name"], "pct": p.info["memory_percent"]})
    items.sort(key=lambda x: x["pct"], reverse=True)
    return items[:n]


# ── نظارت روی یک پروسه ───────────────────────────────────────────────────────
class Watcher:
    def __init__(self):
        self.pid = None
        self.name = None

    def set(self, val):
        val = (val or "").strip()
        if not val:
            return {"ok": False, "error": "empty"}
        try:
            pid = int(val)
            p = psutil.Process(pid)
            self.pid, self.name = pid, p.name()
            return {"ok": True, "pid": self.pid, "name": self.name}
        except (ValueError, psutil.NoSuchProcess):
            # عدد نبود یا PID وجود نداشت → بر اساس اسم پیدا کن
            found = [p for p in psutil.process_iter(["pid", "name"])
                     if p.info["name"] and val.lower() in p.info["name"].lower()]
            if found:
                self.pid, self.name = found[0].info["pid"], found[0].info["name"]
                return {"ok": True, "pid": self.pid, "name": self.name}
            return {"ok": False, "error": "not found"}

    def clear(self):
        self.pid = None
        self.name = None

    def info(self):
        if self.pid is None:
            return None
        return {"pid": self.pid, "name": self.name,
                "alive": psutil.pid_exists(self.pid)}


def open_log_file():
    try:
        if sys.platform == "win32":
            os.startfile(LOG_FILE)
        elif sys.platform == "darwin":
            subprocess.call(["open", LOG_FILE])
        else:
            subprocess.call(["xdg-open", LOG_FILE])
        return True
    except Exception:
        return False


watcher = Watcher()
temp_reader = TempReader()
collector = Collector()


# ── اجرای خودکار LibreHardwareMonitor (اگه همراه برنامه بسته‌بندی شده باشه) ────
# ساختار پوشه بعد از build:   <app>\backend\monitor_backend.exe   و   <app>\lhm\LibreHardwareMonitor.exe
_lhm_proc = None


def _lhm_reachable():
    try:
        with _NO_PROXY.open(LHM_URL, timeout=1.0):
            return True
    except Exception:
        return False


def start_lhm_if_bundled():
    global _lhm_proc
    if sys.platform != "win32":
        return
    candidates = [
        os.environ.get("LHM_EXE", ""),
        os.path.join(APP_DIR, "lhm", "LibreHardwareMonitor.exe"),
        os.path.join(APP_DIR, "..", "lhm", "LibreHardwareMonitor.exe"),
    ]
    exe = next((os.path.abspath(p) for p in candidates if p and os.path.isfile(p)), None)
    if exe is None:
        tried = "; ".join(os.path.abspath(p) for p in candidates if p)
        log_line(f"[INFO] LibreHardwareMonitor.exe not found. Looked in: {tried}")
        return
    if _lhm_reachable():
        log_line("[INFO] LibreHardwareMonitor already running (web server answers) - not starting another.")
        return
    try:
        si = subprocess.STARTUPINFO()
        si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        si.wShowWindow = 0   # SW_HIDE
        _lhm_proc = subprocess.Popen([exe], cwd=os.path.dirname(exe), startupinfo=si)
        log_line(f"[INFO] Started bundled LibreHardwareMonitor: {exe}")
    except Exception as e:
        log_line(f"[WARN] Could not start LibreHardwareMonitor: {e}")


def stop_lhm():
    if _lhm_proc is not None and _lhm_proc.poll() is None:
        try:
            _lhm_proc.terminate()
        except Exception:
            pass


def watch_parent(parent_pid):
    """وقتی برنامه‌ی فلاتر بسته شد (حتی با کرش)، بک‌اند هم خودش خاموش می‌شه"""
    def loop():
        while psutil.pid_exists(parent_pid):
            time.sleep(2)
        stop_lhm()
        log_line("[INFO] Parent app closed - backend exiting.")
        os._exit(0)
    threading.Thread(target=loop, daemon=True).start()


# ── سرور HTTP ────────────────────────────────────────────────────────────────
class Handler(BaseHTTPRequestHandler):
    def _send(self, code, obj):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        # برای وقتی که فلاتر رو روی وب (Chrome) اجرا می‌کنی
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):   # لاگ‌های اضافه‌ی سرور رو چاپ نکن
        pass

    def do_OPTIONS(self):
        self._send(200, {})

    def do_GET(self):
        try:
            if self.path == "/stats":
                self._send(200, collector.collect())
            elif self.path == "/top-procs":
                self._send(200, top_processes())
            elif self.path == "/health":
                self._send(200, {"ok": True})
            else:
                self._send(404, {"error": "not found"})
        except Exception as e:
            self._send(500, {"error": str(e)})

    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            raw = self.rfile.read(length) if length else b"{}"
            body = json.loads(raw or b"{}")
            if self.path == "/watch":
                self._send(200, watcher.set(body.get("query", "")))
            elif self.path == "/unwatch":
                watcher.clear()
                self._send(200, {"ok": True})
            elif self.path == "/log":
                log_line(str(body.get("msg", "")))
                self._send(200, {"ok": True})
            elif self.path == "/open-log":
                self._send(200, {"ok": open_log_file()})
            else:
                self._send(404, {"error": "not found"})
        except Exception as e:
            self._send(500, {"error": str(e)})


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--parent-pid", type=int, default=0,
                    help="با بسته شدن این پروسه، بک‌اند هم بسته می‌شه (برنامه‌ی فلاتر می‌فرسته)")
    args = ap.parse_args()

    log_line("[INFO] System Monitor v2 started.")
    start_lhm_if_bundled()
    if args.parent_pid:
        watch_parent(args.parent_pid)
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"Backend running on http://{HOST}:{PORT}  (Ctrl+C to stop)")
    if not GPU_AVAILABLE:
        print("pynvml not available — GPU data disabled (pip install pynvml)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        collector.cpu_sampler.stop()
        stop_lhm()
        log_line("[INFO] Monitor closed.")
        server.server_close()

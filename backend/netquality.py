"""
netquality.py  —  تست کیفیت اینترنت (به روش Cloudflare Speed Test)

همون روش کتابخانه‌ی متن‌باز Cloudflare (github.com/cloudflare/speedtest) رو پیاده می‌کنه:

  • Latency  : درخواست‌های خالی GET /__down?bytes=0 ، زمان تا اولین بایت منهای زمان پردازش
               سرور (هدر Server-Timing) ؛ مقدار نهایی = میانه (median) ۲۰ نمونه
  • Jitter   : میانگین فاصله‌ی نمونه‌های پشت‌سرهم latency
  • Download / Upload : فایل‌های با اندازه‌ی افزایشی (100KB ... 250MB) ؛ سرعت هر درخواست =
               بایت‌ها ÷ مدت (منهای زمان سرور) ؛ مقدار نهایی = صدک ۹۰ام.
               هر جهت وقتی درخواستی >= ۱ ثانیه طول کشید از اندازه‌های بزرگ‌تر رد می‌شه، ولی از همون
               اندازه حداقل ۳ نمونه (حداکثر ~۸ ثانیه) می‌گیره (کمی با Cloudflare فرق داره تا روی
               خطوط کند کاربر معطل نشه، بدون اینکه دقت خراب بشه)
  • Loaded latency : همزمان با دانلود/آپلود هر 0.4 ثانیه latency گرفته می‌شه (bufferbloat)
  • UDP packet loss : (اضافه‌ی ما) ارسال پرس‌وجوی DNS به 1.1.1.1 و شمردن پاسخ‌ها

تفاوت‌ها با Cloudflare (صادقانه):
  • packet loss اون‌ها با WebRTC/TURN است؛ این‌جا به‌جاش DNS روی UDP داریم (برای بازی/تماس
    تصویری مناسبه ولی دقیقاً همون نیست)
  • امتیازهای Streaming / Gaming / Video calls / Browsing جدول‌های خودمون رو دارن (پایین
    همین فایل، قابل تغییر)؛ جدول دقیق AIM کلودفلر در دسترس نبود.

استفاده (از monitor_backend.py):
    nq = NetQuality();  nq.start("quick" | "full");  nq.status();  nq.cancel()
"""
import http.client
import math
import os
import random
import re
import select
import socket
import ssl
import struct
import threading
import time
from datetime import datetime
from urllib.parse import urlparse

BASE_URL = os.environ.get("NETTEST_BASE", "https://speed.cloudflare.com")
DNS_TARGET = os.environ.get("NETTEST_DNS", "1.1.1.1:53")

FINISH_DURATION_MS = 1000     # بعد از درخواستی که این‌قدر طول کشید، اندازه‌های بزرگ‌تر همون جهت انجام نمی‌شه
MIN_BIG_REQUESTS = 3          # ولی از همون اندازه حداقل این‌قدر نمونه بگیر تا صدک ۹۰ام دقیق بشه
BIG_BUDGET_MS = 8000          # و کل زمانِ این نمونه‌های «بزرگ» از این بیشتر نشه (برای خطوط کند)
MIN_DURATION_MS = 10          # درخواست‌های کوتاه‌تر از این برای سرعت حساب نمی‌شن
LOADED_MIN_MS = 250           # درخواستی که کمتر از این طول بکشه «بار» حساب نمی‌شه
LOADED_THROTTLE_S = 0.4       # فاصله‌ی بین دو نمونه‌ی loaded latency
LOADED_MAX_POINTS = 20
BANDWIDTH_PERCENTILE = 0.9
LATENCY_PERCENTILE = 0.5

# ── ترتیب اندازه‌گیری‌ها (از README کتابخانه‌ی Cloudflare) ───────────────────────
def _seq(max_down, max_up):
    s = [
        ("latency", 1),
        ("down", 1e5, 1, True),
        ("latency", 20),
        ("down", 1e5, 9), ("down", 1e6, 8),
        ("up", 1e5, 8), ("up", 1e6, 6),
        ("down", 1e7, 6), ("up", 1e7, 4),
        ("down", 2.5e7, 4), ("up", 2.5e7, 4),
        ("down", 1e8, 3), ("up", 5e7, 3),
        ("down", 2.5e8, 2),
    ]
    out = []
    for st in s:
        if st[0] == "down" and st[1] > max_down:
            continue
        if st[0] == "up" and st[1] > max_up:
            continue
        out.append(st)
    return out


MODES = {
    # quick: تا 10MB ← حدود ۲۰ ثانیه و حداکثر ~۱۰۰MB دیتا (برای خطوط تا ~۳۰۰Mbps دقیقه)
    "quick": {"seq": _seq(1e7, 1e7), "loss_packets": 50, "time_cap_s": 120},
    # full: دقیقاً مثل Cloudflare (تا 250MB) ← روی خطوط خیلی سریع ممکنه تا ~۱GB دیتا بخوره
    "full": {"seq": _seq(2.5e8, 5e7), "loss_packets": 200, "time_cap_s": 300},
}


class NetTestError(Exception):
    pass


class Cancelled(Exception):
    pass


# ══════════════════════════════════════════════════════════════════════════════
#  توابع آماری
# ══════════════════════════════════════════════════════════════════════════════
def percentile(values, p):
    if not values:
        return None
    v = sorted(values)
    k = (len(v) - 1) * p
    f = math.floor(k)
    c = min(f + 1, len(v) - 1)
    return v[f] + (v[c] - v[f]) * (k - f)


def jitter(values):
    if len(values) < 2:
        return None
    return sum(abs(b - a) for a, b in zip(values, values[1:])) / (len(values) - 1)


_SERVER_TIMING = re.compile(r"cfRequestDuration;dur=([\d.]+)")


def _server_ms(header):
    m = _SERVER_TIMING.search(header or "")
    return float(m.group(1)) if m else 0.0


# ══════════════════════════════════════════════════════════════════════════════
#  اتصال HTTP(S) با زمان‌سنجی دقیق (بدون پروکسی؛ مستقیم)
# ══════════════════════════════════════════════════════════════════════════════
_HEADERS = {"User-Agent": "SysMon-NetTest", "Accept-Encoding": "identity", "Connection": "keep-alive"}
_ZEROS = bytes(1 << 18)


class Conn:
    def __init__(self, base=None):
        u = urlparse(base or BASE_URL)
        self.https = u.scheme == "https"
        self.host = u.hostname
        self.port = u.port or (443 if self.https else 80)
        self.conn = None
        self.cf_ray = None
        self.bytes_down = 0
        self.bytes_up = 0

    def open(self):
        self.close()
        if self.https:
            ctx = ssl.create_default_context()
            self.conn = http.client.HTTPSConnection(self.host, self.port, timeout=15, context=ctx)
        else:
            self.conn = http.client.HTTPConnection(self.host, self.port, timeout=15)
        self.conn.connect()          # ← TCP + TLS handshake اینجا انجام می‌شه، نه توی زمان‌سنجی

    def close(self):
        try:
            if self.conn:
                self.conn.close()
        except Exception:
            pass
        self.conn = None

    def _retry(self, fn):
        """اگه سرور اتصال keep-alive رو بسته بود، یک بار دوباره وصل شو"""
        try:
            return fn()
        except (http.client.HTTPException, ConnectionError, socket.timeout, ssl.SSLError, OSError):
            self.open()
            return fn()

    def down(self, n, cancel):
        """GET /__down?bytes=n  →  (ttfb_ms, duration_ms, server_ms) ؛ بدون زمان پردازش سرور"""
        def run():
            t0 = time.perf_counter()
            self.conn.request("GET", "/__down?bytes=%d" % int(n), headers=_HEADERS)
            resp = self.conn.getresponse()
            t1 = time.perf_counter()
            if resp.status != 200:
                resp.read()
                raise NetTestError("HTTP %d from server" % resp.status)
            got = 0
            while True:
                if cancel.is_set():
                    self.open()
                    raise Cancelled()
                chunk = resp.read(1 << 18)
                if not chunk:
                    break
                got += len(chunk)
            t2 = time.perf_counter()
            self.bytes_down += got
            ray = resp.getheader("cf-ray")
            if ray and "-" in ray:
                self.cf_ray = ray.rsplit("-", 1)[-1]
            srv = _server_ms(resp.getheader("Server-Timing"))
            return max((t1 - t0) * 1000 - srv, 0.0), max((t2 - t0) * 1000 - srv, 0.0), srv
        return self._retry(run)

    def up(self, n, cancel):
        """POST /__up (n بایت)  →  duration_ms منهای زمان پردازش سرور"""
        n = int(n)

        def run():
            t0 = time.perf_counter()
            c = self.conn
            c.putrequest("POST", "/__up", skip_accept_encoding=True)
            c.putheader("User-Agent", "SysMon-NetTest")
            c.putheader("Content-Type", "text/plain;charset=UTF-8")
            c.putheader("Content-Length", str(n))
            c.endheaders()
            left = n
            while left > 0:
                if cancel.is_set():
                    self.open()
                    raise Cancelled()
                k = min(left, len(_ZEROS))
                c.send(_ZEROS if k == len(_ZEROS) else _ZEROS[:k])
                left -= k
            resp = c.getresponse()
            resp.read()
            t2 = time.perf_counter()
            if resp.status >= 400:
                raise NetTestError("HTTP %d from server" % resp.status)
            self.bytes_up += n
            srv = _server_ms(resp.getheader("Server-Timing"))
            return max((t2 - t0) * 1000 - srv, 0.0)
        return self._retry(run)

    def ping(self, cancel):
        return self.down(0, cancel)[0]


class Prober:
    """یک اتصال جدا که فقط وقتی دانلود/آپلود در جریانه latency می‌گیره (loaded latency)"""

    def __init__(self, cancel):
        self.cancel = cancel
        self.conn = Conn()
        self.conn.open()
        self.active = threading.Event()
        self.stop = threading.Event()
        self.pts = []
        self.lock = threading.Lock()
        self.thread = threading.Thread(target=self._run, daemon=True)
        self.thread.start()

    def _run(self):
        while not self.stop.is_set():
            if not self.active.wait(0.1):
                continue
            ts = time.perf_counter()
            try:
                p = self.conn.ping(self.cancel)
            except Exception:
                self.stop.wait(LOADED_THROTTLE_S)
                continue
            te = time.perf_counter()
            with self.lock:
                self.pts.append((ts, te, p))
            self.stop.wait(LOADED_THROTTLE_S)

    def collect(self, t0, t1):
        with self.lock:
            return [p for ts, te, p in self.pts if ts >= t0 and te <= t1]

    def close(self):
        self.stop.set()
        self.active.clear()
        self.conn.close()


# ══════════════════════════════════════════════════════════════════════════════
#  UDP packet loss (پرس‌وجوی DNS به 1.1.1.1)
# ══════════════════════════════════════════════════════════════════════════════
def udp_loss(n, cancel):
    """(ارسال‌شده، دریافت‌شده) یا None اگه هیچ پاسخی نیومد (احتمالاً UDP مسدوده)"""
    host, port = DNS_TARGET.rsplit(":", 1)
    addr = (socket.gethostbyname(host), int(port))
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setblocking(False)
    qname = b"".join(bytes([len(p)]) + p.encode() for p in "cloudflare.com".split(".")) + b"\x00"
    ids = random.sample(range(1, 65535), n)
    sent, got = set(), set()

    def drain(wait):
        end = time.perf_counter() + wait
        while True:
            left = end - time.perf_counter()
            if left <= 0:
                return
            r, _, _ = select.select([sock], [], [], left)
            if not r:
                return
            try:
                data, _a = sock.recvfrom(512)
            except OSError:
                return
            if len(data) >= 4:
                tid = struct.unpack("!H", data[:2])[0]
                if tid in sent and (data[2] & 0x80):
                    got.add(tid)

    try:
        for tid in ids:
            if cancel.is_set():
                raise Cancelled()
            pkt = struct.pack("!HHHHHH", tid, 0x0100, 1, 0, 0, 0) + qname + struct.pack("!HH", 1, 1)
            try:
                sock.sendto(pkt, addr)
                sent.add(tid)
            except OSError:
                pass
            drain(0.02)                       # فاصله‌ی ۲۰ms بین بسته‌ها + دریافت پاسخ‌ها
        t_end = time.perf_counter() + 1.5     # صبر برای پاسخ‌های دیررسیده
        while len(got) < len(sent) and time.perf_counter() < t_end:
            drain(0.1)
    finally:
        sock.close()
    if not got:
        return None
    return len(sent), len(got)


# ══════════════════════════════════════════════════════════════════════════════
#  امتیازدهی (جدول‌های خودمون؛ می‌تونی عددها رو تغییر بدی)
# ══════════════════════════════════════════════════════════════════════════════
LEVELS = ["bad", "poor", "average", "good", "great"]


def _low(v, t):      # هرچی کمتر بهتر (latency، jitter ...). t = [great, good, average, poor]
    for lvl, lim in zip((4, 3, 2, 1), t):
        if v <= lim:
            return lvl
    return 0


def _high(v, t):     # هرچی بیشتر بهتر (سرعت). t = [great, good, average, poor]
    for lvl, lim in zip((4, 3, 2, 1), t):
        if v >= lim:
            return lvl
    return 0


def compute_scores(r):
    """r = dict نتیجه ؛ برای هر کاربرد، «ضعیف‌ترین معیار» تعیین‌کننده است و اسمش هم برمی‌گرده"""
    lat, jit, inc = r.get("latency_ms"), r.get("jitter_ms"), r.get("latency_increase_ms")
    dl, ul, loss = r.get("download_mbps"), r.get("upload_mbps"), r.get("loss_pct")

    rules = {
        "streaming": [("download", dl, _high, [25, 15, 8, 3]),
                      ("latency", lat, _low, [100, 200, 350, 600]),
                      ("latency under load", inc, _low, [200, 400, 800, 1500])],
        "gaming": [("latency", lat, _low, [20, 40, 70, 120]),
                   ("jitter", jit, _low, [5, 15, 30, 60]),
                   ("latency under load", inc, _low, [30, 60, 120, 250]),
                   ("packet loss", loss, _low, [0.1, 0.5, 1.5, 4])],
        "video_calls": [("upload", ul, _high, [5, 3, 1.5, 0.5]),
                        ("download", dl, _high, [5, 3, 1.5, 0.5]),
                        ("latency", lat, _low, [50, 100, 150, 250]),
                        ("jitter", jit, _low, [10, 20, 30, 50]),
                        ("latency under load", inc, _low, [50, 100, 200, 400]),
                        ("packet loss", loss, _low, [0.2, 1, 2, 5])],
        "browsing": [("download", dl, _high, [25, 10, 5, 1]),
                     ("latency", lat, _low, [30, 60, 120, 250]),
                     ("latency under load", inc, _low, [100, 200, 400, 800])],
    }
    out = {}
    for name, items in rules.items():
        best = None
        for label, value, fn, table in items:
            if value is None:
                continue
            lvl = fn(value, table)
            if best is None or lvl < best[0]:
                best = (lvl, label)
        if best is not None:
            out[name] = {"level": best[0], "label": LEVELS[best[0]], "limit": best[1]}
    return out


# ══════════════════════════════════════════════════════════════════════════════
#  مدیر تست: thread + وضعیت قابل‌خواندن
# ══════════════════════════════════════════════════════════════════════════════
class NetQuality:
    def __init__(self):
        self._lock = threading.Lock()
        self._cancel = threading.Event()
        self._thread = None
        self._st = self._fresh("idle")

    @staticmethod
    def _fresh(state, mode="quick"):
        return {"state": state, "mode": mode, "phase": "", "progress": 0.0, "message": "",
                "live": {}, "result": None}

    # ── API ────────────────────────────────────────────────────────────────
    def start(self, mode="quick"):
        mode = mode if mode in MODES else "quick"
        with self._lock:
            if self._st["state"] == "running":
                return False
            self._st = self._fresh("running", mode)
            self._cancel.clear()
        self._thread = threading.Thread(target=self._worker, args=(mode,), daemon=True)
        self._thread.start()
        return True

    def cancel(self):
        self._cancel.set()

    def status(self):
        with self._lock:
            st = dict(self._st)
            st["live"] = dict(st["live"])
            return st

    def _set(self, **kw):
        with self._lock:
            live = kw.pop("live", None)
            self._st.update(kw)
            if live:
                self._st["live"].update(live)

    # ── worker ─────────────────────────────────────────────────────────────
    def _worker(self, mode):
        cfg = MODES[mode]
        t_start = time.perf_counter()
        deadline = t_start + cfg["time_cap_s"]
        conn = prober = None
        try:
            try:
                conn = Conn()
                conn.open()
                prober = Prober(self._cancel)
            except (OSError, ssl.SSLError, http.client.HTTPException) as e:
                raise NetTestError("Could not reach %s — check your internet connection "
                                   "(a VPN or proxy can also block it). %s" % (urlparse(BASE_URL).hostname, e))
            result = self._run(cfg, conn, prober, deadline)
            result["duration_s"] = round(time.perf_counter() - t_start, 1)
            result["mode"] = mode
            result["bytes_down"] = conn.bytes_down + prober.conn.bytes_down
            result["bytes_up"] = conn.bytes_up
            result["server"] = conn.cf_ray
            result["finished_at"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            result["scores"] = compute_scores(result)
            self._set(state="done", phase="Done", progress=1.0, result=result)
        except Cancelled:
            self._set(state="cancelled", phase="Cancelled", message="Test cancelled.")
        except NetTestError as e:
            self._set(state="error", phase="Failed", message=str(e))
        except Exception as e:                       # هر خطای پیش‌بینی‌نشده
            self._set(state="error", phase="Failed", message="Unexpected error: %s" % e)
        finally:
            if prober:
                prober.close()
            if conn:
                conn.close()

    def _run(self, cfg, conn, prober, deadline):
        seq = cfg["seq"]
        total = sum(s[1] if s[0] == "latency" else s[2] for s in seq) + 10
        done = 0
        lat_pts = []
        pts = {"down": [], "up": []}
        loaded = {"down": [], "up": []}
        finished = {"down": False, "up": False}
        warnings = []

        def upd(**live):
            self._set(progress=min(done / total, 0.99), live=live)

        def bw_now(d):
            good = [p for p in pts[d] if p[1] >= MIN_DURATION_MS]
            v = percentile([b * 8 / (ms / 1000.0) for b, ms in good], BANDWIDTH_PERCENTILE)
            return None if v is None else round(v / 1e6, 2)

        for st in seq:
            if self._cancel.is_set():
                raise Cancelled()
            if time.perf_counter() > deadline:
                warnings.append("time limit reached")
                break
            kind = st[0]

            if kind == "latency":
                for i in range(st[1]):
                    if self._cancel.is_set():
                        raise Cancelled()
                    try:
                        lat_pts.append(conn.ping(self._cancel))
                    except Cancelled:
                        raise
                    except (NetTestError, OSError, http.client.HTTPException) as e:
                        if not lat_pts:
                            raise NetTestError("Server is not answering: %s" % e)
                        break
                    done += 1
                    if len(lat_pts) >= 3:
                        upd(latency_ms=round(percentile(lat_pts[1:] or lat_pts, LATENCY_PERCENTILE), 1),
                            jitter_ms=round(jitter(lat_pts[1:]) or 0, 1))
                self._set(phase="Latency")
                continue

            size, count = st[1], st[2]
            bypass = len(st) > 3 and st[3]
            d = kind                                    # "down" / "up"
            if finished[d]:
                done += count
                continue
            label = "%s %s" % ("Download" if d == "down" else "Upload", _fmt_bytes(size))
            n_big, big_ms = 0, 0.0
            for i in range(count):
                if self._cancel.is_set():
                    raise Cancelled()
                if time.perf_counter() > deadline:
                    warnings.append("time limit reached")
                    finished[d] = True
                    break
                self._set(phase="%s (%d/%d)" % (label, i + 1, count))
                prober.active.set()
                t0 = time.perf_counter()
                try:
                    if d == "down":
                        _ttfb, dur, _srv = conn.down(size, self._cancel)
                    else:
                        dur = conn.up(size, self._cancel)
                except Cancelled:
                    prober.active.clear()
                    raise
                except (NetTestError, OSError, http.client.HTTPException) as e:
                    prober.active.clear()
                    warnings.append("%s failed: %s" % (d, e))
                    finished[d] = True
                    try:
                        conn.open()
                    except Exception:
                        pass
                    break
                t1 = time.perf_counter()
                prober.active.clear()
                if (t1 - t0) * 1000 >= LOADED_MIN_MS:
                    loaded[d].extend(prober.collect(t0, t1))
                    loaded[d] = loaded[d][-LOADED_MAX_POINTS:]
                pts[d].append((size, dur))
                done += 1
                live = {("download_mbps" if d == "down" else "upload_mbps"): bw_now(d)}
                if loaded["down"]:
                    live["loaded_down_ms"] = round(percentile(loaded["down"], LATENCY_PERCENTILE), 1)
                if loaded["up"]:
                    live["loaded_up_ms"] = round(percentile(loaded["up"], LATENCY_PERCENTILE), 1)
                upd(**live)
                if dur >= FINISH_DURATION_MS and not bypass:
                    n_big += 1
                    big_ms += dur
                    if n_big >= min(MIN_BIG_REQUESTS, count) or big_ms >= BIG_BUDGET_MS:
                        finished[d] = True              # این جهت کافیه؛ اندازه‌های بزرگ‌تر رد می‌شن
                        done += count - i - 1
                        break

        # ── UDP loss ──────────────────────────────────────────────────────
        loss_pct = loss_sent = loss_got = None
        if not self._cancel.is_set():
            self._set(phase="UDP packet loss")
            try:
                r = udp_loss(cfg["loss_packets"], self._cancel)
                if r:
                    loss_sent, loss_got = r
                    loss_pct = round((loss_sent - loss_got) * 100.0 / loss_sent, 2)
                    upd(loss_pct=loss_pct)
                else:
                    warnings.append("UDP probe unavailable (UDP to %s may be blocked)" % DNS_TARGET)
            except Cancelled:
                raise
            except Exception as e:
                warnings.append("UDP probe failed: %s" % e)
            done = total

        lat = percentile(lat_pts[1:] if len(lat_pts) > 1 else lat_pts, LATENCY_PERCENTILE)
        ld = percentile(loaded["down"], LATENCY_PERCENTILE)
        lu = percentile(loaded["up"], LATENCY_PERCENTILE)
        inc = None
        if lat is not None and (ld is not None or lu is not None):
            inc = max(max(x for x in (ld, lu) if x is not None) - lat, 0.0)
        if lat is None and not pts["down"] and not pts["up"]:
            raise NetTestError("No measurements could be completed.")
        r = lambda v, n=1: None if v is None else round(v, n)
        return {
            "download_mbps": bw_now("down"),
            "upload_mbps": bw_now("up"),
            "latency_ms": r(lat),
            "jitter_ms": r(jitter(lat_pts[1:])),
            "loaded_down_ms": r(ld),
            "loaded_up_ms": r(lu),
            "latency_increase_ms": r(inc),
            "loss_pct": loss_pct,
            "loss_sent": loss_sent,
            "loss_received": loss_got,
            "warnings": warnings,
        }


def _fmt_bytes(n):
    return "%d KB" % (n / 1e3) if n < 1e6 else "%d MB" % (n / 1e6)

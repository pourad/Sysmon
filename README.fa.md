# SysMon — نسخه‌ی فلاتر

## چطوری کار می‌کنه؟

برنامه دو تیکه است:

| تیکه | زبان | کار |
|---|---|---|
| `backend/monitor_backend.py` | پایتون | فقط داده می‌خونه (CPU، GPU، RAM، شبکه). **هیچ رابط گرافیکی نداره.** |
| `lib/` | فلاتر | همه‌ی ظاهر و دکمه‌ها. داده رو از بک‌اند می‌گیره و نشون می‌ده. |

چرا پایتون هنوز لازمه؟ چون فلاتر خودش نمی‌تونه مصرف CPU و GPU رو بخونه.
`psutil` و `pynvml` همون‌جا می‌مونن و فلاتر فقط نقاشی می‌کنه.

---

## نصب و اجرا

**۱) بک‌اند** (یک ترمینال، باز بمونه):

```
cd backend
pip install psutil pynvml
python monitor_backend.py
```

**۲) فلاتر** (یک ترمینال دیگه، فقط بار اول):

```
flutter create sysmon_flutter
```

بعد از داخل همین زیپ، پوشه‌ی `lib/` و فایل `pubspec.yaml` رو بریز توی پروژه‌ی جدید و جایگزین کن.
فایل `test/widget_test.dart` که خودکار ساخته شده رو پاک کن.

```
cd sysmon_flutter
flutter pub get
flutter run -d windows
```

(برای ویندوز باید Visual Studio با گزینه‌ی «Desktop development with C++» نصب باشه.)

---

## نقشه‌ی فایل‌ها

```
backend/monitor_backend.py     جمع‌آوری داده (CpuSampler، collect، watch، لاگ فایل)
lib/
  main.dart                    شروع برنامه + منوی کناری + بنر هشدار
  config.dart                  رنگ‌ها، استایل متن‌ها، تنظیمات پیش‌فرض، آدرس بک‌اند
  controller.dart              منطق: هشدارها، تاریخچه، لاگ، نظارت بر پروسه   (بدون ظاهر)
  stats.dart                   مدل داده (JSON → شیء Dart)
  api.dart                     صحبت با بک‌اند
  widgets/
    common.dart                AppCard، AppButton، InfoRow، StatCard، BarMeter، LabeledSlider
    gauge.dart                 گیج نیم‌دایره
    spark.dart                 نمودار خطی
  pages/
    dashboard_page.dart  cpu_page.dart  gpu_page.dart  ram_page.dart
    network_page.dart    log_page.dart  settings_page.dart
```

هر صفحه یک فایل جداست. اگه بخوای ظاهر صفحه‌ی CPU رو عوض کنی فقط `cpu_page.dart` رو باز کن.

---

## ⭐ چطور دکمه اضافه کنم؟

سه چیز باید بدونی:

1. **ظاهر** توی فایل‌های `pages/` و `widgets/` است.
2. **کار** (منطق) توی `controller.dart` است. توی همه‌ی صفحه‌ها با اسم `monitor` بهش دسترسی داری.
3. دکمه فقط این رو می‌گه: «وقتی زدن، این تابع رو صدا بزن».

### مثال ۱ — دکمه‌ای که یک کار آماده رو انجام می‌ده

توی `dashboard_page.dart`، آخر لیست `children` (جایی که کامنت ⭐ هست):

```dart
const SizedBox(height: 12),
AppButton(
  label: 'پاک کردن لاگ',
  icon: Icons.delete,
  color: AppColors.crit,
  onPressed: () => monitor.clearEvents(),
),
```

### مثال ۲ — دکمه‌ای که کار جدید انجام می‌ده

**اول** توی `controller.dart` یک تابع بنویس (مثلاً بعد از `clearEvents`):

```dart
void resetHistory() {
  cpuHistory.clear();
  ramHistory.clear();
  gpuHistory.clear();
  netDownHistory.clear();
  netUpHistory.clear();
  notifyListeners();   // ← این خط باعث می‌شه صفحه‌ها خودشون رو آپدیت کنن
}
```

**بعد** توی هر صفحه‌ای که خواستی:

```dart
AppButton(
  label: 'Reset charts',
  icon: Icons.refresh,
  onPressed: () => monitor.resetHistory(),
),
```

### مثال ۳ — دکمه‌ی کاملاً با طراحی خودت

`AppButton` فقط یک پیش‌فرضه. هر چیزی رو می‌تونی دکمه کنی:

```dart
GestureDetector(
  onTap: () => monitor.clearEvents(),
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Colors.purple, Colors.blue]),
      borderRadius: BorderRadius.circular(30),
    ),
    child: const Text('دکمه‌ی من', style: TextStyle(color: Colors.white)),
  ),
)
```

### اگه دکمه باید با **بک‌اند** کار کنه

1. توی `monitor_backend.py` یک آدرس جدید توی `do_POST` اضافه کن
2. توی `api.dart` یک تابع براش بنویس (مثل `openLogFile`)
3. توی `controller.dart` یک تابع بنویس که اون رو صدا بزنه
4. دکمه همون تابع controller رو صدا می‌زنه

### شکل همه‌ی دکمه‌ها رو یکجا عوض کنم؟

`AppButton` رو توی `widgets/common.dart` ویرایش کن (گردی گوشه‌ها، padding، فونت...).
همه‌ی دکمه‌های برنامه همون رو استفاده می‌کنن.

---

## چطور ظاهر رو عوض کنم؟

| می‌خوام... | کجا؟ |
|---|---|
| رنگ‌ها رو عوض کنم | `config.dart` ← `AppColors` |
| اندازه/رنگ متن‌ها | `config.dart` ← `AppText` |
| گردی گوشه‌ی کارت‌ها | `widgets/common.dart` ← `AppCard` (`borderRadius`) |
| ضخامت کمان گیج | `widgets/gauge.dart` ← `strokeWidth` |
| ترتیب/چیدمان کارت‌های یک صفحه | همون صفحه توی `pages/` (ترتیب `children`) |
| یک صفحه‌ی جدید | راهنما بالای `main.dart` |
| آدرس بک‌اند (گوشی/امولاتور) | `config.dart` ← `kBaseUrl` |

نکته: `CardRow(children: [...])` یعنی «این‌ها رو کنار هم بذار». `Column` یعنی زیر هم.
`SizedBox(height: 12)` یک فاصله‌ی خالیه.

---

## چیزهایی که نسبت به نسخه‌ی tkinter فرق دارن

- بنر هشدار حالا روی همه‌ی صفحه‌ها نشون داده می‌شه و دکمه‌ی ✕ داره.
- کنار ساعت داشبورد، اگه بک‌اند قطع باشه `● Offline` قرمز می‌بینی.
- نمودار شبکه حالا مقیاسش خودکاره (قبلاً ثابت ۰ تا ۱۰۰ بود و سرعت‌های بالا بیرون نمودار می‌رفتن).
- پیام‌های لاگ جدیدترین‌شون پایینه و خودکار اسکرول می‌شه.
- شروع نظارت روی پروسه با اسم هم توی فایل `monitor_log.txt` ثبت می‌شه.
- آستانه‌ی لاگ RAM (`logRam`) هنوز ۸۰ ثابته؛ مثل قبل اسلایدر نداره. اگه خواستی، توی `settings_page.dart` یک `_slider` براش اضافه کن.
- تنظیمات هنوز فقط تا وقتی برنامه بازه می‌مونن (مثل قبل).

## مشکلات رایج

- **`● Offline` می‌بینم:** بک‌اند اجرا نیست، یا `kBaseUrl` درست نیست.
- **GPU همیشه 0:** `pip install pynvml` و کارت NVIDIA لازمه.
- **فلاتر روی وب (Chrome):** کار می‌کنه، بک‌اند CORS رو باز گذاشته.

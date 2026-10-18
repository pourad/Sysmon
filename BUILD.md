# ساخت نسخه‌ی .exe (بدون هیچ کاری برای کاربر)

هدف: کاربر فقط `SysMon-Setup.exe` رو نصب کنه و برنامه رو باز کنه. نه پایتون می‌خواد، نه ترمینال، نه LibreHardwareMonitor جدا.

## چطور کار می‌کنه؟

```
SysMon (نصب‌شده)
├─ sysmon_flutter.exe          ← برنامه‌ی فلاتر (کاربر این رو باز می‌کنه)
├─ data\  *.dll                ← فایل‌های لازم فلاتر
├─ backend\monitor_backend.exe ← بک‌اند پایتون، به .exe تبدیل شده (با PyInstaller)
└─ lhm\LibreHardwareMonitor.exe← (اختیاری) برای دمای CPU و SSD
```

- برنامه‌ی فلاتر موقع باز شدن، خودش `backend\monitor_backend.exe` رو اجرا می‌کنه.
- بک‌اند خودش `lhm\LibreHardwareMonitor.exe` رو (اگه باشه) مخفی اجرا می‌کنه.
- وقتی برنامه بسته بشه، بک‌اند و LibreHardwareMonitor هم خودشون بسته می‌شن.
- لاگ‌ها توی `%LOCALAPPDATA%\SysMon\monitor_log.txt` ذخیره می‌شن (پوشه‌ی Program Files قابل‌نوشتن نیست).

## پیش‌نیازها (فقط روی کامپیوتر خودت، برای ساختن)

Flutter (با Visual Studio و Desktop development with C++)، Python و pip، و برای ساخت Setup.exe برنامه‌ی [Inno Setup](https://jrsoftware.org/isinfo.php) (رایگان).

## مراحل

### ۱) دمای CPU و SSD (اختیاری ولی اگه می‌خوای کاربر کاری نکنه لازمه)

1. LibreHardwareMonitor رو دانلود و zip رو باز کن.
2. محتویاتش رو بذار توی پوشه‌ی **`lhm`** کنار `pubspec.yaml`.
3. یک بار `lhm\LibreHardwareMonitor.exe` رو با Administrator اجرا کن و این‌ها رو فعال کن:
   **Options ← Remote Web Server ← Run**، و **Start Minimized** و **Minimize To Tray**.
4. ببندش. کنار exe فایل `LibreHardwareMonitor.config` ساخته می‌شه که این تنظیمات توشه. همون رو هم همراه بقیه بسته‌بندی کن (اسکریپت خودکار کپی می‌کنه).

> نکته: LibreHardwareMonitor برای خوندن دمای CPU یک درایور کرنل لازم داره. نسخه‌های قدیمی از درایور WinRing0 استفاده می‌کردن که Windows Defender اون رو مشکوک می‌دونه و بلاک می‌کنه. نسخه‌های جدیدتر به‌جاش از PawnIO استفاده می‌کنن که یک بار نصبش لازمه (https://pawnio.eu). قبل از توزیع، نسخه‌ی دقیقی که دانلود کردی رو روی یک کامپیوتر تمیز تست کن و اگه PawnIO می‌خواد، نصب‌کننده‌اش رو هم توی Setup بذار.
> LibreHardwareMonitor با لایسنس MPL-2.0 منتشر شده؛ فایل لایسنسش رو توی پوشه‌ی `lhm` نگه دار.

### ۲) اجرای خودکار با دسترسی Administrator

LibreHardwareMonitor برای دمای CPU باید با Administrator اجرا بشه. ساده‌ترین راه اینه که کل برنامه با Administrator اجرا بشه، تا بک‌اند و LHM هم همون دسترسی رو بگیرن.

فایل `windows\runner\runner.exe.manifest` رو باز کن و قبل از `</assembly>` این رو اضافه کن:

```xml
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v3">
    <security>
      <requestedPrivileges>
        <requestedExecutionLevel level="requireAdministrator" uiAccess="false"/>
      </requestedPrivileges>
    </security>
  </trustInfo>
```

نتیجه: هر بار که کاربر برنامه رو باز می‌کنه، **یک پنجره‌ی تأیید ویندوز (UAC)** می‌بینه. این تنها کاریه که ازش می‌خوایم. حذف کامل این پنجره فقط با نصب یک Windows Service موقع نصب ممکنه که کار پیچیده‌تریه؛ اگه خواستی بعداً بررسیش می‌کنیم.

⚠️ بعد از این تغییر، `flutter run` هم باید توی ترمینالی باشه که با Administrator باز شده. اگه موقع توسعه اذیتت کرد، این تغییر رو فقط موقع ساخت نسخه‌ی نهایی اعمال کن.

**اگه دمای CPU/SSD رو نمی‌خوای:** پوشه‌ی `lhm` رو نذار و manifest رو تغییر نده. برنامه بدون Administrator اجرا می‌شه و فقط دمای GPU (کارت NVIDIA) رو نشون می‌ده.

### ۳) ساخت برنامه

توی ترمینال، داخل پوشه‌ی پروژه:

```
build_release.bat
```

این اسکریپت به ترتیب: بک‌اند رو به .exe تبدیل می‌کنه، برنامه‌ی فلاتر رو می‌سازه، همه‌چیز رو توی یک پوشه جمع می‌کنه و DLLهای Visual C++ رو هم کنارش می‌ذاره (تا روی کامپیوترهایی که نصب ندارن هم اجرا بشه).
پوشه‌ی آماده این‌جاست:

```
build\windows\x64\runner\Release
```

این پوشه رو می‌تونی zip کنی و بدی. ولی فقط فایل exe تنها کار نمی‌کنه؛ کل پوشه لازمه.

### ۴) ساخت یک فایل نصب‌کننده (Setup.exe)

`installer.iss` رو با Inno Setup باز کن و **Compile** (یا Ctrl+F9) رو بزن. خروجی `Output\SysMon-Setup.exe` است: یک فایل واحد که برنامه رو نصب می‌کنه و میان‌بر Start Menu و دسکتاپ می‌سازه.

## انتشار آپدیت (دکمه‌ی Check for updates)

برنامه توی Settings یک کارت **Updates** داره. کاربر Check for updates رو می‌زنه، اگه نسخه‌ی جدیدی روی GitHub باشه توضیحاتش رو می‌بینه و با Download & install خودکار دانلود و نصب می‌شه (برنامه بسته می‌شه، نسخه‌ی جدید جایگزین می‌شه و دوباره باز می‌شه).

**یک بار تنظیم:**
1. یک ریپازیتوری **public** توی GitHub بساز.
2. توی `lib/config.dart` مقدار `kGithubRepo` رو به `'نام‌کاربری/نام‌ریپو'` تغییر بده.

**هر بار که آپدیت منتشر می‌کنی:**
1. شماره‌ی نسخه رو بالا ببر، توی هر سه جا با یک عدد: `kAppVersion` (config.dart)، `version:` (pubspec.yaml)، `AppVersion` (installer.iss).
2. `build_release.bat` رو اجرا کن و بعد `installer.iss` رو توی Inno Setup Compile کن تا `Output\SysMon-Setup.exe` ساخته بشه.
3. توی GitHub: **Releases ← Draft a new release**.
4. Tag رو به شکل `v1.1.0` بنویس (باید از نسخه‌ی قبلی بزرگ‌تر باشه).
5. فایل `SysMon-Setup.exe` رو توی قسمت فایل‌ها آپلود کن.
6. توی توضیحات بنویس چی عوض شده (کاربر همین متن رو توی برنامه می‌بینه).
7. **Publish release** رو بزن. (Draft و Pre-release توسط برنامه دیده نمی‌شن.)

نکته‌ها:
- فقط خود ریپازیتوری تو مجاز است؛ اگه آدرس دانلود از جای دیگه بود، آپدیت لغو می‌شه.
- اگه GitHub برای فایل hash (sha256) بده، قبل از نصب با فایل دانلودشده چک می‌شه. اندازه‌ی فایل هم همیشه چک می‌شه.
- GitHub برای درخواست‌های بدون توکن حدود ۶۰ بار در ساعت برای هر IP اجازه می‌ده؛ برای «دکمه‌ی دستی» کافیه.
- ریپازیتوری private کار نمی‌کنه (برنامه توکنی نداره، و گذاشتن توکن داخل برنامه امن نیست).
- AppId توی installer.iss رو هیچ‌وقت عوض نکن؛ وگرنه آپدیت به‌جای جایگزین شدن، نسخه‌ی جدیدی کنار قبلی نصب می‌کنه.

## محدودیت‌ها که باید بدونی

- نصب‌کننده و برنامه امضای دیجیتال ندارن، پس ویندوز SmartScreen ممکنه برای فایل جدید هشدار «Unknown publisher» نشون بده. حذفش فقط با خرید گواهی Code Signing ممکنه.
- فایل‌های ساخته‌شده با PyInstaller گاهی آنتی‌ویروس‌ها رو حساس می‌کنن (false positive). اگه شد، روی کامپیوتر خودت تست کن و اگه لازم بود به آنتی‌ویروس گزارش بده.
- اگه کاربر برنامه رو دوبار هم‌زمان باز کنه، بک‌اند اولی رو هر دو استفاده می‌کنن و با بسته شدن برنامه‌ی اولی، دومی Offline می‌شه.
- این روش فقط ویندوز رو پوشش می‌ده.

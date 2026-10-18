// ════════════════════════════════════════════════════════════════════════════
// main.dart  —  نقطه‌ی شروع برنامه + قاب اصلی (منوی کناری + بنر + صفحه‌ها)
//
//  ┌────────┬──────────────────────────────┐
//  │Sidebar │  بنر هشدار (فقط وقتی هشداره)  │
//  │        ├──────────────────────────────┤
//  │ منوی   │  صفحه‌ی انتخاب‌شده            │
//  │ کناری  │  (dashboard / cpu / ...)     │
//  └────────┴──────────────────────────────┘
//
// ⭐ برای اضافه کردن یک صفحه‌ی جدید:
//    1) اسمش رو به enum AppTab توی config.dart اضافه کن
//    2) فایل صفحه رو توی lib/pages بساز
//    3) اینجا توی _pages اضافه‌اش کن
//    4) توی _navItems یک آیکون و اسم براش بذار
// ════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'config.dart';
import 'controller.dart';
import 'pages/cpu_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/gpu_page.dart';
import 'pages/log_page.dart';
import 'pages/network_page.dart';
import 'pages/ram_page.dart';
import 'pages/settings_page.dart';
import 'pages/temps_page.dart';
import 'backend_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackendLauncher.start();
  monitor.start();
  runApp(const SysMonApp());
}

class SysMonApp extends StatelessWidget {
  const SysMonApp({super.key});

  @override
  Widget build(BuildContext context) {
    // هر وقت تم عوض شد، کل MaterialApp با رنگ‌های جدید دوباره ساخته می‌شه
    return ValueListenableBuilder<bool>(
      valueListenable: AppTheme.dark,
      builder: (context, isDark, _) {
        final scheme = isDark
            ? ColorScheme.dark(primary: AppColors.blue, surface: AppColors.card)
            : ColorScheme.light(primary: AppColors.blue, surface: AppColors.card);
        return MaterialApp(
          title: 'System Monitor',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: isDark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: AppColors.bg,
            colorScheme: scheme,
          ),
          home: const HomeShell(),
        );
      },
    );
  }
}

// ── کدوم صفحه برای کدوم تب ───────────────────────────────────────────────────
const Map<AppTab, Widget> _pages = {
  AppTab.dashboard: DashboardPage(),
  AppTab.cpu: CpuPage(),
  AppTab.gpu: GpuPage(),
  AppTab.ram: RamPage(),
  AppTab.network: NetworkPage(),
  AppTab.temps: TempsPage(),
  AppTab.log: LogPage(),
  AppTab.settings: SettingsPage(),
};

// ── آیتم‌های منوی کناری ──────────────────────────────────────────────────────
class _NavItem {
  const _NavItem(this.tab, this.icon, this.label);
  final AppTab tab;
  final IconData icon;
  final String label;
}

const List<_NavItem> _navItems = [
  _NavItem(AppTab.dashboard, Icons.dashboard_outlined, 'Dashboard'),
  _NavItem(AppTab.cpu, Icons.memory, 'CPU'),
  _NavItem(AppTab.gpu, Icons.desktop_windows_outlined, 'GPU'),
  _NavItem(AppTab.ram, Icons.storage_outlined, 'RAM'),
  _NavItem(AppTab.network, Icons.network_check, 'Network'),
  _NavItem(AppTab.temps, Icons.thermostat, 'Temps'),
  _NavItem(AppTab.log, Icons.description_outlined, 'Log'),
  _NavItem(AppTab.settings, Icons.settings_outlined, 'Settings'),
];

// ════════════════════════════════════════════════════════════════════════════
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const _Sidebar(),
          Expanded(
            child: ListenableBuilder(
              listenable: monitor,
              builder: (context, _) {
                return Column(
                  children: [
                    if (monitor.bannerText != null)
                      _AlertBanner(
                          text: monitor.bannerText!, color: monitor.bannerColor),
                    Expanded(
                      // IndexedStack همه‌ی صفحه‌ها رو نگه می‌داره و فقط یکی رو نشون می‌ده
                      // (برای همین اسلایدرهای Settings با عوض کردن تب پاک نمی‌شن)
                      child: IndexedStack(
                        index: monitor.tab.index,
                        children: [for (final t in AppTab.values) _pages[t]!],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── بنر هشدار ────────────────────────────────────────────────────────────────
class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text('⚠  $text',
                style: TextStyle(fontSize: 12, color: AppColors.bg)),
          ),
          InkWell(
            onTap: monitor.hideBanner,
            child: Icon(Icons.close, size: 16, color: AppColors.bg),
          ),
        ],
      ),
    );
  }
}

// ── منوی کناری ───────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: ListenableBuilder(
        listenable: monitor,
        builder: (context, _) {
          return Material(
            color: AppColors.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // لوگو: نقطه‌ی قرمز + اسم
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 10, color: AppColors.crit),
                      const SizedBox(width: 8),
                      Text('SysMon',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text1)),
                    ],
                  ),
                ),

                for (final item in _navItems) ...[
                  // خط جداکننده قبل از Log
                  if (item.tab == AppTab.log)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Divider(height: 1, color: AppColors.border),
                    ),
                  _navButton(item),
                ],

                const Spacer(),

                // ⭐ دکمه‌ی تیره / روشن
                _themeButton(),

                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                  child: Text('v$kAppVersion', style: AppText.caption),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// دکمه‌ی عوض کردن تم. شکلش مثل بقیه‌ی آیتم‌های منوئه.
  Widget _themeButton() {
    final dark = monitor.isDark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          hoverColor: AppColors.border2,
          onTap: () => monitor.toggleTheme(), // ← فقط همین یک خط کار اصلی رو می‌کنه
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    size: 16, color: AppColors.text2),
                const SizedBox(width: 10),
                Text(dark ? 'Light mode' : 'Dark mode',
                    style: TextStyle(fontSize: 12, color: AppColors.text2)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navButton(_NavItem item) {
    final active = monitor.tab == item.tab;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: active ? AppColors.navActive : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          hoverColor: AppColors.border2,
          onTap: () => monitor.setTab(item.tab),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(item.icon,
                    size: 16, color: active ? AppColors.text1 : AppColors.text2),
                const SizedBox(width: 10),
                Text(item.label,
                    style: TextStyle(
                        fontSize: 12,
                        color: active ? AppColors.text1 : AppColors.text2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// widgets/title_bar.dart  —  نوار بالای پنجره (هم‌رنگ برنامه)
//
// نوار پیش‌فرض ویندوز رنگش رو نمی‌شه عوض کرد، برای همین اون رو مخفی می‌کنیم
// (توی main.dart) و این نوار رو خودمون می‌کشیم:
//
//   [آیکون] SysMon ..................................  [ – ] [ ▢ ] [ ✕ ]
//
// • گرفتن و کشیدن نوار = جابه‌جا کردن پنجره
// • دابل‌کلیک روی نوار = بزرگ / کوچک کردن
//
// رنگ نوار رو از `color:` توی build عوض کن (الان همرنگ پس‌زمینه‌ی برنامه است).
// ════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../config.dart';
import '../controller.dart';

class AppTitleBar extends StatefulWidget {
  const AppTitleBar({super.key});

  @override
  State<AppTitleBar> createState() => _AppTitleBarState();
}

class _AppTitleBarState extends State<AppTitleBar> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _maximized = v);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  // وقتی پنجره بزرگ/کوچک شد آیکون دکمه‌ی وسط عوض بشه
  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder: با عوض شدن تم (تیره/روشن) رنگ نوار هم عوض بشه
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        return Container(
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.bg, // ← رنگ نوار
            border: Border(bottom: BorderSide(color: AppColors.border2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // بخش خالی وسط = ناحیه‌ی کشیدن پنجره
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: _toggleMaximize,
                  child: DragToMoveArea(
                    child: Container(
                      color: Colors.transparent,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/icon.png',
                            width: 18,
                            height: 18,
                            // اگه فایل آیکون پیدا نشد، به‌جاش یک آیکون ساده نشون بده
                            errorBuilder: (context, error, stack) =>
                                Icon(Icons.speed, size: 16, color: AppColors.blue),
                          ),
                          const SizedBox(width: 8),
                          Text('SysMon',
                              style: TextStyle(fontSize: 12, color: AppColors.text2)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // دکمه‌های کوچک / بزرگ / بستن
              _WinButton(
                icon: Icons.remove,
                onTap: () => windowManager.minimize(),
              ),
              _WinButton(
                icon: _maximized ? Icons.filter_none : Icons.crop_square,
                onTap: _toggleMaximize,
              ),
              _WinButton(
                icon: Icons.close,
                onTap: () => windowManager.close(),
                hoverColor: const Color(0xFFE81123), // قرمز مخصوص دکمه‌ی بستن ویندوز
                hoverIconColor: Colors.white,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// یک دکمه‌ی مربعی نوار عنوان (با رنگ مخصوص وقتی موس روشه)
class _WinButton extends StatefulWidget {
  const _WinButton({
    required this.icon,
    required this.onTap,
    this.hoverColor,
    this.hoverIconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? hoverColor;
  final Color? hoverIconColor;

  @override
  State<_WinButton> createState() => _WinButtonState();
}

class _WinButtonState extends State<_WinButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hover ? (widget.hoverColor ?? AppColors.border2) : Colors.transparent;
    final fg = _hover && widget.hoverIconColor != null
        ? widget.hoverIconColor!
        : AppColors.text2;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          width: 46,
          color: bg,
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 16, color: fg),
        ),
      ),
    );
  }
}

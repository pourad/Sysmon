// ════════════════════════════════════════════════════════════════════════════
// pages/log_page.dart  —  لاگ رویدادها (هشدارها، نظارت روی پروسه و ...)
// ════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../config.dart';
import '../controller.dart';
import '../widgets/common.dart';

class LogPage extends StatelessWidget {
  const LogPage({super.key});

  /// رنگ هر نوع پیام
  Color _color(LogTag t) {
    switch (t) {
      case LogTag.warn:
        return AppColors.warn;
      case LogTag.crit:
      case LogTag.crash:
        return AppColors.crit;
      case LogTag.ok:
        return AppColors.ok;
      case LogTag.info:
        return AppColors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final events = monitor.events;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // تیتر + دو دکمه سمت راست
              PageTitle(
                'Event Log',
                trailing: Row(
                  children: [
                    AppButton(
                      label: 'Open file',
                      color: AppColors.border2,
                      textColor: AppColors.text2,
                      onPressed: () => monitor.openLogFile(),
                    ),
                    const SizedBox(width: 8),
                    AppButton(
                      label: 'Clear',
                      color: AppColors.border2,
                      textColor: AppColors.text2,
                      onPressed: () => monitor.clearEvents(),
                    ),
                  ],
                ),
              ),

              // لیست پیام‌ها. reverse: true یعنی همیشه آخرین پیام پایینه
              // (مثل ترمینال) و خودش اسکرول می‌شه.
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  child: ListView.builder(
                    reverse: true,
                    itemCount: events.length,
                    itemBuilder: (context, i) {
                      final e = events[events.length - 1 - i];
                      return SelectableText(
                        '[${e.time}] ${e.msg}',
                        style: AppText.mono.copyWith(fontSize: 12, color: _color(e.tag)),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

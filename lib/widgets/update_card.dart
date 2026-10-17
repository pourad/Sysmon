// ════════════════════════════════════════════════════════════════════════════
// widgets/update_card.dart  —  کارت «Updates» توی صفحه‌ی Settings
//
//   [Check for updates]  →  پیام وضعیت
//   اگه نسخه‌ی جدید بود:   توضیحات + [Download & install] + نوار پیشرفت
//
// منطقش توی updater.dart است؛ اینجا فقط ظاهره.
// ════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../config.dart';
import '../updater.dart';
import 'common.dart';

class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key});

  Color _statusColor(UpdateStatus s) {
    switch (s) {
      case UpdateStatus.error:
        return AppColors.crit;
      case UpdateStatus.upToDate:
        return AppColors.ok;
      case UpdateStatus.available:
        return AppColors.warn;
      case UpdateStatus.idle:
      case UpdateStatus.checking:
      case UpdateStatus.downloading:
      case UpdateStatus.installing:
        return AppColors.text2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: updater,
      builder: (context, _) {
        final info = updater.info;
        final status = updater.status;

        return AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Updates', style: AppText.small),
              const SizedBox(height: 6),
              Text('Current version: v$kAppVersion', style: AppText.body),
              const SizedBox(height: 10),

              // دکمه + پیام وضعیت
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  AppButton(
                    label: 'Check for updates',
                    icon: Icons.system_update_alt,
                    onPressed: updater.busy ? null : () => updater.check(),
                  ),
                  if (updater.message.isNotEmpty)
                    Text(updater.message,
                        style: TextStyle(fontSize: 12, color: _statusColor(status))),
                ],
              ),

              // نسخه‌ی جدید پیدا شده
              if (info != null && status == UpdateStatus.available) ...[
                const SizedBox(height: 12),
                if (info.notes.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.border2,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(info.notes,
                        maxLines: 10,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.small),
                  ),
                const SizedBox(height: 10),
                AppButton(
                  label: 'Download & install',
                  icon: Icons.download,
                  color: AppColors.ok,
                  textColor: AppColors.bg,
                  onPressed: () => updater.downloadAndInstall(),
                ),
              ],

              // نوار پیشرفت دانلود
              if (status == UpdateStatus.downloading) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: BarMeter(
                          fraction: updater.progress, color: AppColors.blue, height: 8),
                    ),
                    const SizedBox(width: 10),
                    Text('${(updater.progress * 100).toStringAsFixed(0)}%',
                        style: AppText.small),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// widgets/common.dart  —  قطعه‌های آماده‌ی ظاهر که توی همه‌ی صفحه‌ها استفاده می‌شن.
//
//   AppCard      کارت با حاشیه          (قبلاً self._card)
//   CardRow      چند کارت کنار هم
//   PageTitle    تیتر بالای هر صفحه
//   InfoRow      یک ردیف «برچسب ........ مقدار»
//   StatCard     کارت کوچیک با عنوان و عدد بزرگ
//   BarMeter     نوار پیشرفت باریک
//   AppButton    ⭐ دکمه — اگه می‌خوای شکل همه‌ی دکمه‌ها رو عوض کنی همین‌جا
//   LabeledSlider اسلایدر با برچسب و عدد
// ════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../config.dart';

/// کارت: یک مستطیل با پس‌زمینه و حاشیه. هر چیزی رو می‌تونی توش بذاری.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8), // گوشه‌ها رو گردتر/تیزتر کن
      ),
      child: child,
    );
  }
}

/// چند کارت کنار هم با فاصله‌ی مساوی و ارتفاع برابر
class CardRow extends StatelessWidget {
  const CardRow({super.key, required this.children, this.gap = 8});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(SizedBox(width: gap));
      items.add(Expanded(child: children[i]));
    }
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
    );
  }
}

/// تیتر صفحه (و اختیاری: چیزی در سمت راست، مثلاً دکمه)
class PageTitle extends StatelessWidget {
  const PageTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(text, style: AppText.title),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// یک ردیف:  «Frequency ............ 3200 MHz»
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.labelWidth = 140});

  final String label;
  final String value;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          SizedBox(width: labelWidth, child: Text(label, style: AppText.small)),
          Expanded(child: Text(value, style: AppText.mono)),
        ],
      ),
    );
  }
}

/// کارت کوچیک: عنوان ریز + عدد بزرگ
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Text(label, style: AppText.caption),
          const SizedBox(height: 4),
          Text(value, style: AppText.value),
        ],
      ),
    );
  }
}

/// نوار باریک پر شونده. fraction بین 0 و 1
class BarMeter extends StatelessWidget {
  const BarMeter({
    super.key,
    required this.fraction,
    required this.color,
    this.height = 6,
  });

  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: AppColors.border2),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: f,
              child: Container(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// ⭐ دکمه‌ی استاندارد برنامه.
/// مثال:
///   AppButton(label: 'Clear', onPressed: () => monitor.clearEvents())
///   AppButton(label: 'Save', icon: Icons.save, color: AppColors.ok, onPressed: ...)
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color, // null یعنی رنگ آبی پیش‌فرض
    this.textColor, // null یعنی سفید
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed; // null بدی دکمه غیرفعال می‌شه
  final Color? color;
  final Color? textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AppColors.blue,
        foregroundColor: textColor ?? Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
          Text(label),
        ],
      ),
    );
  }
}

/// ظاهر کادر ورودی متن
InputDecoration inputDecoration(String hint) => InputDecoration(
      isDense: true,
      filled: true,
      fillColor: AppColors.border2,
      hintText: hint,
      hintStyle: AppText.caption,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide.none,
      ),
    );

/// اسلایدر با برچسب سمت چپ و عدد سمت راست
class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Row(
        children: [
          SizedBox(width: 160, child: Text(label, style: AppText.small)),
          Expanded(
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text('$value',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: AppColors.blue)),
          ),
        ],
      ),
    );
  }
}

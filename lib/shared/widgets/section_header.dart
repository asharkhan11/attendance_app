import 'package:flutter/material.dart';
import '../../design_system/app_spacing.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;
  final Color? color;

  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = color ?? Theme.of(context).textTheme.titleMedium?.color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: titleColor),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
              ),
            ],
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

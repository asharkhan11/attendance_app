import 'package:flutter/material.dart';
import '../../design_system/app_breakpoints.dart';
import '../../design_system/app_spacing.dart';

class ResponsiveKpiGrid<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final double mobileAspectRatio;
  final double desktopAspectRatio;

  const ResponsiveKpiGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.mobileAspectRatio = 2.0,
    this.desktopAspectRatio = 2.4,
  });

  @override
  Widget build(BuildContext context) {
    final cols = context.isMobile ? 2 : (context.isTablet ? 3 : 6);
    final aspect = context.isMobile ? mobileAspectRatio : desktopAspectRatio;

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: aspect,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
      ),
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => itemBuilder(ctx, items[i]),
        childCount: items.length,
      ),
    );
  }
}

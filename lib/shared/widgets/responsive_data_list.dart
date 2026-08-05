import 'package:flutter/material.dart';
import '../../design_system/app_breakpoints.dart';

class ResponsiveDataList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item) mobileItemBuilder;
  final List<DataColumn> columns;
  final DataRow Function(T item) rowBuilder;

  const ResponsiveDataList({
    super.key,
    required this.items,
    required this.mobileItemBuilder,
    required this.columns,
    required this.rowBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) {
      return SliverList.builder(
        itemCount: items.length,
        itemBuilder: (ctx, i) => mobileItemBuilder(ctx, items[i]),
      );
    }

    return SliverToBoxAdapter(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: columns,
          rows: items.map(rowBuilder).toList(),
        ),
      ),
    );
  }
}

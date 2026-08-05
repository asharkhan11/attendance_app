import 'package:flutter/material.dart';
import '../../design_system/app_spacing.dart';

class PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final String itemLabel;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    this.itemLabel = 'items',
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous',
            onPressed: currentPage > 1 ? onPrev : null,
          ),
          Text(
            'Page $currentPage of $totalPages ($totalItems $itemLabel)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next',
            onPressed: currentPage < totalPages ? onNext : null,
          ),
        ],
      ),
    );
  }
}

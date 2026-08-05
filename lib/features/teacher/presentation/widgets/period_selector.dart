import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/app_providers.dart';

/// A segment control widget that allows teachers to select the period number (1..maxPeriods)
/// when the app is in `AttendanceMode.periodWise`.
class PeriodSelector extends ConsumerWidget {
  final int selectedPeriod;
  final ValueChanged<int> onPeriodChanged;
  final int maxPeriods;

  const PeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    this.maxPeriods = 8,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(attendanceModeProvider);
    final theme = Theme.of(context);

    // If attendance mode is daily, hide the period selector
    if (!mode.isPeriodWise) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            'Period:',
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: selectedPeriod.clamp(1, maxPeriods),
              isDense: true,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: theme.colorScheme.primary,
              ),
              items: List.generate(maxPeriods, (i) {
                final p = i + 1;
                return DropdownMenuItem<int>(
                  value: p,
                  child: Text('Period $p'),
                );
              }),
              onChanged: (p) {
                if (p != null) onPeriodChanged(p);
              },
            ),
          ),
        ],
      ),
    );
  }
}

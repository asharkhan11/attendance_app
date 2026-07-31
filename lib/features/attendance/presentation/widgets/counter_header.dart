import 'package:flutter/material.dart';
import '../../../../design_system/app_breakpoints.dart';
import '../../../../design_system/app_spacing.dart';

class CounterHeader extends StatelessWidget {
  final String dateText;
  final bool isClosed;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int excusedCount;

  const CounterHeader({
    super.key,
    required this.dateText,
    required this.isClosed,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.excusedCount,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    return Container(
      color: isClosed ? Colors.amber.shade50 : Colors.blue.shade50,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isClosed ? Icons.lock : Icons.info_outline,
                color: isClosed ? Colors.amber.shade800 : Colors.blue.shade800,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  isClosed
                      ? 'Session LOCKED — Attendance completed.'
                      : 'Date: $dateText • Daily Attendance Roster',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isClosed ? Colors.amber.shade900 : Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (isMobile)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _statBadge('Present', '$presentCount', Colors.green)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _statBadge('Absent', '$absentCount', Colors.red)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(child: _statBadge('Late', '$lateCount', Colors.orange)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _statBadge('Excused', '$excusedCount', Colors.blue)),
                  ],
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statBadge('Present', '$presentCount', Colors.green),
                _statBadge('Absent', '$absentCount', Colors.red),
                _statBadge('Late', '$lateCount', Colors.orange),
                _statBadge('Excused', '$excusedCount', Colors.blue),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

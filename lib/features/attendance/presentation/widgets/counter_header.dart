import 'package:flutter/material.dart';
import '../../../../design_system/app_breakpoints.dart';
import '../../../../design_system/app_spacing.dart';
import '../../../../design_system/attendance_theme.dart';

class CounterHeader extends StatelessWidget {
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int excusedCount;

  const CounterHeader({
    super.key,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.excusedCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).extension<AttendanceTheme>() ?? AttendanceTheme.light;

    if (context.isMobile) {
      return _buildMobileGrid(theme);
    }
    return _buildDesktopRow(theme);
  }

  Widget _buildMobileGrid(AttendanceTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _counterChip('Present', '$presentCount', theme.present)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _counterChip('Absent', '$absentCount', theme.absent)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(child: _counterChip('Late', '$lateCount', theme.late)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _counterChip('Excused', '$excusedCount', theme.excused)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopRow(AttendanceTheme theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _counterChip('Present', '$presentCount', theme.present),
        _counterChip('Absent', '$absentCount', theme.absent),
        _counterChip('Late', '$lateCount', theme.late),
        _counterChip('Excused', '$excusedCount', theme.excused),
      ],
    );
  }

  Widget _counterChip(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $val',
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../design_system/app_breakpoints.dart';
import '../../../../design_system/app_radius.dart';
import '../../../../design_system/app_spacing.dart';
import '../../../../design_system/attendance_theme.dart';
import '../../../../models/app_models.dart';

class RosterItem extends StatelessWidget {
  final RosterEntry entry;
  final bool isClosed;
  final ValueChanged<String>? onStatusChanged;
  final VoidCallback? onTap;

  const RosterItem({
    super.key,
    required this.entry,
    this.isClosed = false,
    this.onStatusChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).extension<AttendanceTheme>() ?? AttendanceTheme.light;

    Color statusColor;
    switch (entry.status) {
      case 'present':
        statusColor = theme.present;
        break;
      case 'absent':
        statusColor = theme.absent;
        break;
      case 'late':
        statusColor = theme.late;
        break;
      case 'excused':
        statusColor = theme.excused;
        break;
      default:
        statusColor = theme.noRecord;
    }

    if (context.isMobile && !isClosed) {
      return _buildMobileItem(context, theme, statusColor);
    }
    return _buildDesktopItem(context, theme, statusColor);
  }

  Widget _buildMobileItem(
    BuildContext context,
    AttendanceTheme theme,
    Color statusColor,
  ) {
    return Container(
      key: Key('roster_item_${entry.studentId}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: statusColor.withValues(alpha: 0.15),
                child: Text(
                  entry.rollNumber,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  entry.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              if (entry.remarks != null && entry.remarks!.isNotEmpty)
                const Icon(Icons.note_alt_outlined, size: 16, color: Colors.grey),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: ['present', 'absent', 'late', 'excused'].map((st) {
              final isSelected = entry.status == st;
              Color stColor;
              switch (st) {
                case 'present':
                  stColor = theme.present;
                  break;
                case 'absent':
                  stColor = theme.absent;
                  break;
                case 'late':
                  stColor = theme.late;
                  break;
                default:
                  stColor = theme.excused;
              }

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: InkWell(
                    key: Key('roster_item_${entry.studentId}_status_${st[0].toUpperCase()}'),
                    onTap: onStatusChanged != null ? () => onStatusChanged!(st) : null,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Container(
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? stColor : stColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: isSelected ? stColor : stColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        st[0].toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isSelected ? Colors.white : stColor,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopItem(
    BuildContext context,
    AttendanceTheme theme,
    Color statusColor,
  ) {
    return ListTile(
      key: Key('roster_item_${entry.studentId}'),
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.15),
        child: Text(
          entry.rollNumber,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: statusColor,
            fontSize: 13,
          ),
        ),
      ),
      title: Text(entry.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: entry.remarks != null && entry.remarks!.isNotEmpty
          ? Text('Note: ${entry.remarks}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700))
          : null,
      onTap: onTap,
      trailing: isClosed
          ? Chip(
              label: Text(
                entry.status.toUpperCase(),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              backgroundColor: statusColor.withValues(alpha: 0.2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: ['present', 'absent', 'late', 'excused'].map((st) {
                final isSelected = entry.status == st;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: ChoiceChip(
                    label: Text(
                      st[0].toUpperCase(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    selected: isSelected,
                    onSelected: (sel) {
                      if (sel && onStatusChanged != null) onStatusChanged!(st);
                    },
                  ),
                );
              }).toList(),
            ),
    );
  }
}

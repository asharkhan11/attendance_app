import 'package:flutter/material.dart';
import '../../../../design_system/app_breakpoints.dart';
import '../../../../design_system/app_spacing.dart';
import '../../../../design_system/attendance_theme.dart';
import '../../../../models/app_models.dart';

const double kRosterItemExtent = 76.0;

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

  Color _getStatusColor(String status, AttendanceTheme attTheme) {
    switch (status) {
      case 'present':
        return attTheme.present;
      case 'absent':
        return attTheme.absent;
      case 'late':
        return attTheme.late;
      case 'excused':
        return attTheme.excused;
      default:
        return attTheme.noRecord;
    }
  }

  Color _getStatusBgColor(String status, AttendanceTheme attTheme) {
    switch (status) {
      case 'present':
        return attTheme.presentBg;
      case 'absent':
        return attTheme.absentBg;
      case 'late':
        return attTheme.lateBg;
      case 'excused':
        return attTheme.excusedBg;
      default:
        return attTheme.noRecordBg;
    }
  }

  String _getStatusShortLabel(String status) {
    switch (status) {
      case 'present':
        return 'P';
      case 'absent':
        return 'A';
      case 'late':
        return 'L';
      case 'excused':
        return 'E';
      default:
        return '?';
    }
  }

  @override
  Widget build(BuildContext context) {
    final attTheme = Theme.of(context).extension<AttendanceTheme>() ?? AttendanceTheme.light;
    final statusColor = _getStatusColor(entry.status, attTheme);
    final statusBgColor = _getStatusBgColor(entry.status, attTheme);
    final isMobile = context.isMobile;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4.0,
      ),
      child: Container(
        height: kRosterItemExtent - 8.0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: statusBgColor == attTheme.noRecordBg
                ? Theme.of(context).dividerColor.withValues(alpha: 0.6)
                : statusColor.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Roll Number Badge
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.3),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                entry.rollNumber.length > 3
                    ? entry.rollNumber
                    : entry.rollNumber.padLeft(2, '0'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Student Name & Remarks
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isClosed && onTap != null) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.edit_note_rounded,
                              size: 16,
                              color: Theme.of(context).disabledColor,
                            ),
                          ],
                        ],
                      ),
                      if (entry.remarks != null && entry.remarks!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 11,
                                color: attTheme.excused,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  entry.remarks!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: attTheme.excused,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Status Control Group (Segmented Pills)
            if (isClosed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  entry.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade800
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ['present', 'absent', 'late', 'excused'].map((st) {
                    final isSelected = entry.status == st;
                    final color = _getStatusColor(st, attTheme);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onStatusChanged != null
                            ? () => onStatusChanged!(st)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 8.0 : 12.0,
                            vertical: 6.0,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? color : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            isMobile
                                ? _getStatusShortLabel(st)
                                : st[0].toUpperCase() + st.substring(1),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

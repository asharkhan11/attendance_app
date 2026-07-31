import 'package:flutter/material.dart';
import '../../../../design_system/app_breakpoints.dart';
import '../../../../design_system/app_radius.dart';
import '../../../../design_system/app_spacing.dart';
import '../../../../models/app_models.dart';

const double kRosterItemExtent = 72.0;

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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present':
        return Colors.green.shade700;
      case 'absent':
        return Colors.red.shade700;
      case 'late':
        return Colors.orange.shade800;
      case 'excused':
        return Colors.blue.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(entry.status);
    final isMobile = context.isMobile;

    return Container(
      height: kRosterItemExtent,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: statusColor.withValues(alpha: 0.15),
            child: Text(
              entry.rollNumber,
              style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 13),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (entry.remarks != null && entry.remarks!.isNotEmpty)
                    Text(
                      'Note: ${entry.remarks}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          if (isClosed)
            Chip(
              label: Text(entry.status.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              backgroundColor: statusColor.withValues(alpha: 0.15),
              side: BorderSide.none,
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: ['present', 'absent', 'late', 'excused'].map((st) {
                final isSelected = entry.status == st;
                final color = _getStatusColor(st);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: InkWell(
                    onTap: onStatusChanged != null ? () => onStatusChanged!(st) : null,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8.0 : 12.0,
                        vertical: 6.0,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? color : color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: isSelected ? color : color.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        isMobile ? st[0].toUpperCase() : st[0].toUpperCase() + st.substring(1),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : color,
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
}

import 'package:flutter/material.dart';
import '../../../../design_system/app_breakpoints.dart';
import '../../../../design_system/app_radius.dart';
import '../../../../design_system/app_spacing.dart';
import '../../../../shared/domain/entities/defaulter_entry.dart';

class DefaulterCard extends StatelessWidget {
  final DefaulterEntry defaulter;
  final VoidCallback? onTapProfile;

  const DefaulterCard({
    super.key,
    required this.defaulter,
    this.onTapProfile,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) {
      return _buildMobileCard(context);
    }
    return _buildDesktopTile(context);
  }

  Widget _buildMobileCard(BuildContext context) {
    return Card(
      key: Key('defaulter_card_${defaulter.studentId}'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorderRadius,
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.red.shade100,
                  child: Text(
                    defaulter.rollNumber,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        defaulter.fullName,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${defaulter.className} • Adm: ${defaulter.admissionNumber}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${defaulter.attendancePercentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: defaulter.attendancePercentage < 50
                        ? Colors.red
                        : Colors.orange.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (defaulter.attendancePercentage / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.red.shade50,
                color: defaulter.attendancePercentage < 50
                    ? Colors.red
                    : Colors.orange,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Attended ${defaulter.presentCount} / ${defaulter.totalSessions} sessions',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (onTapProfile != null)
                  TextButton.icon(
                    onPressed: onTapProfile,
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: const Text('Profile'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTile(BuildContext context) {
    return ListTile(
      key: Key('defaulter_tile_${defaulter.studentId}'),
      leading: CircleAvatar(
        backgroundColor: Colors.red.shade100,
        child: Text(
          defaulter.rollNumber,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade900,
          ),
        ),
      ),
      title: Text(
        defaulter.fullName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        'Attended ${defaulter.presentCount} / ${defaulter.totalSessions} sessions',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${defaulter.attendancePercentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: defaulter.attendancePercentage < 50
                  ? Colors.red
                  : Colors.orange.shade900,
              fontSize: 16,
            ),
          ),
          if (onTapProfile != null) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.blue),
              onPressed: onTapProfile,
              tooltip: 'View Profile',
            ),
          ],
        ],
      ),
    );
  }
}

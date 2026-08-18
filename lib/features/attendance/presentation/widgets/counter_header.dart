import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../design_system/app_breakpoints.dart';
import '../../../../design_system/attendance_theme.dart';

class CounterHeader extends StatelessWidget {
  final String dateText;
  final bool isClosed;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int excusedCount;
  final VoidCallback? onMarkAllPresent;
  final VoidCallback? onMarkAllAbsent;
  final VoidCallback? onLockSession;

  const CounterHeader({
    super.key,
    required this.dateText,
    required this.isClosed,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.excusedCount,
    this.onMarkAllPresent,
    this.onMarkAllAbsent,
    this.onLockSession,
  });

  String _formatDate(String rawDate) {
    if (rawDate.isEmpty) return 'Today';
    try {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        return DateFormat('EEE, MMM d, yyyy').format(parsed.toLocal());
      }
    } catch (_) {}
    return rawDate;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final attTheme =
        Theme.of(context).extension<AttendanceTheme>() ?? AttendanceTheme.light;

    if (isMobile) {
      return _buildMobileCompactHeader(context, attTheme);
    }

    return _buildDesktopHeader(context, attTheme);
  }

  /// Mobile-first ultra-compact summary bar
  Widget _buildMobileCompactHeader(
    BuildContext context,
    AttendanceTheme attTheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isClosed
              ? attTheme.late.withValues(alpha: 0.5)
              : Theme.of(context).dividerColor.withValues(alpha: 0.6),
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
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _microStatBadge(
                    'Present',
                    presentCount,
                    attTheme.present,
                    attTheme.presentBg,
                  ),
                  const SizedBox(width: 6),
                  _microStatBadge(
                    'Absent',
                    absentCount,
                    attTheme.absent,
                    attTheme.absentBg,
                  ),
                  const SizedBox(width: 6),
                  _microStatBadge(
                    'Late',
                    lateCount,
                    attTheme.late,
                    attTheme.lateBg,
                  ),
                  const SizedBox(width: 6),
                  _microStatBadge(
                    'Excused',
                    excusedCount,
                    attTheme.excused,
                    attTheme.excusedBg,
                  ),
                ],
              ),
            ),
          ),

          if (isClosed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: attTheme.lateBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: attTheme.late.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_rounded, size: 12, color: attTheme.late),
                  const SizedBox(width: 3),
                  Text(
                    'LOCKED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: attTheme.late,
                    ),
                  ),
                ],
              ),
            )
          else
            PopupMenuButton<String>(
              tooltip: 'Quick Actions',
              padding: EdgeInsets.zero,
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 14,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ),
              onSelected: (val) {
                if (val == 'present' && onMarkAllPresent != null) {
                  onMarkAllPresent!();
                } else if (val == 'absent' && onMarkAllAbsent != null) {
                  onMarkAllAbsent!();
                } else if (val == 'lock' && onLockSession != null) {
                  onLockSession!();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'present',
                  child: Row(
                    children: [
                      Icon(Icons.done_all_rounded, size: 16, color: attTheme.present),
                      const SizedBox(width: 8),
                      const Text('Mark All Present', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'absent',
                  child: Row(
                    children: [
                      Icon(Icons.remove_done_rounded, size: 16, color: attTheme.absent),
                      const SizedBox(width: 8),
                      const Text('Mark All Absent', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'lock',
                  child: Row(
                    children: [
                      Icon(Icons.lock_rounded, size: 16, color: attTheme.late),
                      const SizedBox(width: 8),
                      Text(
                        'Lock Session',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: attTheme.late,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _microStatBadge(
    String label,
    int count,
    Color fgColor,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fgColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fgColor,
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Compact, High-Density Desktop Header Strip (~60px height instead of 220px)
  Widget _buildDesktopHeader(
    BuildContext context,
    AttendanceTheme attTheme,
  ) {
    final total = presentCount + absentCount + lateCount + excusedCount;
    final formattedDate = _formatDate(dateText);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isClosed
              ? attTheme.late.withValues(alpha: 0.5)
              : Theme.of(context).dividerColor.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Session Date & Status Pill
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isClosed
                      ? attTheme.lateBg
                      : Theme.of(context).primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isClosed ? Icons.lock_rounded : Icons.calendar_today_rounded,
                  color: isClosed ? attTheme.late : Theme.of(context).primaryColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formattedDate,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isClosed ? attTheme.lateBg : attTheme.presentBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isClosed ? attTheme.late : attTheme.present,
                  ),
                ),
                child: Text(
                  isClosed ? 'LOCKED' : 'SESSION ACTIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isClosed ? attTheme.late : attTheme.present,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 16),
          Container(
            height: 24,
            width: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 16),

          // 2. Stat Badges Grid (Present, Absent, Late, Excused)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _desktopStatBadge(
                    context,
                    'Present',
                    presentCount,
                    total,
                    attTheme.present,
                    attTheme.presentBg,
                    Icons.check_circle_outline_rounded,
                  ),
                  const SizedBox(width: 8),
                  _desktopStatBadge(
                    context,
                    'Absent',
                    absentCount,
                    total,
                    attTheme.absent,
                    attTheme.absentBg,
                    Icons.cancel_outlined,
                  ),
                  const SizedBox(width: 8),
                  _desktopStatBadge(
                    context,
                    'Late',
                    lateCount,
                    total,
                    attTheme.late,
                    attTheme.lateBg,
                    Icons.access_time_rounded,
                  ),
                  const SizedBox(width: 8),
                  _desktopStatBadge(
                    context,
                    'Excused',
                    excusedCount,
                    total,
                    attTheme.excused,
                    attTheme.excusedBg,
                    Icons.verified_user_outlined,
                  ),
                ],
              ),
            ),
          ),

          // 3. Quick Action Buttons
          if (!isClosed) ...[
            const SizedBox(width: 16),
            Container(
              height: 24,
              width: 1,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onMarkAllPresent != null)
                  InkWell(
                    onTap: onMarkAllPresent,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: attTheme.presentBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: attTheme.present.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.done_all_rounded, size: 14, color: attTheme.present),
                          const SizedBox(width: 4),
                          Text(
                            'All Present',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: attTheme.present,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                if (onMarkAllAbsent != null)
                  InkWell(
                    onTap: onMarkAllAbsent,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: attTheme.absentBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: attTheme.absent.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.remove_done_rounded, size: 14, color: attTheme.absent),
                          const SizedBox(width: 4),
                          Text(
                            'All Absent',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: attTheme.absent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (onLockSession != null) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Finalize & Lock Session',
                    icon: Icon(
                      Icons.lock_outline_rounded,
                      color: attTheme.late,
                      size: 18,
                    ),
                    onPressed: onLockSession,
                    style: IconButton.styleFrom(
                      backgroundColor: attTheme.lateBg,
                      padding: const EdgeInsets.all(6),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _desktopStatBadge(
    BuildContext context,
    String label,
    int count,
    int total,
    Color fgColor,
    Color bgColor,
    IconData icon,
  ) {
    final pct = total > 0 ? ((count / total) * 100).toStringAsFixed(0) : '0';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fgColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fgColor, size: 15),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              color: fgColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '$count ',
            style: TextStyle(
              color: fgColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '($pct%)',
            style: TextStyle(
              color: fgColor.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

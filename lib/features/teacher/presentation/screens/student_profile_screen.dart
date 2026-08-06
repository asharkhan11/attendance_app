import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../models/app_models.dart';

class StudentProfileScreen extends StatelessWidget {
  final Student student;
  final String className;
  final double attendancePct;
  final int totalPresent;
  final int totalAbsent;
  final int totalLate;
  final int totalExcused;

  const StudentProfileScreen({
    super.key,
    required this.student,
    required this.className,
    required this.attendancePct,
    required this.totalPresent,
    required this.totalAbsent,
    required this.totalLate,
    required this.totalExcused,
  });

  /// Opens the student details overlay as a Modal Bottom Sheet on mobile screens
  /// and as a centered Modal Dialog on desktop / wider screens.
  static void show(
    BuildContext context, {
    required Student student,
    required String className,
    required double attendancePct,
    required int totalPresent,
    required int totalAbsent,
    required int totalLate,
    required int totalExcused,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: StudentProfileScreen(
            student: student,
            className: className,
            attendancePct: attendancePct,
            totalPresent: totalPresent,
            totalAbsent: totalAbsent,
            totalLate: totalLate,
            totalExcused: totalExcused,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 680,
              maxHeight: MediaQuery.of(context).size.height * 0.80,
            ),
            child: StudentProfileScreen(
              student: student,
              className: className,
              attendancePct: attendancePct,
              totalPresent: totalPresent,
              totalAbsent: totalAbsent,
              totalLate: totalLate,
              totalExcused: totalExcused,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : 'S';
    final totalSessions = totalPresent + totalAbsent + totalLate + totalExcused;
    final isWide = MediaQuery.of(context).size.width >= 600;

    final pctColor = attendancePct >= 85
        ? const Color(0xFF059669)
        : (attendancePct >= 75 ? const Color(0xFFD97706) : const Color(0xFFEF4444));

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            // Mobile drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ─── Compact Header Banner ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
              child: Row(
                children: [
                  Hero(
                    tag: 'student_avatar_${student.id}',
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: theme.primaryColor.withValues(alpha: 0.12),
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          student.fullName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Class $className • Roll #${student.rollNumber} • Adm: ${student.admissionNumber}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Overall Attendance Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: pctColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: pctColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${attendancePct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: pctColor,
                          ),
                        ),
                        Text(
                          '$totalSessions sessions',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: pctColor.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ─── Content Body ───────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── Compact Metrics Bar ─────────────────────────────────────
                    Row(
                      children: [
                        Expanded(child: _miniStatChip('Present', '$totalPresent', const Color(0xFF059669))),
                        const SizedBox(width: 6),
                        Expanded(child: _miniStatChip('Absent', '$totalAbsent', const Color(0xFFEF4444))),
                        const SizedBox(width: 6),
                        Expanded(child: _miniStatChip('Late', '$totalLate', const Color(0xFFD97706))),
                        const SizedBox(width: 6),
                        Expanded(child: _miniStatChip('Excused', '$totalExcused', const Color(0xFF3B82F6))),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ─── Detailed Section (Desktop 2-Col vs Mobile Stack) ────────
                    if (isWide)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left Col: Attendance Donut Chart
                            Expanded(
                              flex: 5,
                              child: _chartCard(context, totalSessions),
                            ),
                            const SizedBox(width: 12),
                            // Right Col: Student Details
                            Expanded(
                              flex: 6,
                              child: _infoCard(context),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      if (totalSessions > 0) _chartCard(context, totalSessions),
                      if (totalSessions > 0) const SizedBox(height: 12),
                      _infoCard(context),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStatChip(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _chartCard(BuildContext context, int totalSessions) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Attendance Distribution',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (totalSessions == 0)
            const SizedBox(
              height: 120,
              child: Center(
                child: Text('No attendance records', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: Stack(
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 36,
                      sections: [
                        if (totalPresent > 0)
                          PieChartSectionData(
                            value: totalPresent.toDouble(),
                            color: const Color(0xFF059669),
                            title: '$totalPresent',
                            titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (totalAbsent > 0)
                          PieChartSectionData(
                            value: totalAbsent.toDouble(),
                            color: const Color(0xFFEF4444),
                            title: '$totalAbsent',
                            titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (totalLate > 0)
                          PieChartSectionData(
                            value: totalLate.toDouble(),
                            color: const Color(0xFFD97706),
                            title: '$totalLate',
                            titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (totalExcused > 0)
                          PieChartSectionData(
                            value: totalExcused.toDouble(),
                            color: const Color(0xFF3B82F6),
                            title: '$totalExcused',
                            titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${attendancePct.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const Text(
                          'Rate',
                          style: TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoCard(BuildContext context) {
    final theme = Theme.of(context);
    final genderStr = student.gender == 'M' ? 'Male' : (student.gender == 'F' ? 'Female' : (student.gender ?? 'N/A'));
    final dobStr = student.dob != null && student.dob!.isNotEmpty ? student.dob!.split('T')[0] : 'N/A';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Student Information',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _infoRow(Icons.badge_outlined, 'Admission No', student.admissionNumber),
          _infoRow(Icons.person_outline, 'Gender', genderStr),
          _infoRow(Icons.cake_outlined, 'Date of Birth', dobStr),
          _infoRow(Icons.family_restroom_outlined, 'Guardian', student.guardianName ?? 'N/A'),
          _infoRow(Icons.phone_outlined, 'Phone', student.guardianPhone ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}


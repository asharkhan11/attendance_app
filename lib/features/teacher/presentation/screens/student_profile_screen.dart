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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : 'S';
    final totalSessions = totalPresent + totalAbsent + totalLate + totalExcused;

    final pctColor = attendancePct >= 85
        ? const Color(0xFF059669)
        : (attendancePct >= 75 ? const Color(0xFFD97706) : const Color(0xFFEF4444));

    return Scaffold(
      appBar: AppBar(
        title: Text('${student.fullName} • Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ─── Header Card ────────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Hero(
                      tag: 'student_avatar_${student.id}',
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      student.fullName,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(
                        'Class $className • Roll #${student.rollNumber}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: theme.primaryColor.withValues(alpha: 0.08),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ─── KPI Stats Row ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _statTile(context, 'Attendance', '${attendancePct.toStringAsFixed(1)}%', pctColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statTile(context, 'Total Sessions', '$totalSessions', theme.colorScheme.primary),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: _miniStatCard('Present', '$totalPresent', const Color(0xFF059669))),
                const SizedBox(width: 8),
                Expanded(child: _miniStatCard('Absent', '$totalAbsent', const Color(0xFFEF4444))),
                const SizedBox(width: 8),
                Expanded(child: _miniStatCard('Late', '$totalLate', const Color(0xFFD97706))),
                const SizedBox(width: 8),
                Expanded(child: _miniStatCard('Excused', '$totalExcused', const Color(0xFF3B82F6))),
              ],
            ),

            const SizedBox(height: 20),

            // ─── Attendance Pie Breakdown ──────────────────────────────────
            if (totalSessions > 0)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance Distribution',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 180,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: [
                              if (totalPresent > 0)
                                PieChartSectionData(
                                  value: totalPresent.toDouble(),
                                  color: const Color(0xFF059669),
                                  title: 'P: $totalPresent',
                                  titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              if (totalAbsent > 0)
                                PieChartSectionData(
                                  value: totalAbsent.toDouble(),
                                  color: const Color(0xFFEF4444),
                                  title: 'A: $totalAbsent',
                                  titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              if (totalLate > 0)
                                PieChartSectionData(
                                  value: totalLate.toDouble(),
                                  color: const Color(0xFFD97706),
                                  title: 'L: $totalLate',
                                  titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              if (totalExcused > 0)
                                PieChartSectionData(
                                  value: totalExcused.toDouble(),
                                  color: const Color(0xFF3B82F6),
                                  title: 'E: $totalExcused',
                                  titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // ─── Details Section ───────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Student Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _infoRow(Icons.badge_outlined, 'Admission Number', student.admissionNumber),
                    _infoRow(Icons.person_outline, 'Gender', student.gender == 'M' ? 'Male' : (student.gender == 'F' ? 'Female' : 'Other')),
                    _infoRow(Icons.cake_outlined, 'Date of Birth', student.dob != null && student.dob!.isNotEmpty ? student.dob!.split('T')[0] : 'N/A'),
                    _infoRow(Icons.family_restroom_outlined, 'Guardian Name', student.guardianName ?? 'N/A'),
                    _infoRow(Icons.phone_outlined, 'Guardian Phone', student.guardianPhone ?? 'N/A'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(BuildContext context, String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _miniStatCard(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(count, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

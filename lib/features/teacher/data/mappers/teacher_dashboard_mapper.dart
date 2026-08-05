import 'package:flutter/material.dart';
import '../../../../design_system/attendance_theme.dart';
import '../../../../shared/domain/entities/defaulter_entry.dart';
import '../../../../shared/domain/entities/kpi_metric.dart';
import '../../domain/entities/student_monthly_row.dart';
import '../../domain/entities/teacher_dashboard_data.dart';

abstract final class TeacherDashboardMapper {
  static TeacherDashboardData fromMap(
    String classId,
    String className,
    Map<String, dynamic> json,
  ) {
    final overallPct =
        (json['overall_attendance_percentage'] as num?)?.toDouble() ??
            (json['attendance_percentage'] as num?)?.toDouble() ??
            0.0;
    final totalStudents = (json['total_students'] as num?)?.toInt() ?? 0;
    final presentCount = (json['present_count'] as num?)?.toInt() ?? 0;
    final absentCount = (json['absent_count'] as num?)?.toInt() ?? 0;
    final lateCount = (json['late_count'] as num?)?.toInt() ?? 0;
    final defaultersList = (json['defaulters'] as List?) ?? [];

    final kpis = [
      KpiMetric(
        title: 'Attendance',
        value: '${overallPct.toStringAsFixed(1)}%',
        icon: Icons.bar_chart,
        color: overallPct >= 75
            ? AttendanceTheme.light.present
            : AttendanceTheme.light.absent,
      ),
      KpiMetric(
        title: 'Total Students',
        value: '$totalStudents',
        icon: Icons.people_outline,
        color: Colors.blue.shade700,
      ),
      KpiMetric(
        title: 'Present Today',
        value: '$presentCount',
        icon: Icons.check_circle_outline,
        color: AttendanceTheme.light.present,
      ),
      KpiMetric(
        title: 'Absent Today',
        value: '$absentCount',
        icon: Icons.cancel_outlined,
        color: AttendanceTheme.light.absent,
      ),
      KpiMetric(
        title: 'Late Today',
        value: '$lateCount',
        icon: Icons.access_time,
        color: AttendanceTheme.light.late,
      ),
      KpiMetric(
        title: 'Defaulters (<75%)',
        value: '${defaultersList.length}',
        icon: Icons.warning_amber_rounded,
        color: defaultersList.isEmpty
            ? AttendanceTheme.light.present
            : AttendanceTheme.light.absent,
      ),
    ];

    final studentsRaw = (json['students'] as List?) ?? [];
    final monthlyRows = studentsRaw.map((s) {
      final map = s is Map<String, dynamic> ? s : Map<String, dynamic>.from(s);
      final dailyMap =
          (map['daily_status'] as Map?) ?? (map['daily'] as Map?) ?? {};
      final String studentId = (map['student_id'] ?? map['id'] ?? '').toString();

      return StudentMonthlyRow(
        studentId: studentId,
        fullName: (map['full_name'] ?? '').toString(),
        rollNumber: (map['roll_number'] ?? '').toString(),
        admissionNumber: (map['admission_number'] ?? 'N/A').toString(),
        dailyStatus: dailyMap.map((k, v) => MapEntry(k.toString(), v.toString())),
        totalPresent: (map['total_present'] as num?)?.toInt() ?? 0,
        totalAbsent: (map['total_absent'] as num?)?.toInt() ?? 0,
        totalLate: (map['total_late'] as num?)?.toInt() ?? 0,
        totalExcused: (map['total_excused'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    final defaulters = defaultersList.map((d) {
      final map = d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d);
      return DefaulterEntry(
        studentId: (map['student_id'] ?? map['id'] ?? '').toString(),
        fullName: (map['full_name'] ?? '').toString(),
        rollNumber: (map['roll_number'] ?? '').toString(),
        admissionNumber: (map['admission_number'] ?? 'N/A').toString(),
        className: className,
        guardianName: map['guardian_name']?.toString(),
        guardianPhone: map['guardian_phone']?.toString(),
        presentCount: (map['present_count'] ?? map['present'] ?? 0) as int,
        totalSessions: (map['total_sessions'] ?? 0) as int,
        attendancePercentage:
            (map['attendance_percentage'] ?? map['attendance_pct'] ?? 0.0)
                as double,
      );
    }).toList();

    return TeacherDashboardData(
      classId: classId,
      className: className,
      kpis: kpis,
      monthlyRows: monthlyRows,
      defaulters: defaulters,
    );
  }
}

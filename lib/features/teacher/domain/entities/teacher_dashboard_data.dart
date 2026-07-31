import 'package:flutter/foundation.dart';
import '../../../../shared/domain/entities/defaulter_entry.dart';
import '../../../../shared/domain/entities/kpi_metric.dart';
import 'student_monthly_row.dart';

@immutable
class TeacherDashboardData {
  final String classId;
  final String className;
  final List<KpiMetric> kpis;
  final List<StudentMonthlyRow> monthlyRows;
  final List<DefaulterEntry> defaulters;

  const TeacherDashboardData({
    required this.classId,
    required this.className,
    required this.kpis,
    required this.monthlyRows,
    required this.defaulters,
  });

  TeacherDashboardData copyWith({
    String? classId,
    String? className,
    List<KpiMetric>? kpis,
    List<StudentMonthlyRow>? monthlyRows,
    List<DefaulterEntry>? defaulters,
  }) {
    return TeacherDashboardData(
      classId: classId ?? this.classId,
      className: className ?? this.className,
      kpis: kpis ?? this.kpis,
      monthlyRows: monthlyRows ?? this.monthlyRows,
      defaulters: defaulters ?? this.defaulters,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherDashboardData &&
          runtimeType == other.runtimeType &&
          classId == other.classId &&
          className == other.className;

  @override
  int get hashCode => classId.hashCode ^ className.hashCode;
}

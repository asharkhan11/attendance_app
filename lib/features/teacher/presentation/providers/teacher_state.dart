import 'package:flutter/foundation.dart';
import '../../../../models/app_models.dart';
import '../../domain/entities/teacher_dashboard_data.dart';

@immutable
class TeacherDashboardState {
  final SchoolClass? selectedClass;
  final DateTime selectedDate;
  final bool isHoliday;
  final String? holidayName;
  final TeacherDashboardData? data;

  const TeacherDashboardState({
    this.selectedClass,
    required this.selectedDate,
    this.isHoliday = false,
    this.holidayName,
    this.data,
  });

  TeacherDashboardState copyWith({
    SchoolClass? selectedClass,
    DateTime? selectedDate,
    bool? isHoliday,
    String? holidayName,
    TeacherDashboardData? data,
  }) {
    return TeacherDashboardState(
      selectedClass: selectedClass ?? this.selectedClass,
      selectedDate: selectedDate ?? this.selectedDate,
      isHoliday: isHoliday ?? this.isHoliday,
      holidayName: holidayName ?? this.holidayName,
      data: data ?? this.data,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherDashboardState &&
          runtimeType == other.runtimeType &&
          selectedClass == other.selectedClass &&
          selectedDate == other.selectedDate &&
          isHoliday == other.isHoliday &&
          holidayName == other.holidayName &&
          data == other.data;

  @override
  int get hashCode =>
      selectedClass.hashCode ^
      selectedDate.hashCode ^
      isHoliday.hashCode ^
      holidayName.hashCode ^
      data.hashCode;
}

import 'package:flutter/foundation.dart';

@immutable
class StudentMonthlyRow {
  final String studentId;
  final String fullName;
  final String rollNumber;
  final String admissionNumber;
  final Map<String, String> dailyStatus; // e.g. "2026-07-01": "P"
  final int totalPresent;
  final int totalAbsent;
  final int totalLate;
  final int totalExcused;

  const StudentMonthlyRow({
    required this.studentId,
    required this.fullName,
    required this.rollNumber,
    required this.admissionNumber,
    required this.dailyStatus,
    required this.totalPresent,
    required this.totalAbsent,
    required this.totalLate,
    required this.totalExcused,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentMonthlyRow &&
          runtimeType == other.runtimeType &&
          studentId == other.studentId &&
          fullName == other.fullName &&
          rollNumber == other.rollNumber &&
          admissionNumber == other.admissionNumber &&
          totalPresent == other.totalPresent &&
          totalAbsent == other.totalAbsent &&
          totalLate == other.totalLate &&
          totalExcused == other.totalExcused;

  @override
  int get hashCode =>
      studentId.hashCode ^
      fullName.hashCode ^
      rollNumber.hashCode ^
      admissionNumber.hashCode ^
      totalPresent.hashCode ^
      totalAbsent.hashCode ^
      totalLate.hashCode ^
      totalExcused.hashCode;
}

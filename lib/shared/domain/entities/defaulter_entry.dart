import 'package:flutter/foundation.dart';

@immutable
class DefaulterEntry {
  final String studentId;
  final String fullName;
  final String rollNumber;
  final String admissionNumber;
  final String className;
  final String? guardianName;
  final String? guardianPhone;
  final int presentCount;
  final int totalSessions;
  final double attendancePercentage;

  const DefaulterEntry({
    required this.studentId,
    required this.fullName,
    required this.rollNumber,
    required this.admissionNumber,
    required this.className,
    this.guardianName,
    this.guardianPhone,
    required this.presentCount,
    required this.totalSessions,
    required this.attendancePercentage,
  });

  DefaulterEntry copyWith({
    String? studentId,
    String? fullName,
    String? rollNumber,
    String? admissionNumber,
    String? className,
    String? guardianName,
    String? guardianPhone,
    int? presentCount,
    int? totalSessions,
    double? attendancePercentage,
  }) {
    return DefaulterEntry(
      studentId: studentId ?? this.studentId,
      fullName: fullName ?? this.fullName,
      rollNumber: rollNumber ?? this.rollNumber,
      admissionNumber: admissionNumber ?? this.admissionNumber,
      className: className ?? this.className,
      guardianName: guardianName ?? this.guardianName,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      presentCount: presentCount ?? this.presentCount,
      totalSessions: totalSessions ?? this.totalSessions,
      attendancePercentage: attendancePercentage ?? this.attendancePercentage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DefaulterEntry &&
          runtimeType == other.runtimeType &&
          studentId == other.studentId &&
          fullName == other.fullName &&
          rollNumber == other.rollNumber &&
          admissionNumber == other.admissionNumber &&
          className == other.className &&
          guardianName == other.guardianName &&
          guardianPhone == other.guardianPhone &&
          presentCount == other.presentCount &&
          totalSessions == other.totalSessions &&
          attendancePercentage == other.attendancePercentage;

  @override
  int get hashCode =>
      studentId.hashCode ^
      fullName.hashCode ^
      rollNumber.hashCode ^
      admissionNumber.hashCode ^
      className.hashCode ^
      guardianName.hashCode ^
      guardianPhone.hashCode ^
      presentCount.hashCode ^
      totalSessions.hashCode ^
      attendancePercentage.hashCode;
}

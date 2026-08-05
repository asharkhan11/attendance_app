import 'package:flutter/material.dart';

@immutable
class AttendanceTheme extends ThemeExtension<AttendanceTheme> {
  final Color present;
  final Color absent;
  final Color late;
  final Color excused;
  final Color noRecord;

  final Color presentBg;
  final Color absentBg;
  final Color lateBg;
  final Color excusedBg;
  final Color noRecordBg;

  const AttendanceTheme({
    required this.present,
    required this.absent,
    required this.late,
    required this.excused,
    required this.noRecord,
    required this.presentBg,
    required this.absentBg,
    required this.lateBg,
    required this.excusedBg,
    required this.noRecordBg,
  });

  static const light = AttendanceTheme(
    present: Color(0xFF059669), // Emerald 600
    absent: Color(0xFFEF4444), // Red 500
    late: Color(0xFFD97706), // Amber 600
    excused: Color(0xFF3B82F6), // Blue 500
    noRecord: Color(0xFF94A3B8), // Slate 400
    presentBg: Color(0xFFECFDF5), // Emerald 50
    absentBg: Color(0xFFFEF2F2), // Red 50
    lateBg: Color(0xFFFFFBEB), // Amber 50
    excusedBg: Color(0xFFEFF6FF), // Blue 50
    noRecordBg: Color(0xFFF1F5F9), // Slate 100
  );

  static const dark = AttendanceTheme(
    present: Color(0xFF34D399), // Emerald 400
    absent: Color(0xFFF87171), // Red 400
    late: Color(0xFFFBBF24), // Amber 400
    excused: Color(0xFF60A5FA), // Blue 400
    noRecord: Color(0xFF64748B), // Slate 500
    presentBg: Color(0xFF064E3B), // Emerald 900
    absentBg: Color(0xFF7F1D1D), // Red 900
    lateBg: Color(0xFF78350F), // Amber 900
    excusedBg: Color(0xFF1E3A5F), // Blue 900
    noRecordBg: Color(0xFF1E293B), // Slate 800
  );

  @override
  AttendanceTheme copyWith({
    Color? present,
    Color? absent,
    Color? late,
    Color? excused,
    Color? noRecord,
    Color? presentBg,
    Color? absentBg,
    Color? lateBg,
    Color? excusedBg,
    Color? noRecordBg,
  }) {
    return AttendanceTheme(
      present: present ?? this.present,
      absent: absent ?? this.absent,
      late: late ?? this.late,
      excused: excused ?? this.excused,
      noRecord: noRecord ?? this.noRecord,
      presentBg: presentBg ?? this.presentBg,
      absentBg: absentBg ?? this.absentBg,
      lateBg: lateBg ?? this.lateBg,
      excusedBg: excusedBg ?? this.excusedBg,
      noRecordBg: noRecordBg ?? this.noRecordBg,
    );
  }

  @override
  AttendanceTheme lerp(ThemeExtension<AttendanceTheme>? other, double t) {
    if (other is! AttendanceTheme) return this;
    return AttendanceTheme(
      present: Color.lerp(present, other.present, t)!,
      absent: Color.lerp(absent, other.absent, t)!,
      late: Color.lerp(late, other.late, t)!,
      excused: Color.lerp(excused, other.excused, t)!,
      noRecord: Color.lerp(noRecord, other.noRecord, t)!,
      presentBg: Color.lerp(presentBg, other.presentBg, t)!,
      absentBg: Color.lerp(absentBg, other.absentBg, t)!,
      lateBg: Color.lerp(lateBg, other.lateBg, t)!,
      excusedBg: Color.lerp(excusedBg, other.excusedBg, t)!,
      noRecordBg: Color.lerp(noRecordBg, other.noRecordBg, t)!,
    );
  }
}

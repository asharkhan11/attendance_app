import 'package:flutter/material.dart';
import '../../design_system/app_radius.dart';
import '../../design_system/attendance_theme.dart';

class AttendanceBadge extends StatelessWidget {
  final String code; // 'P', 'A', 'L', 'E', '-'
  final double size;

  const AttendanceBadge({
    super.key,
    required this.code,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).extension<AttendanceTheme>() ?? AttendanceTheme.light;

    Color bg;
    Color text;

    switch (code) {
      case 'P':
        bg = theme.presentBg;
        text = theme.present;
        break;
      case 'A':
        bg = theme.absentBg;
        text = theme.absent;
        break;
      case 'L':
        bg = theme.lateBg;
        text = theme.late;
        break;
      case 'E':
        bg = theme.excusedBg;
        text = theme.excused;
        break;
      default:
        bg = theme.noRecordBg;
        text = theme.noRecord;
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm / 2),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontSize: size * 0.5,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }
}

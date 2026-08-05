import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/design_system/attendance_theme.dart';
import 'package:attendance_app/features/teacher/domain/entities/student_monthly_row.dart';
import 'package:attendance_app/features/teacher/presentation/widgets/monthly_grid_student_card.dart';

void main() {
  testWidgets('MonthlyGridStudentCard renders student name and present/absent counts', (tester) async {
    final student = StudentMonthlyRow(
      studentId: 'st_1',
      fullName: 'Rahul Sharma',
      rollNumber: '01',
      admissionNumber: '2024001',
      dailyStatus: const {'2026-07-01': 'P', '2026-07-02': 'A'},
      totalPresent: 22,
      totalAbsent: 4,
      totalLate: 1,
      totalExcused: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [AttendanceTheme.light]),
        home: Scaffold(
          body: MonthlyGridStudentCard(
            student: student,
            daysInMonth: 30,
            selectedDate: DateTime(2026, 7, 1),
          ),
        ),
      ),
    );

    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('P: 22'), findsOneWidget);
    expect(find.text('A: 4'), findsOneWidget);
  });
}

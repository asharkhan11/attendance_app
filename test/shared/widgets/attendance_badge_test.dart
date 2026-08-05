import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/design_system/attendance_theme.dart';
import 'package:attendance_app/shared/widgets/attendance_badge.dart';

void main() {
  testWidgets('AttendanceBadge renders code text correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const [AttendanceTheme.light],
        ),
        home: const Scaffold(
          body: Row(
            children: [
              AttendanceBadge(code: 'P'),
              AttendanceBadge(code: 'A'),
              AttendanceBadge(code: 'L'),
              AttendanceBadge(code: 'E'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('P'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);
    expect(find.text('E'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/design_system/attendance_theme.dart';
import 'package:attendance_app/features/attendance/presentation/widgets/roster_item.dart';
import 'package:attendance_app/models/app_models.dart';

void main() {
  testWidgets('RosterItem renders student name and status buttons on mobile', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;

    final entry = RosterEntry(
      studentId: 'st_1',
      rollNumber: '01',
      fullName: 'Rahul Sharma',
      status: 'present',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [AttendanceTheme.light]),
        home: Scaffold(
          body: RosterItem(entry: entry),
        ),
      ),
    );

    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('P'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);
    expect(find.text('E'), findsOneWidget);
  });
}

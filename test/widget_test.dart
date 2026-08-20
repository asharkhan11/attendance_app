import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:attendance_app/main.dart';

void main() {
  testWidgets('AttendanceApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AttendanceApp()));
    expect(find.byType(AttendanceApp), findsOneWidget);
  });
}


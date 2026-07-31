import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/shared/domain/entities/kpi_metric.dart';
import 'package:attendance_app/shared/widgets/kpi_card.dart';

void main() {
  testWidgets('KpiCard renders title, value and icon', (tester) async {
    const metric = KpiMetric(
      title: 'Present Students',
      value: '42',
      icon: Icons.check_circle,
      color: Colors.green,
      subtitle: '92% of roster',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KpiCard(metric: metric),
        ),
      ),
    );

    expect(find.text('Present Students'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('92% of roster'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}

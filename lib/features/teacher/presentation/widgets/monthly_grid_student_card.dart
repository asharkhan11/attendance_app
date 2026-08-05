import 'package:flutter/material.dart';
import '../../../../design_system/app_radius.dart';
import '../../../../design_system/app_spacing.dart';
import '../../../../shared/widgets/attendance_badge.dart';
import '../../domain/entities/student_monthly_row.dart';

class MonthlyGridStudentCard extends StatelessWidget {
  final StudentMonthlyRow student;
  final int daysInMonth;
  final DateTime selectedDate;
  final VoidCallback? onTap;

  const MonthlyGridStudentCard({
    super.key,
    required this.student,
    required this.daysInMonth,
    required this.selectedDate,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('student_card_${student.studentId}'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorderRadius,
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardBorderRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          child: Text(
                            student.rollNumber,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            student.fullName,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(AppRadius.sm / 2),
                        ),
                        child: Text(
                          'P: ${student.totalPresent}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(AppRadius.sm / 2),
                        ),
                        child: Text(
                          'A: ${student.totalAbsent}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(daysInMonth, (i) {
                    final dayNum = i + 1;
                    final isSelected = dayNum == selectedDate.day;
                    final dateKey =
                        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}";
                    final code = student.dailyStatus[dateKey] ??
                        student.dailyStatus[dayNum.toString()] ??
                        '-';

                    return Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                        decoration: isSelected
                            ? BoxDecoration(
                                color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Theme.of(context).primaryColor, width: 1.5),
                              )
                            : null,
                        child: Column(
                          children: [
                            Text(
                              '$dayNum',
                              style: TextStyle(
                                fontSize: isSelected ? 10 : 9,
                                color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            AttendanceBadge(code: code, size: 22),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

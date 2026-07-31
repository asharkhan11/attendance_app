import 'package:flutter/material.dart';
import '../../../../design_system/app_spacing.dart';
import '../../../../shared/widgets/app_skeleton.dart';

class TeacherDashboardSkeleton extends StatelessWidget {
  const TeacherDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSkeleton(width: double.infinity, height: 80),
          const SizedBox(height: AppSpacing.md),
          const AppSkeleton(width: double.infinity, height: 50),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: const [
              Expanded(child: AppSkeleton(width: double.infinity, height: 90)),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: AppSkeleton(width: double.infinity, height: 90)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const AppSkeleton(width: double.infinity, height: 200),
        ],
      ),
    );
  }
}

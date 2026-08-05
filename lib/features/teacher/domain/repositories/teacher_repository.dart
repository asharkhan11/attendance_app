import '../../../../core/result.dart';
import '../../../../shared/domain/entities/defaulter_entry.dart';
import '../entities/teacher_dashboard_data.dart';

abstract interface class TeacherRepository {
  Future<Result<TeacherDashboardData>> getDashboard({
    required String classId,
    required DateTime month,
  });

  Future<Result<List<DefaulterEntry>>> getDefaulters({
    required String classId,
    double threshold,
  });
}

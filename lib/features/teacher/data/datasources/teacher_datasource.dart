import '../../../../core/app_error.dart';
import '../../../../core/result.dart';
import '../../../../services/api_service.dart';
import '../../domain/entities/teacher_dashboard_data.dart';
import '../mappers/teacher_dashboard_mapper.dart';

class TeacherDatasource {
  final ApiService _apiService;

  TeacherDatasource(this._apiService);

  Future<Result<TeacherDashboardData>> fetchDashboardData({
    required String classId,
    required String className,
    required int year,
    required int month,
  }) async {
    try {
      final res = await _apiService.getMonthlyMatrix(
        classId,
        year: year,
        month: month,
      );
      final json = res is Map<String, dynamic>
          ? res
          : (res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{});
      final entity = TeacherDashboardMapper.fromMap(classId, className, json);
      return Result.success(entity);
    } catch (e, st) {
      return Result.failure(AppError.unexpected(e, st));
    }
  }
}

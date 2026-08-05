import '../../../../core/app_constants.dart';
import '../../../../core/cache/memory_cache.dart';
import '../../../../core/result.dart';
import '../../../../shared/domain/entities/defaulter_entry.dart';
import '../../domain/entities/teacher_dashboard_data.dart';
import '../../domain/repositories/teacher_repository.dart';
import '../datasources/teacher_datasource.dart';

class TeacherRepositoryImpl implements TeacherRepository {
  final TeacherDatasource _datasource;
  final MemoryCache<String, TeacherDashboardData> _cache;

  TeacherRepositoryImpl(this._datasource)
      : _cache = MemoryCache<String, TeacherDashboardData>(
          ttl: AppConstants.kAnalyticsCacheTtl,
          maxSize: 20,
        );

  @override
  Future<Result<TeacherDashboardData>> getDashboard({
    required String classId,
    required DateTime month,
  }) async {
    final cacheKey = 'dashboard-$classId-${month.year}-${month.month}';
    final cached = _cache.get(cacheKey);
    if (cached != null) {
      return Result.success(cached);
    }

    final result = await _datasource.fetchDashboardData(
      classId: classId,
      className: 'Class',
      year: month.year,
      month: month.month,
    );

    result.whenSuccess((data) => _cache.put(cacheKey, data));
    return result;
  }

  @override
  Future<Result<List<DefaulterEntry>>> getDefaulters({
    required String classId,
    double threshold = AppConstants.kDefaultAttendanceThreshold,
  }) async {
    final now = DateTime.now();
    final dashboardResult = await getDashboard(classId: classId, month: now);

    return dashboardResult.when(
      success: (data) => Result.success(data.defaulters),
      failure: (error) => Result.failure(error),
    );
  }
}

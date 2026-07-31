import '../../../../core/result.dart';
import '../../../../shared/domain/entities/defaulter_entry.dart';
import '../entities/admin_analytics_data.dart';

abstract interface class AnalyticsRepository {
  Future<Result<AdminAnalyticsData>> getOverview({
    String? classId,
    double threshold,
  });

  Future<Result<List<DefaulterEntry>>> getSchoolDefaulters({
    String? classId,
    double threshold,
    String? from,
    String? to,
  });
}

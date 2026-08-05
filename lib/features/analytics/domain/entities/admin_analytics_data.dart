import 'package:flutter/foundation.dart';
import '../../../../shared/domain/entities/defaulter_entry.dart';
import '../../../../shared/domain/entities/kpi_metric.dart';

@immutable
class AdminAnalyticsData {
  final String? selectedClassId;
  final double threshold;
  final List<KpiMetric> overviewKpis;
  final List<DefaulterEntry> defaulters;

  const AdminAnalyticsData({
    this.selectedClassId,
    required this.threshold,
    required this.overviewKpis,
    required this.defaulters,
  });

  AdminAnalyticsData copyWith({
    String? selectedClassId,
    double? threshold,
    List<KpiMetric>? overviewKpis,
    List<DefaulterEntry>? defaulters,
  }) {
    return AdminAnalyticsData(
      selectedClassId: selectedClassId ?? this.selectedClassId,
      threshold: threshold ?? this.threshold,
      overviewKpis: overviewKpis ?? this.overviewKpis,
      defaulters: defaulters ?? this.defaulters,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminAnalyticsData &&
          runtimeType == other.runtimeType &&
          selectedClassId == other.selectedClassId &&
          threshold == other.threshold;

  @override
  int get hashCode => selectedClassId.hashCode ^ threshold.hashCode;
}

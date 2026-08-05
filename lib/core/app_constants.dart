/// Application-wide constants.
///
/// Centralising magic values here prevents inconsistencies across screens
/// (e.g. three different breakpoint values for "wide" layout were previously
/// scattered as 700, 720, and 768 in three different files).
abstract final class AppConstants {
  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  /// Minimum width (dp) at which the UI switches to a wide/desktop layout.
  static const double kWideBreakpoint = 768.0;

  /// Fixed height for analytics charts (BarChart, LineChart).
  static const double kChartHeight = 240.0;

  /// Fixed row height for the student roster ListView.
  ///
  /// Providing a uniform [itemExtent] to [ListView] eliminates per-item
  /// layout measurement and significantly improves scroll performance.
  static const double kRosterItemExtent = 68.0;

  /// Pixel distance to pre-render beyond the visible viewport.
  /// Start at 400.0 and tune in Phase 9 profiling based on memory vs jank.
  static const double kListCacheExtent = 400.0;

  // ---------------------------------------------------------------------------
  // Business rules
  // ---------------------------------------------------------------------------

  /// Default attendance threshold below which a student is flagged as a defaulter.
  static const double kDefaultAttendanceThreshold = 75.0;

  /// Default number of items to request per paginated API call.
  static const int kDefaultPageSize = 100;

  /// Maximum number of log entries retained by [AppLogger].
  static const int kMaxLogEntries = 250;

  // ---------------------------------------------------------------------------
  // Network
  // ---------------------------------------------------------------------------

  /// Maximum time to wait for any single HTTP request before throwing a
  /// [TimeoutException] and surfacing a user-readable error.
  static const Duration kRequestTimeout = Duration(seconds: 30);

  /// Debounce delay for the analytics filter controls in the admin dashboard.
  ///
  /// Prevents firing a full analytics reload on every keystroke / rapid
  /// dropdown selection — only the final settled value triggers a request.
  static const Duration kAnalyticsDebounce = Duration(milliseconds: 400);

  // ---------------------------------------------------------------------------
  // Cache TTL
  // ---------------------------------------------------------------------------

  /// How long list data (classes, teachers, years) is considered fresh.
  static const Duration kListCacheTtl = Duration(minutes: 5);

  /// How long schedule / holiday data is considered fresh.
  static const Duration kScheduleCacheTtl = Duration(hours: 1);

  /// How long analytics overview data is considered fresh.
  static const Duration kAnalyticsCacheTtl = Duration(minutes: 2);
}

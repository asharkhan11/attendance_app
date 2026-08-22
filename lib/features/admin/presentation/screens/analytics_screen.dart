import 'package:attendance_app/features/teacher/presentation/screens/student_profile_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../design_system/app_breakpoints.dart';
import '../../../../models/app_models.dart';
import '../../../../services/api_service.dart';
import '../../../../widgets/searchable_dropdown.dart';
import '../widgets/analytics_filter_sheet.dart';

class AnalyticsScreen extends StatefulWidget {
  final ApiService api;
  final List<SchoolClass> classes;
  final AcademicYear? selectedYear;
  final void Function(String, {bool error}) snack;

  const AnalyticsScreen({
    super.key,
    required this.api,
    required this.classes,
    required this.selectedYear,
    required this.snack,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  SchoolClass? _selectedClass; // null = All Classes
  String _datePreset = 'month';
  double _threshold = 75;
  bool _loading = false;
  String _defaulterSearchQuery = '';

  Map<String, dynamic>? _overviewData;
  List<dynamic> _trendData = [];
  List<dynamic> _defaultersData = [];
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    _loadAllAnalytics();
  }

  @override
  void didUpdateWidget(covariant AnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedYear?.id != widget.selectedYear?.id) {
      _loadAllAnalytics();
    }
  }

  (String, String) _getDateRange() {
    final now = DateTime.now();
    DateTime toDt = now;

    if (widget.selectedYear != null) {
      final eDate = widget.selectedYear!.endDate.split('T')[0];
      final parsedEnd = DateTime.tryParse(eDate);
      if (parsedEnd != null && parsedEnd.isBefore(now)) {
        toDt = parsedEnd;
      }
    }

    DateTime fromDt;
    switch (_datePreset) {
      case 'week':
        fromDt = toDt.subtract(const Duration(days: 7));
        break;
      case '90days':
        fromDt = toDt.subtract(const Duration(days: 90));
        break;
      case 'all':
        if (widget.selectedYear != null) {
          final sDate = widget.selectedYear!.startDate.split('T')[0];
          fromDt = DateTime.tryParse(sDate) ?? DateTime(2025, 1, 1);
        } else {
          fromDt = DateTime(2025, 1, 1);
        }
        break;
      case 'custom':
        if (_customDateRange != null) {
          fromDt = _customDateRange!.start;
          toDt = _customDateRange!.end;
        } else {
          fromDt = toDt.subtract(const Duration(days: 30));
        }
        break;
      case 'month':
      default:
        fromDt = DateTime(toDt.year, toDt.month, 1);
        break;
    }
    final from =
        "${fromDt.year}-${fromDt.month.toString().padLeft(2, '0')}-${fromDt.day.toString().padLeft(2, '0')}";
    final to =
        "${toDt.year}-${toDt.month.toString().padLeft(2, '0')}-${toDt.day.toString().padLeft(2, '0')}";
    return (from, to);
  }

  Future<void> _loadAllAnalytics() async {
    setState(() => _loading = true);
    try {
      final (from, to) = _getDateRange();
      final ayId = widget.selectedYear?.id;

      final trendGranularity = _datePreset == 'week'
          ? 'day'
          : (_datePreset == '90days' || _datePreset == 'all' ? 'month' : 'week');

      // Fetch all analytics concurrently for lowest latency and zero redundant calls
      final ovFuture = widget.api.getSchoolOverview(
        academicYearId: ayId,
        classId: _selectedClass?.id,
        from: from,
        to: to,
        threshold: _threshold,
      );

      final defFuture = widget.api.getSchoolDefaulters(
        classId: _selectedClass?.id,
        from: from,
        to: to,
        threshold: _threshold,
      );

      final trFuture = _selectedClass == null
          ? widget.api.getSchoolTrend(
              from: from,
              to: to,
              granularity: trendGranularity,
            )
          : widget.api.getClassTrend(
              _selectedClass!.id,
              from: from,
              to: to,
              granularity: trendGranularity,
            );

      final results = await Future.wait([ovFuture, defFuture, trFuture]);
      final ovRes = results[0];
      final defRes = results[1];
      final trRes = results[2];

      if (ovRes is Map && ovRes['data'] != null) {
        _overviewData = Map<String, dynamic>.from(ovRes['data'] as Map);
      } else if (ovRes is Map) {
        _overviewData = Map<String, dynamic>.from(ovRes);
      }

      if (_selectedClass != null) {
        try {
          final clsSum = await widget.api.getClassSummary(
            _selectedClass!.id,
            from: from,
            to: to,
          );
          final summaryMap = (clsSum is Map && clsSum['data'] != null)
              ? clsSum['data'] as Map<String, dynamic>
              : (clsSum is Map ? clsSum as Map<String, dynamic> : null);
          if (summaryMap != null) {
            _overviewData = {
              ...?_overviewData,
              'overall_attendance_pct':
                  summaryMap['attendance_percentage'] ??
                  summaryMap['attendance_pct'] ??
                  summaryMap['overall_attendance_pct'] ??
                  _overviewData?['overall_attendance_pct'],
              'total_students':
                  summaryMap['total_students'] ??
                  _overviewData?['total_students'],
              'total_sessions':
                  summaryMap['total_sessions'] ??
                  _overviewData?['total_sessions'],
              'present_records':
                  summaryMap['present'] ??
                  summaryMap['present_records'] ??
                  _overviewData?['present_records'],
              'absent_records':
                  summaryMap['absent'] ??
                  summaryMap['absent_records'] ??
                  _overviewData?['absent_records'],
              'late_records':
                  summaryMap['late'] ??
                  summaryMap['late_records'] ??
                  _overviewData?['late_records'],
              'excused_records':
                  summaryMap['excused'] ??
                  summaryMap['excused_records'] ??
                  _overviewData?['excused_records'],
              'total_records':
                  summaryMap['total_records'] ??
                  _overviewData?['total_records'],
            };
          }
        } catch (_) {}
      }

      if (defRes is Map && defRes['data'] is List) {
        _defaultersData = defRes['data'] as List;
      } else if (defRes is List) {
        _defaultersData = defRes;
      } else {
        _defaultersData = [];
      }

      if (trRes is Map &&
          trRes['data'] is Map &&
          trRes['data']['trend'] is List) {
        _trendData = trRes['data']['trend'] as List;
      } else if (trRes is Map && trRes['trend'] is List) {
        _trendData = trRes['trend'] as List;
      } else if (trRes is Map && trRes['data'] is List) {
        _trendData = trRes['data'] as List;
      } else if (trRes is List) {
        _trendData = trRes;
      } else {
        _trendData = [];
      }
    } catch (e) {
      widget.snack('Error loading analytics: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDesktop = context.isDesktop;

    if (widget.selectedYear == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: Colors.orange.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Academic Session Selected',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please select an Academic Session to view analytics.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    num? findNum(List<String> keys) {
      for (final k in keys) {
        final val = _overviewData?[k];
        if (val is num) return val;
      }
      return null;
    }

    final double overallPct =
        (findNum([
                  'overall_attendance_pct',
                  'attendance_percentage',
                  'attendance_pct',
                  'overall_attendance_percentage',
                  'attendance_rate',
                  'average_attendance',
                ]) ??
                0.0)
            .toDouble();

    final int totalStudents =
        (findNum([
                  'total_students',
                  'enrolled_students',
                  'student_count',
                  'students_count',
                ]) ??
                0)
            .toInt();

    final int totalClasses =
        (findNum([
                  'total_classes',
                  'classes_count',
                  'class_count',
                ]) ??
                widget.classes.length)
            .toInt();

    final int totalSessions =
        (findNum([
                  'total_sessions',
                  'sessions_conducted',
                  'session_count',
                  'sessions_count',
                ]) ??
                0)
            .toInt();

    int totalDefaulters =
        (findNum(['total_defaulters', 'defaulters_count', 'defaulter_count']) ??
                0)
            .toInt();

    if (totalDefaulters == 0 && _defaultersData.isNotEmpty) {
      totalDefaulters = _defaultersData.length;
    }

    final int presentRecords = (findNum(['present_records', 'present']) ?? 0).toInt();
    final int absentRecords = (findNum(['absent_records', 'absent']) ?? 0).toInt();
    final int lateRecords = (findNum(['late_records', 'late']) ?? 0).toInt();
    final int excusedRecords = (findNum(['excused_records', 'excused']) ?? 0).toInt();
    final int totalRecords = (findNum(['total_records']) ?? (presentRecords + absentRecords + lateRecords + excusedRecords)).toInt();

    final rawComparisons = (_overviewData?['class_comparisons'] as List?) ?? [];
    final classComparisons = _selectedClass == null
        ? rawComparisons
        : rawComparisons.where((c) {
            final cId = c['class_id']?.toString();
            final cName = c['class_name']?.toString() ?? '';
            return (cId != null && cId == _selectedClass!.id) ||
                cName.contains(_selectedClass!.displayName);
          }).toList();

    return RefreshIndicator(
      onRefresh: _loadAllAnalytics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Filter Controls Card ──────────────────────────────────────
            _buildFilterCard(context),

            const SizedBox(height: 16),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(60.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              // ─── KPI Cards Row ───────────────────────────────────────────
              _buildKpiRow(
                theme,
                overallPct: overallPct,
                totalStudents: totalStudents,
                totalClasses: totalClasses,
                totalSessions: totalSessions,
                totalDefaulters: totalDefaulters,
                presentRecords: presentRecords,
                absentRecords: absentRecords,
                lateRecords: lateRecords,
                excusedRecords: excusedRecords,
                totalRecords: totalRecords,
                isDesktop: isDesktop,
              ),

              const SizedBox(height: 20),

              // ─── Charts Section ──────────────────────────────────────────
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildTrendLineChart(theme)),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _selectedClass == null
                          ? _buildClassComparisonBarChart(theme, classComparisons)
                          : _buildClassBreakdownCard(
                              theme,
                              overallPct: overallPct,
                              present: presentRecords,
                              absent: absentRecords,
                              late: lateRecords,
                              excused: excusedRecords,
                              total: totalRecords,
                              totalStudents: totalStudents,
                              defaulters: totalDefaulters,
                            ),
                    ),
                  ],
                )
              else ...[
                _buildTrendLineChart(theme),
                const SizedBox(height: 16),
                if (_selectedClass == null)
                  _buildClassComparisonBarChart(theme, classComparisons)
                else
                  _buildClassBreakdownCard(
                    theme,
                    overallPct: overallPct,
                    present: presentRecords,
                    absent: absentRecords,
                    late: lateRecords,
                    excused: excusedRecords,
                    total: totalRecords,
                    totalStudents: totalStudents,
                    defaulters: totalDefaulters,
                  ),
              ],

              const SizedBox(height: 24),

              // ─── Defaulters List Table ───────────────────────────────────
              _buildDefaultersSection(theme, totalStudents: totalStudents),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Filter Controls Card ───────────────────────────────────────────────────
  Widget _buildFilterCard(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (context.isMobile)
              OutlinedButton.icon(
                icon: const Icon(Icons.filter_list),
                label: const Text('Analytics Filters'),
                onPressed: () => AnalyticsFilterSheet.show(
                  context,
                  classes: widget.classes,
                  selectedClass: _selectedClass,
                  threshold: _threshold,
                  onClassChanged: (c) {
                    setState(() => _selectedClass = c);
                    _loadAllAnalytics();
                  },
                  onThresholdChanged: (t) {
                    setState(() => _threshold = t);
                    _loadAllAnalytics();
                  },
                ),
              )
            else ...[
              SizedBox(
                width: 240,
                child: SearchableDropdown<SchoolClass?>(
                  value: _selectedClass,
                  labelText: 'Class Scope',
                  isDense: true,
                  items: [
                    null,
                    ...(List<SchoolClass>.from(widget.classes)..sort(compareSchoolClasses)),
                  ],
                  itemAsString: (c) =>
                      c == null ? '🏫 All Classes (School-Wide)' : c.displayName,
                  onChanged: (v) {
                    setState(() => _selectedClass = v);
                    _loadAllAnalytics();
                  },
                ),
              ),
            ],

            // Date Preset Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _datePreset,
                  isDense: true,
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  items: [
                    const DropdownMenuItem(
                      value: 'week',
                      child: Text('Last 7 Days'),
                    ),
                    const DropdownMenuItem(
                      value: 'month',
                      child: Text('This Month'),
                    ),
                    const DropdownMenuItem(
                      value: '90days',
                      child: Text('Last 90 Days'),
                    ),
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('All Time (Session)'),
                    ),
                    DropdownMenuItem(
                      value: 'custom',
                      child: Text(
                        _customDateRange != null
                            ? '📅 ${_customDateRange!.start.month}/${_customDateRange!.start.day} - ${_customDateRange!.end.month}/${_customDateRange!.end.day}'
                            : '📅 Custom Range...',
                      ),
                    ),
                  ],
                  onChanged: (v) async {
                    if (v != null) {
                      if (v == 'custom') {
                        final now = DateTime.now();
                        final picked = await showDateRangePicker(
                          context: context,
                          initialDateRange: _customDateRange ??
                              DateTimeRange(
                                start: now.subtract(const Duration(days: 30)),
                                end: now,
                              ),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() {
                            _customDateRange = picked;
                            _datePreset = 'custom';
                          });
                          _loadAllAnalytics();
                        }
                      } else {
                        setState(() => _datePreset = v);
                        _loadAllAnalytics();
                      }
                    }
                  },
                ),
              ),
            ),

            // Defaulter Cutoff threshold input
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Defaulter Cutoff:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 75,
                  child: TextFormField(
                    initialValue: _threshold.toStringAsFixed(0),
                    decoration: InputDecoration(
                      suffixText: '%',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onFieldSubmitted: (v) {
                      final val = double.tryParse(v);
                      if (val != null && val > 0 && val <= 100) {
                        setState(() => _threshold = val);
                        _loadAllAnalytics();
                      }
                    },
                  ),
                ),
              ],
            ),

            IconButton.filledTonal(
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: 'Refresh Analytics',
              onPressed: _loadAllAnalytics,
            ),
          ],
        ),
      ),
    );
  }

  // ─── KPI Cards Row ──────────────────────────────────────────────────────────
  Widget _buildKpiRow(
    ThemeData theme, {
    required double overallPct,
    required int totalStudents,
    required int totalClasses,
    required int totalSessions,
    required int totalDefaulters,
    required int presentRecords,
    required int absentRecords,
    required int lateRecords,
    required int excusedRecords,
    required int totalRecords,
    required bool isDesktop,
  }) {
    final defaulterPct = totalStudents > 0
        ? ((totalDefaulters / totalStudents) * 100).toStringAsFixed(1)
        : '0.0';

    final cards = [
      _kpiCard(
        title: 'Overall Attendance',
        value: '${overallPct.toStringAsFixed(1)}%',
        subtitle: totalRecords > 0 ? '$presentRecords / $totalRecords Records' : 'No records yet',
        icon: Icons.trending_up_rounded,
        color: overallPct >= 85
            ? const Color(0xFF059669)
            : (overallPct >= 75
                ? const Color(0xFFD97706)
                : const Color(0xFFEF4444)),
      ),
      _kpiCard(
        title: _selectedClass == null ? 'Total Students' : 'Class Enrollment',
        value: '$totalStudents',
        subtitle: _selectedClass == null
            ? '$totalClasses Enrolled Classes'
            : _selectedClass!.displayName,
        icon: Icons.people_alt_outlined,
        color: const Color(0xFF2563EB),
      ),
      _kpiCard(
        title: 'Sessions Conducted',
        value: '$totalSessions',
        subtitle: 'In selected period',
        icon: Icons.event_available_rounded,
        color: const Color(0xFF7C3AED),
      ),
      _kpiCard(
        title: 'Defaulters (<${_threshold.toStringAsFixed(0)}%)',
        value: '$totalDefaulters',
        subtitle: '$defaulterPct% of students at risk',
        icon: Icons.warning_amber_rounded,
        color: totalDefaulters > 0
            ? const Color(0xFFDC2626)
            : const Color(0xFF059669),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isDesktop)
          Row(
            children: cards
                .map(
                  (c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: c,
                    ),
                  ),
                )
                .toList(),
          )
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: cards,
          ),

        // Status Distribution Breakdown Bar
        if (totalRecords > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
            ),
            child: Wrap(
              spacing: 20,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Record Breakdown:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                _statusPill('Present', presentRecords, const Color(0xFF059669)),
                _statusPill('Absent', absentRecords, const Color(0xFFDC2626)),
                if (lateRecords > 0)
                  _statusPill('Late', lateRecords, const Color(0xFFD97706)),
                if (excusedRecords > 0)
                  _statusPill('Excused', excusedRecords, const Color(0xFF2563EB)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _statusPill(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Weekly/Monthly Trend Line Chart ───────────────────────────────────────
  Widget _buildTrendLineChart(ThemeData theme) {
    final spots = <FlSpot>[];
    final xLabels = <String>[];
    final fullDates = <String>[];

    for (int i = 0; i < _trendData.length; i++) {
      final item = _trendData[i];
      if (item is Map) {
        final pctVal = item['attendance_pct'] ??
            item['attendance_percentage'] ??
            item['pct'] ??
            item['rate'] ??
            0.0;
        final pct = (pctVal as num).toDouble();

        final rawBucket =
            (item['bucket'] ?? item['date'] ?? item['label'] ?? '').toString();
        String label = 'W${i + 1}';
        String fullDate = rawBucket;

        if (rawBucket.isNotEmpty) {
          final dt = DateTime.tryParse(rawBucket);
          if (dt != null) {
            if (_datePreset == 'month' || _datePreset == 'week') {
              label = '${dt.month}/${dt.day}';
            } else {
              final months = [
                '',
                'Jan',
                'Feb',
                'Mar',
                'Apr',
                'May',
                'Jun',
                'Jul',
                'Aug',
                'Sep',
                'Oct',
                'Nov',
                'Dec'
              ];
              label = months[dt.month];
            }
            fullDate = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          }
        }

        spots.add(FlSpot(i.toDouble(), pct.clamp(0, 100)));
        xLabels.add(label);
        fullDates.add(fullDate);
      }
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.show_chart_rounded,
                      color: theme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Attendance Trend Over Time',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (spots.isNotEmpty)
                  Text(
                    '${spots.length} data points',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: spots.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timeline, color: Colors.grey.shade400, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            'No trend data recorded for this time range',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: 100,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (val) => FlLine(
                            color: theme.dividerColor.withValues(alpha: 0.6),
                            strokeWidth: 1,
                          ),
                        ),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final idx = spot.x.toInt();
                                final dateStr = idx >= 0 && idx < fullDates.length
                                    ? fullDates[idx]
                                    : '';
                                return LineTooltipItem(
                                  '$dateStr\n${spot.y.toStringAsFixed(1)}%',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              interval: 25,
                              getTitlesWidget: (v, meta) => Text(
                                '${v.toInt()}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 26,
                              getTitlesWidget: (v, meta) {
                                final idx = v.toInt();
                                if (idx >= 0 && idx < xLabels.length) {
                                  // Show all labels if <= 8 spots, otherwise skip every other label
                                  if (xLabels.length > 8 && idx % 2 != 0) {
                                    return const SizedBox();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      xLabels[idx],
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            curveSmoothness: 0.25,
                            color: theme.primaryColor,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: spots.length <= 15,
                              getDotPainter: (spot, percent, barData, index) =>
                                  FlDotCirclePainter(
                                radius: 4,
                                color: theme.primaryColor,
                                strokeWidth: 1.5,
                                strokeColor: Colors.white,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: theme.primaryColor.withValues(alpha: 0.12),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Class Comparison Bar Chart ─────────────────────────────────────────────
  Widget _buildClassComparisonBarChart(
    ThemeData theme,
    List<dynamic> classComparisons,
  ) {
    final barGroups = <BarChartGroupData>[];
    final shortLabels = <String>[];
    final fullLabels = <String>[];

    final displayList = List<dynamic>.from(classComparisons);
    for (int i = 0; i < displayList.length; i++) {
      final c = displayList[i];
      if (c is Map) {
        final fullName = (c['class_name'] ?? 'Class ${i + 1}').toString();
        final pctVal = c['attendance_percentage'] ?? c['attendance_pct'] ?? c['pct'] ?? 0.0;
        final pct = (pctVal as num).toDouble();

        // Build clean readable short label: e.g. "Grade 1 - A" -> "1-A"
        String shortName = fullName.replaceAll('Grade ', '').replaceAll(' ', '');
        if (shortName.isEmpty) shortName = 'C${i + 1}';

        shortLabels.add(shortName);
        fullLabels.add(fullName);

        final color = pct >= 85
            ? const Color(0xFF059669)
            : (pct >= 75 ? const Color(0xFFD97706) : const Color(0xFFEF4444));

        barGroups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: pct.clamp(0, 100),
                color: color,
                width: displayList.length <= 4 ? 24 : 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          ),
        );
      }
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bar_chart_rounded,
                      color: theme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Class Comparison',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${barGroups.length} Classes',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: barGroups.isEmpty
                  ? Center(
                      child: Text(
                        'No class comparison data available',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        minY: 0,
                        maxY: 100,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (val) => FlLine(
                            color: theme.dividerColor.withValues(alpha: 0.6),
                            strokeWidth: 1,
                          ),
                        ),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final name = groupIndex < fullLabels.length
                                  ? fullLabels[groupIndex]
                                  : 'Class';
                              return BarTooltipItem(
                                '$name\n${rod.toY.toStringAsFixed(1)}%',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              interval: 25,
                              getTitlesWidget: (v, meta) => Text(
                                '${v.toInt()}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 26,
                              getTitlesWidget: (v, meta) {
                                final idx = v.toInt();
                                if (idx >= 0 && idx < shortLabels.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      shortLabels[idx],
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        barGroups: barGroups,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Single Class Health Breakdown Card ─────────────────────────────────────
  Widget _buildClassBreakdownCard(
    ThemeData theme, {
    required double overallPct,
    required int present,
    required int absent,
    required int late,
    required int excused,
    required int total,
    required int totalStudents,
    required int defaulters,
  }) {
    final pPct = total > 0 ? (present / total * 100).toStringAsFixed(1) : '0.0';
    final aPct = total > 0 ? (absent / total * 100).toStringAsFixed(1) : '0.0';
    final lPct = total > 0 ? (late / total * 100).toStringAsFixed(1) : '0.0';
    final ePct = total > 0 ? (excused / total * 100).toStringAsFixed(1) : '0.0';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pie_chart_outline_rounded,
                  color: theme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_selectedClass?.displayName ?? "Class"} Overview',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Class Performance Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    if (present > 0)
                      Expanded(
                        flex: present,
                        child: Container(color: const Color(0xFF059669)),
                      ),
                    if (absent > 0)
                      Expanded(
                        flex: absent,
                        child: Container(color: const Color(0xFFDC2626)),
                      ),
                    if (late > 0)
                      Expanded(
                        flex: late,
                        child: Container(color: const Color(0xFFD97706)),
                      ),
                    if (excused > 0)
                      Expanded(
                        flex: excused,
                        child: Container(color: const Color(0xFF2563EB)),
                      ),
                    if (total == 0)
                      Expanded(
                        child: Container(color: Colors.grey.shade300),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            _metricRow('Present Attendance', '$present ($pPct%)', const Color(0xFF059669)),
            const Divider(height: 14),
            _metricRow('Unexcused Absent', '$absent ($aPct%)', const Color(0xFFDC2626)),
            const Divider(height: 14),
            _metricRow('Late Arrivals', '$late ($lPct%)', const Color(0xFFD97706)),
            const Divider(height: 14),
            _metricRow('Excused Absences', '$excused ($ePct%)', const Color(0xFF2563EB)),
          ],
        ),
      ),
    );
  }

  Widget _metricRow(String title, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // ─── Defaulters Section ───────────────────────────────────────────────────
  Widget _buildDefaultersSection(ThemeData theme, {required int totalStudents}) {
    // Filter defaulters according to search query
    final query = _defaulterSearchQuery.trim().toLowerCase();
    final filtered = _defaultersData.where((d) {
      if (query.isEmpty) return true;
      final name = (d['student_name'] ?? d['full_name'] ?? d['name'] ?? '').toString().toLowerCase();
      final roll = (d['roll_number'] ?? '').toString().toLowerCase();
      final cls = (d['class_name'] ?? '').toString().toLowerCase();
      final adm = (d['admission_number'] ?? '').toString().toLowerCase();
      return name.contains(query) || roll.contains(query) || cls.contains(query) || adm.contains(query);
    }).toList();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Defaulters (<${_threshold.toStringAsFixed(0)}%)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Chip(
                  label: Text(
                    '${_defaultersData.length} Students',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Search Bar for Defaulters
            if (_defaultersData.length > 3) ...[
              SizedBox(
                height: 38,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search student by name, roll, class...',
                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (v) => setState(() => _defaulterSearchQuery = v),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (_defaultersData.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.green, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        'Great! No defaulters found below ${_threshold.toStringAsFixed(0)}% cutoff.',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              )
            else if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('No students match your search filter.'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final d = filtered[i];
                  final name = (d['student_name'] ?? d['full_name'] ?? d['name'] ?? 'Student').toString();
                  final roll = (d['roll_number'] ?? '-').toString();
                  final clsName = (d['class_name'] ?? '-').toString();
                  final guardian = (d['guardian_name'] ?? '').toString();
                  final phone = (d['guardian_phone'] ?? '').toString();

                  final present = (d['present_count'] ?? d['present'] ?? 0) as num;
                  final total = (d['total_sessions'] ?? d['total'] ?? 0) as num;

                  // Guaranteed calculation fallback to prevent any 0.0% bugs
                  double pct;
                  if (d['attendance_pct'] != null) {
                    pct = (d['attendance_pct'] as num).toDouble();
                  } else if (d['attendance_percentage'] != null) {
                    pct = (d['attendance_percentage'] as num).toDouble();
                  } else if (d['pct'] != null) {
                    pct = (d['pct'] as num).toDouble();
                  } else if (total > 0) {
                    pct = (present / total) * 100.0;
                  } else {
                    pct = 0.0;
                  }

                  final isCritical = pct < 50;

                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    onTap: () {
                      final stId = (d['student_id'] ?? d['id'] ?? '').toString();
                      final student = Student(
                        id: stId,
                        fullName: name,
                        rollNumber: roll,
                        classId: (d['class_id'] ?? '').toString(),
                        admissionNumber: (d['admission_number'] ?? d['admission_no'] ?? '-').toString(),
                      );
                      final totP = present.toInt();
                      final totS = total.toInt();
                      final totA = totS > totP ? totS - totP : 0;
                      StudentProfileScreen.show(
                        context,
                        student: student,
                        className: clsName,
                        attendancePct: pct,
                        totalPresent: totP,
                        totalAbsent: totA,
                        totalLate: 0,
                        totalExcused: 0,
                      );
                    },
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: isCritical
                          ? Colors.red.shade100
                          : Colors.amber.shade100,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'S',
                        style: TextStyle(
                          color: isCritical ? Colors.red.shade800 : Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          'Class: $clsName • Roll: $roll • $present/$total Sessions',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                        if (phone.isNotEmpty || guardian.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.phone_outlined, size: 12, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                '${guardian.isNotEmpty ? "$guardian: " : ""}$phone',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                              if (phone.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: phone));
                                    widget.snack('Copied $phone to clipboard');
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(Icons.copy_outlined, size: 12, color: Colors.blue),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isCritical
                            ? Colors.red.withValues(alpha: 0.12)
                            : Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCritical
                              ? Colors.red.withValues(alpha: 0.4)
                              : Colors.amber.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: isCritical ? Colors.red.shade800 : Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

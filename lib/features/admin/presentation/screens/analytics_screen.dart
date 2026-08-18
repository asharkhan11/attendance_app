import 'package:attendance_app/features/teacher/presentation/screens/student_profile_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
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

      final ovRes = await widget.api.getSchoolOverview(
        academicYearId: ayId,
        classId: _selectedClass?.id,
        from: from,
        to: to,
        threshold: _threshold,
      );
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
                  summaryMap['overall_attendance_pct'] ??
                  _overviewData?['overall_attendance_pct'],
              'total_students':
                  summaryMap['total_students'] ??
                  _overviewData?['total_students'],
              'total_sessions':
                  summaryMap['total_sessions'] ??
                  _overviewData?['total_sessions'],
              'total_defaulters':
                  summaryMap['defaulters_count'] ??
                  summaryMap['total_defaulters'] ??
                  _overviewData?['total_defaulters'],
            };
          }
        } catch (_) {}
      }

      final defRes = await widget.api.getSchoolDefaulters(
        classId: _selectedClass?.id,
        from: from,
        to: to,
        threshold: _threshold,
      );
      if (defRes is Map && defRes['data'] is List) {
        _defaultersData = defRes['data'] as List;
      } else if (defRes is List) {
        _defaultersData = defRes;
      } else {
        _defaultersData = [];
      }

      final trRes = _selectedClass == null
          ? await widget.api.getSchoolTrend(
              from: from,
              to: to,
              granularity: 'week',
            )
          : await widget.api.getClassTrend(
              _selectedClass!.id,
              from: from,
              to: to,
              granularity: 'week',
            );

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

    double overallPct =
        (findNum([
                  'overall_attendance_pct',
                  'attendance_percentage',
                  'overall_attendance_percentage',
                  'attendance_rate',
                  'average_attendance',
                ]) ??
                0.0)
            .toDouble();

    int totalStudents =
        (findNum([
                  'total_students',
                  'enrolled_students',
                  'student_count',
                  'students_count',
                ]) ??
                0)
            .toInt();

    int totalSessions =
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

    final rawComparisons = (_overviewData?['class_comparisons'] as List?) ?? [];
    final classComparisons = _selectedClass == null
        ? rawComparisons
        : rawComparisons.where((c) {
            final cId = c['class_id']?.toString();
            final cName = c['class_name']?.toString() ?? '';
            return (cId != null && cId == _selectedClass!.id) ||
                cName.contains(_selectedClass!.displayName);
          }).toList();

    if (totalDefaulters == 0 && _defaultersData.isNotEmpty) {
      totalDefaulters = _defaultersData.length;
    }

    return RefreshIndicator(
      onRefresh: _loadAllAnalytics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Filter Controls Card ──────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 12,
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
                        width: 220,
                        child: SearchableDropdown<SchoolClass?>(
                          value: _selectedClass,
                          labelText: 'Class Scope',
                          isDense: true,
                          items: [null, ...widget.classes],
                          itemAsString: (c) => c == null
                              ? '🏫 All Classes (School-Wide)'
                              : c.displayName,
                          onChanged: (v) {
                            setState(() => _selectedClass = v);
                            _loadAllAnalytics();
                          },
                        ),
                      ),
                    ],

                    DropdownButton<String>(
                      value: _datePreset,
                      isDense: true,
                      underline: const SizedBox(),
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
                          child: Text('All Time'),
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
                              initialDateRange:
                                  _customDateRange ??
                                  DateTimeRange(
                                    start: now.subtract(
                                      const Duration(days: 30),
                                    ),
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

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Defaulter Cutoff:',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 70,
                          child: TextFormField(
                            initialValue: _threshold.toStringAsFixed(0),
                            decoration: const InputDecoration(
                              suffixText: '%',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            onFieldSubmitted: (v) {
                              _threshold = double.tryParse(v) ?? 75;
                              _loadAllAnalytics();
                            },
                          ),
                        ),
                      ],
                    ),

                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh Data',
                      onPressed: _loadAllAnalytics,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              // ─── KPI Cards Row ───────────────────────────────────────────
              _buildKpiRow(
                theme,
                overallPct,
                totalStudents,
                totalSessions,
                totalDefaulters,
                isDesktop,
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
                      child: _buildClassComparisonBarChart(
                        theme,
                        classComparisons,
                      ),
                    ),
                  ],
                )
              else ...[
                _buildTrendLineChart(theme),
                const SizedBox(height: 16),
                _buildClassComparisonBarChart(theme, classComparisons),
              ],

              const SizedBox(height: 24),

              // ─── Defaulters List Table ───────────────────────────────────
              _buildDefaultersSection(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKpiRow(
    ThemeData theme,
    double overallPct,
    int totalStudents,
    int totalSessions,
    int totalDefaulters,
    bool isDesktop,
  ) {
    final cards = [
      _kpiCard(
        'Overall Attendance',
        '${overallPct.toStringAsFixed(1)}%',
        Icons.trending_up,
        overallPct >= 85
            ? const Color(0xFF059669)
            : (overallPct >= 75
                  ? const Color(0xFFD97706)
                  : const Color(0xFFEF4444)),
      ),
      _kpiCard(
        'Total Students',
        '$totalStudents',
        Icons.people_outline,
        const Color(0xFF3B82F6),
      ),
      _kpiCard(
        'Sessions Conducted',
        '$totalSessions',
        Icons.event_available,
        const Color(0xFF8B5CF6),
      ),
      _kpiCard(
        'Defaulters (<${_threshold.toStringAsFixed(0)}%)',
        '$totalDefaulters',
        Icons.warning_amber_rounded,
        totalDefaulters > 0 ? const Color(0xFFEF4444) : const Color(0xFF059669),
      ),
    ];

    if (isDesktop) {
      return Row(
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
      );
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: cards,
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      color: Colors.grey.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color, size: 16),
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
          ],
        ),
      ),
    );
  }

  // ─── Weekly Trend Line Chart (fl_chart) ────────────────────────────────────
  Widget _buildTrendLineChart(ThemeData theme) {
    final spots = <FlSpot>[];
    final xLabels = <String>[];

    for (int i = 0; i < _trendData.length; i++) {
      final item = _trendData[i];
      if (item is Map) {
        final pct =
            (item['attendance_percentage'] ??
                    item['pct'] ??
                    item['rate'] ??
                    0.0)
                as num;
        final label =
            item['week'] ?? item['date'] ?? item['label'] ?? 'W${i + 1}';
        spots.add(FlSpot(i.toDouble(), pct.toDouble().clamp(0, 100)));
        xLabels.add(label.toString());
      }
    }

    // Fallback spots if trend data is empty
    if (spots.isEmpty) {
      spots.addAll(const [
        FlSpot(0, 80),
        FlSpot(1, 85),
        FlSpot(2, 78),
        FlSpot(3, 90),
      ]);
      xLabels.addAll(['W1', 'W2', 'W3', 'W4']);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (val) =>
                        FlLine(color: theme.dividerColor, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (v, meta) => Text(
                          '${v.toInt()}%',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, meta) {
                          final idx = v.toInt();
                          if (idx >= 0 && idx < xLabels.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                xLabels[idx],
                                style: const TextStyle(fontSize: 10),
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
                      color: theme.primaryColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.primaryColor.withValues(alpha: 0.15),
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

  // ─── Class Comparison Bar Chart (fl_chart) ─────────────────────────────────
  Widget _buildClassComparisonBarChart(
    ThemeData theme,
    List<dynamic> classComparisons,
  ) {
    final barGroups = <BarChartGroupData>[];
    final labels = <String>[];

    final displayList = classComparisons.take(8).toList();
    for (int i = 0; i < displayList.length; i++) {
      final c = displayList[i];
      if (c is Map) {
        final name = c['class_name']?.toString() ?? 'Class ${i + 1}';
        final pct =
            ((c['attendance_percentage'] ?? c['attendance_pct'] ?? 0.0) as num)
                .toDouble();
        labels.add(name);

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
                width: 18,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
          ),
        );
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: barGroups.isEmpty
                  ? const Center(
                      child: Text('No class comparison data available'),
                    )
                  : BarChart(
                      BarChartData(
                        minY: 0,
                        maxY: 100,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              getTitlesWidget: (v, meta) => Text(
                                '${v.toInt()}%',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, meta) {
                                final idx = v.toInt();
                                if (idx >= 0 && idx < labels.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      labels[idx].length > 6
                                          ? labels[idx].substring(0, 6)
                                          : labels[idx],
                                      style: const TextStyle(fontSize: 10),
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

  // ─── Defaulters Section ───────────────────────────────────────────────────
  Widget _buildDefaultersSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                      size: 20,
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
                    ),
                  ),
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  side: const BorderSide(color: Colors.redAccent),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_defaultersData.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    '🎉 No defaulters found below the selected cutoff threshold!',
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _defaultersData.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final d = _defaultersData[i];
                  final name =
                      d['student_name'] ??
                      d['full_name'] ??
                      d['name'] ??
                      'Student';
                  final roll = d['roll_number']?.toString() ?? '-';
                  final clsName = d['class_name']?.toString() ?? '-';
                  final pct =
                      ((d['attendance_percentage'] ?? d['pct'] ?? 0.0) as num)
                          .toDouble();
                  final present =
                      (d['present_count'] ?? d['present'] ?? 0) as num;
                  final total = (d['total_sessions'] ?? d['total'] ?? 0) as num;

                  return ListTile(
                    dense: true,
                    onTap: () {
                      final stId = (d['student_id'] ?? d['id'] ?? '')
                          .toString();
                      final student = Student(
                        id: stId,
                        fullName: name,
                        rollNumber: roll,
                        classId: (d['class_id'] ?? '').toString(),
                        admissionNumber:
                            (d['admission_number'] ?? d['admission_no'] ?? '-')
                                .toString(),
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
                      radius: 14,
                      backgroundColor: Colors.red.shade100,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'S',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
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
                    subtitle: Text(
                      'Class: $clsName • Roll: $roll • $present/$total Sessions',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
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

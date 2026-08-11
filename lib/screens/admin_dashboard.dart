import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/auth_provider.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../services/download_helper.dart';
import '../widgets/searchable_dropdown.dart';
import '../widgets/profile_modal.dart';

import '../design_system/app_breakpoints.dart';
import '../design_system/app_spacing.dart';
import '../features/admin/presentation/widgets/admin_navigation.dart';
import '../features/admin/presentation/widgets/analytics_filter_sheet.dart';
import '../features/admin/presentation/screens/admin_overview_screen.dart';
import '../features/admin/presentation/screens/analytics_screen.dart';

// ─── Admin Dashboard ────────────────────────────────────────────────────────────

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final ApiService _api = ApiService();
  int _selectedIndex = 0;
  bool _isLoading = true;

  // Shared data
  List<AcademicYear> _years = [];
  AcademicYear? _selectedYear;
  List<SchoolClass> _classes = [];
  List<User> _teachers = [];

  @override
  void initState() {
    super.initState();
    _loadSharedData();
  }

  Future<void> _loadSharedData() async {
    setState(() => _isLoading = true);
    try {
      final ayRes = await _api.listAcademicYears();
      List rawYears = [];
      if (ayRes is List) {
        rawYears = ayRes;
      } else if (ayRes is Map && ayRes['data'] is List) {
        rawYears = ayRes['data'] as List;
      }
      _years = rawYears.map((x) => AcademicYear.fromJson(x)).toList();

      if (_years.isNotEmpty) {
        if (_selectedYear == null) {
          _selectedYear = _years.firstWhere(
            (y) => y.isCurrent,
            orElse: () => _years.first,
          );
        } else {
          final match = _years.where((y) => y.id == _selectedYear!.id);
          if (match.isNotEmpty) {
            _selectedYear = match.first;
          } else {
            _selectedYear = _years.firstWhere(
              (y) => y.isCurrent,
              orElse: () => _years.first,
            );
          }
        }
      } else {
        _selectedYear = null;
      }

      if (_selectedYear != null) {
        final cp = await _api.listClasses(
          academicYearId: _selectedYear!.id,
          pageSize: 100,
        );
        _classes = cp.data.map((x) => SchoolClass.fromJson(x)).toList();
      } else {
        _classes = [];
      }

      final tp = await _api.listTeachers(pageSize: 100);
      _teachers = tp.data.map((x) => User.fromJson(x)).toList();
    } catch (e) {
      _snack('Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    // Tab index mapping — Overview = 0 (NEW), all originals shifted +1
    final tabs = [
      // 0: Overview (NEW)
      AdminOverviewScreen(
        api: _api,
        selectedYear: _selectedYear,
        classes: _classes,
        snack: _snack,
        navigateTo: (i) => setState(() => _selectedIndex = i),
      ),
      // 1: Sessions (was 0)
      _AcademicSessionsTab(
        api: _api,
        years: _years,
        selectedYear: _selectedYear,
        classes: _classes,
        teachers: _teachers,
        onRefresh: _loadSharedData,
        snack: _snack,
      ),
      // 2: Analytics (was 1)
      AnalyticsScreen(
        api: _api,
        classes: _classes,
        selectedYear: _selectedYear,
        snack: _snack,
      ),
      // 3: Classes (was 2)
      _ClassesTab(
        api: _api,
        classes: _classes,
        teachers: _teachers,
        selectedYear: _selectedYear,
        onRefresh: _loadSharedData,
        snack: _snack,
      ),
      // 4: Students (was 3)
      _StudentsTab(
        api: _api,
        classes: _classes,
        selectedYear: _selectedYear,
        snack: _snack,
      ),
      // 5: Teachers (was 4)
      _TeachersTab(
        api: _api,
        teachers: _teachers,
        selectedYear: _selectedYear,
        onRefresh: _loadSharedData,
        snack: _snack,
      ),
      // 6: Reports (was 5)
      _ReportsTab(
        api: _api,
        classes: _classes,
        selectedYear: _selectedYear,
        snack: _snack,
      ),
      // 7: School Days (was 6)
      _SchoolDaysTab(api: _api, selectedYear: _selectedYear, snack: _snack),
    ];

    Widget content = Scaffold(
      appBar: AppBar(
        title: Text(
          isMobile ? 'Admin Portal' : 'Admin Dashboard & Management Portal',
        ),
        actions: [
          if (!isMobile && _years.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 4.0,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<AcademicYear>(
                    value: _selectedYear,
                    isDense: true,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    items: _years.map((y) {
                      return DropdownMenuItem<AcademicYear>(
                        value: y,
                        child: Text(
                          '${y.name}${y.isCurrent ? ' (Active)' : ''}${y.isArchived ? ' 🔒' : ''}',
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedYear = v);
                        _loadSharedData();
                      }
                    },
                  ),
                ),
              ),
            ),
          if (_selectedYear != null &&
              (!_selectedYear!.isCurrent || _selectedYear!.isArchived))
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.amber.shade700, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: Colors.amber.shade800,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _selectedYear!.isArchived
                          ? 'Archived (Read-Only)'
                          : 'Past Session (Read-Only)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'My Profile & Security',
            onPressed: () =>
                ProfileModal.show(context, onProfileUpdated: _loadSharedData),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadSharedData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () =>
                Provider.of<AuthProvider>(context, listen: false).logout(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Mobile Academic Year Banner Selector
                if (isMobile && _years.isNotEmpty)
                  Container(
                    width: double.infinity,
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.05),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Academic Year:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<AcademicYear>(
                            value: _selectedYear,
                            isDense: true,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                            items: _years.map((y) {
                              return DropdownMenuItem<AcademicYear>(
                                value: y,
                                child: Text(
                                  '${y.name}${y.isCurrent ? ' (Active)' : ''}',
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _selectedYear = v);
                                _loadSharedData();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(child: tabs[_selectedIndex]),
              ],
            ),
    );

    final auth = Provider.of<AuthProvider>(context, listen: false);
    return AdminNavigation(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      body: content,
      userFullName: auth.currentUser?.fullName,
      onRefreshTap: _loadSharedData,
      onProfileTap: () =>
          ProfileModal.show(context, onProfileUpdated: _loadSharedData),
      onLogoutTap: () =>
          Provider.of<AuthProvider>(context, listen: false).logout(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1: Analytics
// ═══════════════════════════════════════════════════════════════════════════════

class _AnalyticsTab extends StatefulWidget {
  final ApiService api;
  final List<SchoolClass> classes;
  final AcademicYear? selectedYear;
  final void Function(String, {bool error}) snack;
  const _AnalyticsTab({
    required this.api,
    required this.classes,
    required this.selectedYear,
    required this.snack,
  });

  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  SchoolClass? _selectedClass; // null = All Classes (School-Wide)
  String _datePreset = 'month'; // 'week', 'month', '90days', 'all'
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
  void didUpdateWidget(covariant _AnalyticsTab oldWidget) {
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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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

    final barComparisons = classComparisons.isNotEmpty
        ? classComparisons
        : (_selectedClass != null
              ? [
                  {
                    'class_name': _selectedClass!.displayName,
                    'attendance_percentage': overallPct,
                  },
                ]
              : []);

    if (rawComparisons.isNotEmpty && _selectedClass == null) {
      if (overallPct == 0.0) {
        final pcts = rawComparisons
            .map((c) => (c['attendance_percentage'] as num?)?.toDouble() ?? 0.0)
            .where((p) => p > 0)
            .toList();
        if (pcts.isNotEmpty) {
          overallPct = pcts.reduce((a, b) => a + b) / pcts.length;
        }
      }
      if (totalStudents == 0) {
        totalStudents = rawComparisons.fold<int>(
          0,
          (sum, c) => sum + ((c['total_students'] as num?)?.toInt() ?? 0),
        );
      }
    }

    if (totalDefaulters == 0 && _defaultersData.isNotEmpty) {
      totalDefaulters = _defaultersData.length;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Controls
          Card(
            margin: EdgeInsets.zero,
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
                            initialEntryMode: DatePickerEntryMode.inputOnly,
                            initialDateRange:
                                _customDateRange ??
                                DateTimeRange(
                                  start: now.subtract(const Duration(days: 30)),
                                  end: now,
                                ),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: Theme.of(context).primaryColor,
                                  ),
                                ),
                                child: child!,
                              );
                            },
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
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            _threshold = double.tryParse(v) ?? 75;
                          },
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
        ],
      ),
    );
  }

  Widget _kpiCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isWide,
  ) {
    return SizedBox(
      width: isWide ? 220 : 160,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(icon, color: color, size: 20),
                ],
              ),
              const SizedBox(height: 8),
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
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2: Classes — List, Create, Delete, Assign Teacher
// ═══════════════════════════════════════════════════════════════════════════════

class _ClassesTab extends StatefulWidget {
  final ApiService api;
  final List<SchoolClass> classes;
  final List<User> teachers;
  final AcademicYear? selectedYear;
  final VoidCallback onRefresh;
  final void Function(String, {bool error}) snack;
  const _ClassesTab({
    required this.api,
    required this.classes,
    required this.teachers,
    required this.selectedYear,
    required this.onRefresh,
    required this.snack,
  });

  @override
  State<_ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends State<_ClassesTab> {
  final _searchCtrl = TextEditingController();
  int _page = 1;
  static const int _pageSize = 20;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showCreateClassDialog() {
    final gradeCtrl = TextEditingController();
    final sectionCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Class'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: gradeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Grade Level (e.g. 10)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sectionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Section (e.g. A)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              try {
                await widget.api.createClass({
                  'grade_level': int.tryParse(gradeCtrl.text.trim()) ?? 0,
                  'section': sectionCtrl.text.trim(),
                });
                nav.pop();
                widget.snack('Class created successfully', error: false);
                widget.onRefresh();
              } catch (e) {
                widget.snack('Failed to create class: $e');
              }
            },
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteClass(SchoolClass c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text(
          'Are you sure you want to delete ${c.displayName}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              try {
                await widget.api.deleteClass(c.id);
                nav.pop();
                widget.snack('Class deleted', error: false);
                widget.onRefresh();
              } catch (e) {
                widget.snack('Failed to delete class: $e');
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAssignTeacherDialog(SchoolClass sc) {
    User? selected;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Assign Teacher to ${sc.displayName}'),
        content: StatefulBuilder(
          builder: (_, setD) => SearchableDropdown<User>(
            value: selected,
            hintText: 'Choose Teacher',
            items: widget.teachers,
            itemAsString: (t) => '${t.fullName} (${t.email})',
            onChanged: (v) => setD(() => selected = v),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selected == null) return;
              final nav = Navigator.of(ctx);
              try {
                await widget.api.assignClassTeacher(sc.id, selected!.id);
                nav.pop();
                widget.snack('Teacher assigned', error: false);
                widget.onRefresh();
              } catch (e) {
                widget.snack('Failed to assign teacher: $e');
              }
            },
            child: const Text('ASSIGN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedYear == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 64,
                color: Colors.orange.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No Academic Session Selected',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please create or select an Academic Session in the "Sessions" tab to view and manage classes.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    final isArchived = widget.selectedYear?.isArchived == true;

    final query = _searchCtrl.text.trim().toLowerCase();
    final filteredClasses = widget.classes.where((c) {
      if (query.isEmpty) return true;
      final assignedTeacher = widget.teachers
          .where((t) => t.id == c.classTeacherId)
          .firstOrNull;
      final teacherName = c.classTeacherName ?? assignedTeacher?.fullName ?? '';
      final teacherPhone = assignedTeacher?.phone ?? '';
      final searchTarget =
          'grade ${c.gradeLevel} section ${c.section} ${c.displayName} $teacherName $teacherPhone'
              .toLowerCase();
      return searchTarget.contains(query);
    }).toList();

    final totalPages = (filteredClasses.length / _pageSize).ceil().clamp(
      1,
      999999,
    );
    final currentPage = _page.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _pageSize;
    final pageClasses = filteredClasses
        .skip(startIndex)
        .take(_pageSize)
        .toList();

    return Scaffold(
      body: Column(
        children: [
          if (isArchived)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: Colors.orange.shade800,
              child: Row(
                children: const [
                  Icon(Icons.lock, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'This Academic Session is Archived (Read-Only Mode). Modifications are locked.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      labelText: 'Search Classes',
                      hintText: 'Grade, section, teacher, phone...',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchCtrl.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _page = 1);
                              },
                            ),
                          const Icon(Icons.search, size: 20),
                        ],
                      ),
                    ),
                    onChanged: (_) => setState(() => _page = 1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredClasses.isEmpty
                ? const Center(child: Text('No classes found.'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: pageClasses.length,
                    itemBuilder: (_, i) {
                      final c = pageClasses[i];
                      final assignedTeacher = widget.teachers
                          .where((t) => t.id == c.classTeacherId)
                          .firstOrNull;
                      final teacherName =
                          c.classTeacherName ??
                          assignedTeacher?.fullName ??
                          'Unassigned';
                      final teacherPhone = assignedTeacher?.phone;
                      final teacherSubtitle =
                          (teacherPhone != null && teacherPhone.isNotEmpty)
                          ? 'Teacher: $teacherName • Phone: $teacherPhone'
                          : 'Teacher: $teacherName';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${c.gradeLevel}')),
                          title: Text(
                            'Grade ${c.gradeLevel} - Section ${c.section}',
                          ),
                          subtitle: Text(teacherSubtitle),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.person_add, size: 20),
                                tooltip: 'Assign Teacher',
                                onPressed: isArchived
                                    ? null
                                    : () => _showAssignTeacherDialog(c),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                tooltip: 'Delete Class',
                                onPressed: isArchived
                                    ? null
                                    : () => _confirmDeleteClass(c),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous 20',
                    onPressed: currentPage > 1
                        ? () => setState(() => _page = currentPage - 1)
                        : null,
                  ),
                  Text(
                    'Page $currentPage of $totalPages (${filteredClasses.length} classes)',
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next 20',
                    onPressed: currentPage < totalPages
                        ? () => setState(() => _page = currentPage + 1)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: isArchived
          ? null
          : FloatingActionButton(
              onPressed: _showCreateClassDialog,
              tooltip: 'Create Class',
              child: const Icon(Icons.add),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 3: Teachers — List, Create, Edit, Deactivate, Reset Password
// ═══════════════════════════════════════════════════════════════════════════════

class _TeachersTab extends StatefulWidget {
  final ApiService api;
  final List<User> teachers;
  final AcademicYear? selectedYear;
  final VoidCallback onRefresh;
  final void Function(String, {bool error}) snack;
  const _TeachersTab({
    required this.api,
    required this.teachers,
    required this.selectedYear,
    required this.onRefresh,
    required this.snack,
  });

  @override
  State<_TeachersTab> createState() => _TeachersTabState();
}

class _TeachersTabState extends State<_TeachersTab> {
  final _searchCtrl = TextEditingController();
  int _page = 1;
  static const int _pageSize = 20;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _bulkImportTeachers() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) {
        widget.snack('Could not read file bytes');
        return;
      }
      await widget.api.bulkImportTeachers(file.bytes!, file.name);
      widget.snack('Teacher bulk import successful', error: false);
      widget.onRefresh();
    } catch (e) {
      widget.snack('Teacher bulk import failed: $e');
    }
  }

  void _showCreateTeacherDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Teacher'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              try {
                await widget.api.createTeacher({
                  'full_name': nameCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'password': passCtrl.text,
                });
                nav.pop();
                widget.snack('Teacher created', error: false);
                widget.onRefresh();
              } catch (e) {
                widget.snack('Failed to create teacher: $e');
              }
            },
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
  }

  void _showEditTeacherDialog(User t) {
    final nameCtrl = TextEditingController(text: t.fullName);
    final phoneCtrl = TextEditingController(text: t.phone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${t.fullName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              try {
                await widget.api.updateTeacher(t.id, {
                  'full_name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                });
                nav.pop();
                widget.snack('Teacher updated', error: false);
                widget.onRefresh();
              } catch (e) {
                widget.snack('Failed to update teacher: $e');
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _confirmDeactivate(User t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Teacher'),
        content: Text(
          'Deactivate ${t.fullName}? They will no longer be able to log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              try {
                await widget.api.deactivateTeacher(t.id);
                nav.pop();
                widget.snack('Teacher deactivated', error: false);
                widget.onRefresh();
              } catch (e) {
                widget.snack('Failed to deactivate: $e');
              }
            },
            child: const Text(
              'DEACTIVATE',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmActivate(User t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reactivate Teacher'),
        content: Text(
          'Reactivate ${t.fullName}? They will be able to log in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              try {
                await widget.api.activateTeacher(t.id);
                nav.pop();
                widget.snack('Teacher reactivated', error: false);
                widget.onRefresh();
              } catch (e) {
                widget.snack('Failed to reactivate: $e');
              }
            },
            child: const Text(
              'REACTIVATE',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTeacher(User t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Teacher'),
        content: Text(
          'Are you sure you want to delete ${t.fullName}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              try {
                await widget.api.deleteTeacher(t.id);
                nav.pop();
                widget.snack('Teacher deleted', error: false);
                widget.onRefresh();
              } catch (e) {
                widget.snack('Failed to delete teacher: $e');
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(User t) {
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset Password — ${t.fullName}'),
        content: TextField(
          controller: passCtrl,
          decoration: const InputDecoration(
            labelText: 'New Password',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              try {
                await widget.api.resetTeacherPassword(t.id, passCtrl.text);
                nav.pop();
                widget.snack('Password reset successfully', error: false);
              } catch (e) {
                widget.snack('Failed to reset password: $e');
              }
            },
            child: const Text('RESET'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArchived = widget.selectedYear?.isArchived == true;

    final query = _searchCtrl.text.trim().toLowerCase();
    final filteredTeachers = widget.teachers.where((t) {
      if (query.isEmpty) return true;
      final searchTarget = '${t.fullName} ${t.email} ${t.phone ?? ''}'
          .toLowerCase();
      return searchTarget.contains(query);
    }).toList();

    final totalPages = (filteredTeachers.length / _pageSize).ceil().clamp(
      1,
      999999,
    );
    final currentPage = _page.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _pageSize;
    final pageTeachers = filteredTeachers
        .skip(startIndex)
        .take(_pageSize)
        .toList();

    return Scaffold(
      body: Column(
        children: [
          if (isArchived)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: Colors.orange.shade800,
              child: Row(
                children: const [
                  Icon(Icons.lock, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'This Academic Session is Archived (Read-Only Mode). Modifications are locked.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 250,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      labelText: 'Search Teachers',
                      hintText: 'Name, email, phone...',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchCtrl.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _page = 1);
                              },
                            ),
                          const Icon(Icons.search, size: 20),
                        ],
                      ),
                    ),
                    onChanged: (_) => setState(() => _page = 1),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Download Teacher Template CSV'),
                      onPressed: () async {
                        try {
                          final file = await widget.api
                              .downloadTeacherTemplate();
                          triggerDownload(
                            file.bytes,
                            file.fileName ?? 'teachers_template.csv',
                            'text/csv',
                          );
                          widget.snack(
                            'Teacher template downloaded',
                            error: false,
                          );
                        } catch (e) {
                          widget.snack('Failed to download template: $e');
                        }
                      },
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: const Text('CSV Import'),
                      onPressed: isArchived ? null : _bulkImportTeachers,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredTeachers.isEmpty
                ? const Center(child: Text('No teachers found.'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: pageTeachers.length,
                    itemBuilder: (_, i) {
                      final t = pageTeachers[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: t.isActive
                                ? Colors.green[100]
                                : Colors.red[100],
                            child: Icon(
                              Icons.person,
                              color: t.isActive ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(t.fullName),
                          subtitle: Text(
                            '${t.email}${t.phone != null && t.phone!.isNotEmpty ? ' • Phone: ${t.phone}' : ''}',
                          ),
                          trailing: isArchived
                              ? null
                              : PopupMenuButton<String>(
                                  onSelected: (action) {
                                    switch (action) {
                                      case 'edit':
                                        _showEditTeacherDialog(t);
                                      case 'deactivate':
                                        _confirmDeactivate(t);
                                      case 'activate':
                                        _confirmActivate(t);
                                      case 'reset_password':
                                        _showResetPasswordDialog(t);
                                      case 'delete':
                                        _confirmDeleteTeacher(t);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: ListTile(
                                        leading: Icon(Icons.edit),
                                        title: Text('Edit Profile'),
                                      ),
                                    ),
                                    if (t.isActive)
                                      const PopupMenuItem(
                                        value: 'deactivate',
                                        child: ListTile(
                                          leading: Icon(
                                            Icons.block,
                                            color: Colors.orange,
                                          ),
                                          title: Text('Deactivate'),
                                        ),
                                      ),
                                    if (!t.isActive)
                                      const PopupMenuItem(
                                        value: 'activate',
                                        child: ListTile(
                                          leading: Icon(
                                            Icons.check_circle_outline,
                                            color: Colors.green,
                                          ),
                                          title: Text('Reactivate'),
                                        ),
                                      ),
                                    const PopupMenuItem(
                                      value: 'reset_password',
                                      child: ListTile(
                                        leading: Icon(Icons.lock_reset),
                                        title: Text('Reset Password'),
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: ListTile(
                                        leading: Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        title: Text('Delete Teacher'),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
          ),
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous 20',
                    onPressed: currentPage > 1
                        ? () => setState(() => _page = currentPage - 1)
                        : null,
                  ),
                  Text(
                    'Page $currentPage of $totalPages (${filteredTeachers.length} teachers)',
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next 20',
                    onPressed: currentPage < totalPages
                        ? () => setState(() => _page = currentPage + 1)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: isArchived
          ? null
          : FloatingActionButton(
              onPressed: _showCreateTeacherDialog,
              tooltip: 'Create Teacher',
              child: const Icon(Icons.person_add),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 4: Students — List (with class filter + search), Create, Bulk CSV Import
// ═══════════════════════════════════════════════════════════════════════════════

class _StudentsTab extends StatefulWidget {
  final ApiService api;
  final List<SchoolClass> classes;
  final AcademicYear? selectedYear;
  final void Function(String, {bool error}) snack;
  const _StudentsTab({
    required this.api,
    required this.classes,
    required this.selectedYear,
    required this.snack,
  });

  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> {
  List<Student> _students = [];
  bool _loading = false;
  SchoolClass? _filterClass;
  final _searchCtrl = TextEditingController();
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    if (widget.classes.isNotEmpty) {
      _filterClass = widget.classes.first;
    }
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _loading = true);
    try {
      final query = _searchCtrl.text.trim().toLowerCase();
      final res = await widget.api.listStudents(
        classId: _filterClass?.id,
        academicYearId: widget.selectedYear?.id,
        search: query.isNotEmpty ? query : null,
        page: _page,
        pageSize: 20,
      );
      var fetched = res.data.map((x) => Student.fromJson(x)).toList();
      if (query.isNotEmpty) {
        fetched = fetched.where((s) {
          return s.fullName.toLowerCase().contains(query) ||
              s.admissionNumber.toLowerCase().contains(query) ||
              s.rollNumber.toLowerCase().contains(query);
        }).toList();
      }
      setState(() {
        _students = fetched;
        _totalPages = res.totalPages;
      });
    } catch (e) {
      widget.snack('Error loading students: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCreateStudentDialog() {
    final admCtrl = TextEditingController();
    final rollCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final dobCtrl = TextEditingController();
    final guardianCtrl = TextEditingController();
    final guardianPhoneCtrl = TextEditingController();
    String gender = 'M';
    SchoolClass? cls =
        _filterClass ??
        (widget.classes.isNotEmpty ? widget.classes.first : null);
    String? errorMsg;
    bool isSubmitting = false;
    String? lastRollNumber;
    bool isLoadingNextInfo = false;
    bool initialLoaded = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setD) {
          void loadNextInfo(String classId) async {
            setD(() => isLoadingNextInfo = true);
            try {
              final res = await widget.api.getNextStudentInfo(classId);
              if (res != null && res is Map) {
                final nextAdm = res['next_admission_number']?.toString();
                final lastRoll = res['last_roll_number']?.toString();
                final suggestedRoll = res['suggested_next_roll_number']
                    ?.toString();
                setD(() {
                  lastRollNumber = lastRoll;
                  if (admCtrl.text.isEmpty && nextAdm != null) {
                    admCtrl.text = nextAdm;
                  }
                  if (rollCtrl.text.isEmpty && suggestedRoll != null) {
                    rollCtrl.text = suggestedRoll;
                  }
                  isLoadingNextInfo = false;
                });
              }
            } catch (_) {
              setD(() => isLoadingNextInfo = false);
            }
          }

          if (!initialLoaded && cls != null) {
            initialLoaded = true;
            loadNextInfo(cls!.id);
          }

          return AlertDialog(
            title: const Text('Create Student'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (errorMsg != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMsg!,
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SearchableDropdown<SchoolClass>(
                      value: cls,
                      labelText: 'Class *',
                      items: widget.classes,
                      itemAsString: (c) => c.displayName,
                      onChanged: isSubmitting
                          ? null
                          : (v) {
                              setD(() {
                                cls = v;
                                admCtrl.clear();
                                rollCtrl.clear();
                                lastRollNumber = null;
                              });
                              if (v != null) loadNextInfo(v.id);
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: admCtrl,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        labelText: 'Admission Number *',
                        helperText: 'Auto-generated next admission number',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.refresh, size: 18),
                          tooltip: 'Refresh next numbers',
                          onPressed: (isSubmitting || cls == null)
                              ? null
                              : () => loadNextInfo(cls!.id),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Roll Number *',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (isLoadingNextInfo)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        else if (lastRollNumber != null)
                          Text(
                            'Last roll no: $lastRollNumber',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: rollCtrl,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        hintText: 'Enter Roll Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdown<String>(
                      value: gender,
                      labelText: 'Gender',
                      items: const ['M', 'F', 'O'],
                      itemAsString: (g) =>
                          g == 'M' ? 'Male' : (g == 'F' ? 'Female' : 'Other'),
                      onChanged: isSubmitting
                          ? null
                          : (v) => setD(() => gender = v ?? 'M'),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: isSubmitting
                          ? null
                          : () async {
                              final current =
                                  DateTime.tryParse(dobCtrl.text) ??
                                  DateTime(2012, 1, 1);
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: current,
                                firstDate: DateTime(1990),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                dobCtrl.text =
                                    "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                              }
                            },
                      child: IgnorePointer(
                        child: TextField(
                          controller: dobCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Date of Birth (DOB)',
                            hintText: 'Select date of birth',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: guardianCtrl,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Guardian Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: guardianPhoneCtrl,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Guardian Phone',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (cls == null) {
                          setD(() => errorMsg = 'Please select a class');
                          return;
                        }
                        final roll = rollCtrl.text.trim();
                        if (roll.isEmpty) {
                          setD(() => errorMsg = 'Roll Number is required');
                          return;
                        }
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          setD(() => errorMsg = 'Full Name is required');
                          return;
                        }

                        setD(() {
                          isSubmitting = true;
                          errorMsg = null;
                        });

                        final nav = Navigator.of(dialogCtx);
                        try {
                          await widget.api.createStudent({
                            'class_id': cls!.id,
                            'admission_number': admCtrl.text.trim(),
                            'roll_number': roll,
                            'full_name': name,
                            'gender': gender,
                            'dob': dobCtrl.text.trim(),
                            'guardian_name': guardianCtrl.text.trim(),
                            'guardian_phone': guardianPhoneCtrl.text.trim(),
                          });
                          nav.pop();
                          widget.snack(
                            'Student created successfully',
                            error: false,
                          );
                          _loadStudents();
                        } catch (e) {
                          var msg = e.toString();
                          if (e is ApiException) {
                            msg = e.message;
                          } else {
                            msg = msg
                                .replaceAll('Exception: ', '')
                                .replaceAll('ApiException: ', '');
                          }
                          setD(() {
                            isSubmitting = false;
                            errorMsg = msg;
                          });
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('CREATE'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditStudentDialog(Student s) {
    final admCtrl = TextEditingController(text: s.admissionNumber);
    final rollCtrl = TextEditingController(text: s.rollNumber);
    final nameCtrl = TextEditingController(text: s.fullName);
    final dobCtrl = TextEditingController(text: s.dob ?? '');
    final guardianCtrl = TextEditingController(text: s.guardianName ?? '');
    final guardianPhoneCtrl = TextEditingController(
      text: s.guardianPhone ?? '',
    );
    String gender = s.gender ?? 'M';
    SchoolClass? cls = widget.classes.firstWhere(
      (c) => c.id == s.classId,
      orElse: () => widget.classes.first,
    );
    String? errorMsg;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setD) => AlertDialog(
          title: const Text('Edit Student Profile'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (errorMsg != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMsg!,
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SearchableDropdown<SchoolClass>(
                    value: cls,
                    labelText: 'Class *',
                    items: widget.classes,
                    itemAsString: (c) => c.displayName,
                    onChanged: isSubmitting ? null : (v) => setD(() => cls = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: admCtrl,
                    enabled: !isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Admission Number *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: rollCtrl,
                    enabled: !isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Roll Number *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    enabled: !isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SearchableDropdown<String>(
                    value: gender,
                    labelText: 'Gender',
                    items: const ['M', 'F', 'O'],
                    itemAsString: (g) =>
                        g == 'M' ? 'Male' : (g == 'F' ? 'Female' : 'Other'),
                    onChanged: isSubmitting
                        ? null
                        : (v) => setD(() => gender = v ?? 'M'),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: isSubmitting
                        ? null
                        : () async {
                            final current =
                                DateTime.tryParse(dobCtrl.text) ??
                                DateTime(2012, 1, 1);
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: current,
                              firstDate: DateTime(1990),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              dobCtrl.text =
                                  "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                            }
                          },
                    child: IgnorePointer(
                      child: TextField(
                        controller: dobCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Date of Birth (DOB)',
                          hintText: 'Select date of birth',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: guardianCtrl,
                    enabled: !isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Guardian Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: guardianPhoneCtrl,
                    enabled: !isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Guardian Phone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (cls == null) {
                        setD(() => errorMsg = 'Please select a class');
                        return;
                      }
                      final adm = admCtrl.text.trim();
                      if (adm.isEmpty) {
                        setD(() => errorMsg = 'Admission Number is required');
                        return;
                      }
                      final roll = rollCtrl.text.trim();
                      if (roll.isEmpty) {
                        setD(() => errorMsg = 'Roll Number is required');
                        return;
                      }
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        setD(() => errorMsg = 'Full Name is required');
                        return;
                      }

                      setD(() {
                        isSubmitting = true;
                        errorMsg = null;
                      });

                      final nav = Navigator.of(dialogCtx);
                      try {
                        await widget.api.updateStudent(s.id, {
                          'class_id': cls!.id,
                          'admission_number': adm,
                          'roll_number': roll,
                          'full_name': name,
                          'gender': gender,
                          'dob': dobCtrl.text.trim(),
                          'guardian_name': guardianCtrl.text.trim(),
                          'guardian_phone': guardianPhoneCtrl.text.trim(),
                        });
                        nav.pop();
                        widget.snack(
                          'Student updated successfully',
                          error: false,
                        );
                        _loadStudents();
                      } catch (e) {
                        var msg = e.toString();
                        if (e is ApiException) {
                          msg = e.message;
                        } else {
                          msg = msg
                              .replaceAll('Exception: ', '')
                              .replaceAll('ApiException: ', '');
                        }
                        setD(() {
                          isSubmitting = false;
                          errorMsg = msg;
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteStudent(Student s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text(
          'Are you sure you want to delete ${s.fullName} (Adm: ${s.admissionNumber}, Roll: ${s.rollNumber})? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              try {
                await widget.api.deleteStudent(s.id);
                nav.pop();
                widget.snack('Student deleted successfully', error: false);
                _loadStudents();
              } catch (e) {
                widget.snack('Failed to delete student: $e');
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) {
        widget.snack('Could not read file bytes');
        return;
      }
      await widget.api.bulkImportStudents(
        file.bytes!,
        file.name,
        classId: _filterClass?.id,
      );
      widget.snack('Bulk import successful', error: false);
      _loadStudents();
    } catch (e) {
      widget.snack('Bulk import failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedYear == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school_outlined,
                size: 64,
                color: Colors.orange.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No Academic Session Selected',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please create or select an Academic Session in the "Sessions" tab to view and manage students.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final isArchived = widget.selectedYear?.isArchived == true;

    return Scaffold(
      body: Column(
        children: [
          if (isArchived)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: Colors.orange.shade800,
              child: Row(
                children: const [
                  Icon(Icons.lock, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'This Academic Session is Archived (Read-Only Mode). Modifications are locked.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          // Filters
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: SearchableDropdown<SchoolClass?>(
                    value: _filterClass,
                    labelText: 'Filter by Class',
                    isDense: true,
                    items: [null, ...widget.classes],
                    itemAsString: (c) => c == null ? 'No Class' : c.displayName,
                    onChanged: (v) {
                      setState(() {
                        _filterClass = v;
                        _page = 1;
                      });
                      _loadStudents();
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) {
                      setState(() {
                        _page = 1;
                      });
                      _loadStudents();
                    },
                    decoration: InputDecoration(
                      labelText: 'Search',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchCtrl.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {
                                  _page = 1;
                                });
                                _loadStudents();
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () {
                              _page = 1;
                              _loadStudents();
                            },
                          ),
                        ],
                      ),
                    ),
                    onSubmitted: (_) {
                      _page = 1;
                      _loadStudents();
                    },
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Download Template CSV'),
                  onPressed: () async {
                    try {
                      final file = await widget.api.downloadStudentTemplate();
                      triggerDownload(
                        file.bytes,
                        file.fileName ?? 'students_template.csv',
                        'text/csv',
                      );
                      widget.snack('Template downloaded', error: false);
                    } catch (e) {
                      widget.snack('Failed to download template: $e');
                    }
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('CSV Import'),
                  onPressed: isArchived ? null : _bulkImport,
                ),
              ],
            ),
          ),
          // Student list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _students.isEmpty
                ? const Center(child: Text('No students found.'))
                : ListView.builder(
                    itemCount: _students.length,
                    itemBuilder: (_, i) {
                      final s = _students[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 3,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              s.rollNumber.isNotEmpty ? s.rollNumber : '?',
                            ),
                          ),
                          title: Text(s.fullName),
                          subtitle: Text(
                            'Adm: ${s.admissionNumber} • ${s.gender ?? ''}${s.guardianName != null ? ' • Guardian: ${s.guardianName}' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                tooltip: 'Edit Profile',
                                onPressed: isArchived
                                    ? null
                                    : () => _showEditStudentDialog(s),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                tooltip: 'Delete Student',
                                onPressed: isArchived
                                    ? null
                                    : () => _confirmDeleteStudent(s),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Pagination
          if (_totalPages > 1)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous 20',
                    onPressed: _page > 1
                        ? () {
                            setState(() => _page--);
                            _loadStudents();
                          }
                        : null,
                  ),
                  Text('Page $_page of $_totalPages'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next 20',
                    onPressed: _page < _totalPages
                        ? () {
                            setState(() => _page++);
                            _loadStudents();
                          }
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: isArchived
          ? null
          : FloatingActionButton(
              onPressed: _showCreateStudentDialog,
              tooltip: 'Create Student',
              child: const Icon(Icons.person_add),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB: Reports Center — Matrix Grid, Summary, Defaulters, Audit Logs
// ═══════════════════════════════════════════════════════════════════════════════

class _ReportsTab extends StatefulWidget {
  final ApiService api;
  final List<SchoolClass> classes;
  final AcademicYear? selectedYear;
  final void Function(String, {bool error}) snack;

  const _ReportsTab({
    required this.api,
    required this.classes,
    required this.selectedYear,
    required this.snack,
  });

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  String _reportType =
      'matrix'; // 'matrix', 'class_summary', 'defaulters', 'audit_log'
  SchoolClass? _selectedClass;
  int _selectedYear = 2026;
  int _selectedMonth = 6; // June 2026 seed default
  double _threshold = 75;

  bool _loading = false;
  bool _exporting = false;
  dynamic _previewData;

  final _sessionIdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.classes.isNotEmpty) {
      _selectedClass = widget.classes.first;
      _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    setState(() => _loading = true);
    try {
      if (_reportType == 'matrix') {
        if (_selectedClass == null) return;
        final res = await widget.api.getMonthlyMatrix(
          _selectedClass!.id,
          year: _selectedYear,
          month: _selectedMonth,
        );
        _previewData = res is Map ? res['data'] ?? res : res;
      } else if (_reportType == 'class_summary') {
        if (_selectedClass == null) return;
        final res = await widget.api.getClassSummary(
          _selectedClass!.id,
          from: '2026-06-01',
          to: '2026-07-25',
        );
        _previewData = res is Map ? res['data'] ?? res : res;
      } else if (_reportType == 'defaulters') {
        final res = await widget.api.getSchoolDefaulters(
          classId: _selectedClass?.id,
          from: '2026-06-01',
          to: '2026-07-25',
          threshold: _threshold,
        );
        _previewData = res is Map ? res['data'] ?? res : res;
      } else if (_reportType == 'audit_log') {
        final res = await widget.api.getAuditLogs(
          from: '2026-06-01',
          to: '2026-07-25',
        );
        _previewData = res is Map ? res['data'] ?? res : res;
      }
    } catch (e) {
      widget.snack('Error loading report preview: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportReport(String format) async {
    setState(() => _exporting = true);
    try {
      DownloadedFile file;
      if (_reportType == 'matrix') {
        if (_selectedClass == null) {
          widget.snack('Select a class first');
          return;
        }
        file = await widget.api.exportMonthlyMatrix(
          _selectedClass!.id,
          year: _selectedYear,
          month: _selectedMonth,
        );
      } else if (_reportType == 'defaulters') {
        file = await widget.api.exportDefaultersReport(
          classId: _selectedClass?.id,
          from: '2026-06-01',
          to: '2026-07-25',
          threshold: _threshold,
        );
      } else if (_reportType == 'audit_log') {
        file = await widget.api.exportAuditLogs(
          from: '2026-06-01',
          to: '2026-07-25',
        );
      } else {
        if (_selectedClass == null) {
          widget.snack('Select a class first');
          return;
        }
        file = await widget.api.exportClassReport(
          _selectedClass!.id,
          format: format,
        );
      }
      triggerDownload(
        file.bytes,
        file.fileName ?? 'report.$format',
        file.contentType ?? 'application/octet-stream',
      );
      widget.snack(
        'Export downloaded successfully: ${file.fileName}',
        error: false,
      );
    } catch (e) {
      widget.snack('Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _reopenSession() async {
    final sid = _sessionIdCtrl.text.trim();
    if (sid.isEmpty) {
      widget.snack('Enter a session ID');
      return;
    }
    try {
      await widget.api.reopenAttendanceSession(sid);
      widget.snack('Session reopened successfully', error: false);
    } catch (e) {
      widget.snack('Failed to reopen session: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedYear == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_outlined,
              size: 64,
              color: Colors.orange.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Academic Session Selected',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please select an Academic Session to access the Reports Center.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Controls Card
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reports Center & Export Hub',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select a report type, configure parameters, preview on-screen, and export in CSV/PDF formats',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<String>(
                          initialValue: _reportType,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Report Type',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'matrix',
                              child: Text(
                                '📅 Monthly Attendance Grid Sheet',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'class_summary',
                              child: Text(
                                '📊 Class Attendance Summary',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'defaulters',
                              child: Text(
                                '⚠️ Defaulters List Report',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'audit_log',
                              child: Text(
                                '🔍 Attendance Audit Log',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _reportType = v);
                              _loadPreview();
                            }
                          },
                        ),
                      ),
                      if (_reportType != 'audit_log')
                        SizedBox(
                          width: 200,
                          child: SearchableDropdown<SchoolClass?>(
                            value: _selectedClass,
                            labelText: 'Class',
                            isDense: true,
                            items: [
                              if (_reportType == 'defaulters') null,
                              ...widget.classes,
                            ],
                            itemAsString: (c) =>
                                c == null ? 'All Classes' : c.displayName,
                            onChanged: (v) {
                              setState(() => _selectedClass = v);
                              _loadPreview();
                            },
                          ),
                        ),
                      if (_reportType == 'matrix') ...[
                        SizedBox(
                          width: 90,
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedMonth,
                            decoration: const InputDecoration(
                              labelText: 'Month',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: List.generate(
                              12,
                              (i) => DropdownMenuItem(
                                value: i + 1,
                                child: Text('${i + 1}'),
                              ),
                            ),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _selectedMonth = v);
                                _loadPreview();
                              }
                            },
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedYear,
                            decoration: const InputDecoration(
                              labelText: 'Year',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 2025,
                                child: Text('2025'),
                              ),
                              DropdownMenuItem(
                                value: 2026,
                                child: Text('2026'),
                              ),
                              DropdownMenuItem(
                                value: 2027,
                                child: Text('2027'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _selectedYear = v);
                                _loadPreview();
                              }
                            },
                          ),
                        ),
                      ],
                      if (_reportType == 'defaulters')
                        SizedBox(
                          width: 110,
                          child: TextFormField(
                            initialValue: _threshold.toStringAsFixed(0),
                            decoration: const InputDecoration(
                              labelText: 'Cutoff %',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            onFieldSubmitted: (v) {
                              _threshold = double.tryParse(v) ?? 75;
                              _loadPreview();
                            },
                          ),
                        ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.remove_red_eye, size: 16),
                        label: const Text('Refresh Preview'),
                        onPressed: _loadPreview,
                      ),
                      ElevatedButton.icon(
                        icon: _exporting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download, size: 16),
                        label: const Text('Export CSV'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _exporting
                            ? null
                            : () => _exportReport('csv'),
                      ),
                      if (_reportType == 'class_summary')
                        ElevatedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf, size: 16),
                          label: const Text('Export PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _exporting
                              ? null
                              : () => _exportReport('pdf'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Live Preview Section
          Text(
            'Live Report Preview',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_previewData == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No preview data generated. Adjust parameters above.',
                  ),
                ),
              ),
            )
          else ...[
            if (_reportType == 'matrix') _buildMatrixPreview(_previewData),
            if (_reportType == 'class_summary')
              _buildClassSummaryPreview(_previewData),
            if (_reportType == 'defaulters')
              _buildDefaultersPreview(_previewData),
            if (_reportType == 'audit_log') _buildAuditLogPreview(_previewData),
          ],

          const Divider(height: 40),

          // Admin Utility: Reopen Session
          Text(
            'Reopen Closed Attendance Session (Admin Only)',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _sessionIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Session ID (UUID)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.lock_open, size: 16),
                label: const Text('Reopen Session'),
                onPressed: _reopenSession,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _matrixLegendChip(String code, String label, MaterialColor color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            code,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color.shade900,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
        ),
      ],
    );
  }

  Widget _buildMatrixPreview(dynamic data) {
    if (data is! Map) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Invalid matrix data'),
        ),
      );
    }

    final className = data['class_name'] ?? 'Class';
    final daysInMonth = (data['days_in_month'] as num?)?.toInt() ?? 30;
    final students = (data['students'] as List?) ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$className — Attendance Grid Sheet (${data['month']}/${data['year']})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Total Students: ${students.length}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Status Legend for Admin Understanding
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Status Key:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                _matrixLegendChip('P', 'Present', Colors.green),
                _matrixLegendChip('L', 'Late', Colors.orange),
                _matrixLegendChip('A', 'Absent', Colors.red),
                _matrixLegendChip('E', 'Excused', Colors.blue),
                _matrixLegendChip('-', 'No Record', Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 10,
                headingRowHeight: 36,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 36,
                columns: [
                  const DataColumn(label: Text('Roll')),
                  const DataColumn(label: Text('Student Name')),
                  ...List.generate(
                    daysInMonth,
                    (i) => DataColumn(
                      label: Center(
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'P',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'A',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'L',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                rows: students.map<DataRow>((st) {
                  final roll = st['roll_number'] ?? '';
                  final name = st['full_name'] ?? '';
                  final daily = (st['daily_status'] as Map?) ?? {};
                  final pCount = st['total_present'] ?? 0;
                  final aCount = st['total_absent'] ?? 0;
                  final lCount = st['total_late'] ?? 0;

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(roll, style: const TextStyle(fontSize: 11)),
                      ),
                      DataCell(
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ...List.generate(daysInMonth, (i) {
                        final dStr = fmtDate(
                          _selectedYear,
                          _selectedMonth,
                          i + 1,
                        );
                        final code = daily[dStr] ?? '-';
                        Color badgeColor = Colors.transparent;
                        Color textColor = Colors.black45;
                        if (code == 'P') {
                          badgeColor = Colors.green.shade100;
                          textColor = Colors.green.shade900;
                        } else if (code == 'A') {
                          badgeColor = Colors.red.shade100;
                          textColor = Colors.red.shade900;
                        } else if (code == 'L') {
                          badgeColor = Colors.orange.shade100;
                          textColor = Colors.orange.shade900;
                        } else if (code == 'E') {
                          badgeColor = Colors.blue.shade100;
                          textColor = Colors.blue.shade900;
                        }
                        return DataCell(
                          Center(
                            child: Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: badgeColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                code,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      DataCell(
                        Text(
                          '$pCount',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '$aCount',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '$lCount',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassSummaryPreview(dynamic data) {
    if (data is! Map) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No summary data'),
        ),
      );
    }
    final pct = (data['attendance_percentage'] as num?)?.toDouble() ?? 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Class Summary Statistics',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _previewMetric(
                  'Attendance %',
                  '${pct.toStringAsFixed(1)}%',
                  pct >= 85 ? Colors.green : Colors.orange,
                ),
                _previewMetric(
                  'Total Sessions',
                  '${data['total_sessions'] ?? 0}',
                  Colors.purple,
                ),
                _previewMetric(
                  'Present Marks',
                  '${data['present'] ?? 0}',
                  Colors.green,
                ),
                _previewMetric(
                  'Absent Marks',
                  '${data['absent'] ?? 0}',
                  Colors.red,
                ),
                _previewMetric(
                  'Late Marks',
                  '${data['late'] ?? 0}',
                  Colors.orange,
                ),
                _previewMetric(
                  'Excused Marks',
                  '${data['excused'] ?? 0}',
                  Colors.teal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultersPreview(dynamic data) {
    final list = data is List ? data : [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Defaulters Preview (${list.length} Students)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Text('No defaulters found in this range.')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Roll')),
                    DataColumn(label: Text('Student Name')),
                    DataColumn(label: Text('Class')),
                    DataColumn(label: Text('Guardian Phone')),
                    DataColumn(label: Text('Present / Total')),
                    DataColumn(label: Text('Attendance %')),
                  ],
                  rows: list.map<DataRow>((d) {
                    final pct =
                        (d['attendance_pct'] as num?)?.toDouble() ?? 0.0;
                    return DataRow(
                      cells: [
                        DataCell(Text(d['roll_number'] ?? '')),
                        DataCell(
                          Text(
                            d['full_name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataCell(Text(d['class_name'] ?? '')),
                        DataCell(Text(d['guardian_phone'] ?? '-')),
                        DataCell(
                          Text(
                            '${d['present_count'] ?? 0} / ${d['total_sessions'] ?? 0}',
                          ),
                        ),
                        DataCell(
                          Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: pct < 50 ? Colors.red : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditLogPreview(dynamic data) {
    final list = data is List ? data : [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audit Log Exception Preview (${list.length} Modifications)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Text(
                'No attendance modifications logged in this date range.',
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Student')),
                    DataColumn(label: Text('Class')),
                    DataColumn(label: Text('Session Date')),
                    DataColumn(label: Text('Old Status')),
                    DataColumn(label: Text('New Status')),
                    DataColumn(label: Text('Changed By')),
                  ],
                  rows: list.map<DataRow>((l) {
                    final oldStat = l['old_status'] ?? '-';
                    final newStat = l['new_status'] ?? '';
                    return DataRow(
                      cells: [
                        DataCell(Text(l['student_name'] ?? '')),
                        DataCell(Text(l['class_name'] ?? '')),
                        DataCell(
                          Text(
                            (l['session_date'] as String? ?? '').split('T')[0],
                          ),
                        ),
                        DataCell(
                          Text(
                            oldStat,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        DataCell(
                          Text(
                            newStat,
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(Text(l['changed_by_name'] ?? '')),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _previewMetric(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String fmtDate(int y, int m, int d) {
    return "$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}";
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 0: Academic Sessions Management — List, Create, Set Active, Archive, Promote, Copy Teachers
// ═══════════════════════════════════════════════════════════════════════════════

class _AcademicSessionsTab extends StatefulWidget {
  final ApiService api;
  final List<AcademicYear> years;
  final AcademicYear? selectedYear;
  final List<SchoolClass> classes;
  final List<User> teachers;
  final VoidCallback onRefresh;
  final void Function(String, {bool error}) snack;

  const _AcademicSessionsTab({
    required this.api,
    required this.years,
    required this.selectedYear,
    required this.classes,
    required this.teachers,
    required this.onRefresh,
    required this.snack,
  });

  @override
  State<_AcademicSessionsTab> createState() => _AcademicSessionsTabState();
}

class _AcademicSessionsTabState extends State<_AcademicSessionsTab> {
  // Copy Classes state
  AcademicYear? _copyClassSourceYear;
  AcademicYear? _copyClassTargetYear;
  bool _copyingClasses = false;

  // Copy Teachers state
  AcademicYear? _copyTeacherSourceYear;
  AcademicYear? _copyTeacherTargetYear;
  bool _copyingTeachers = false;

  // Move Students (Same Session) state
  SchoolClass? _moveSourceClass;
  SchoolClass? _moveTargetClass;
  List<Student> _moveSourceStudents = [];
  Set<String> _selectedMoveStudentIds = {};
  bool _loadingMoveStudents = false;
  bool _moving = false;

  // Promote Students (Cross Session) state
  AcademicYear? _promoteSourceYear;
  AcademicYear? _promoteTargetYear;
  List<SchoolClass> _promoteSourceClasses = [];
  List<SchoolClass> _promoteTargetClasses = [];
  SchoolClass? _promoteSourceClass;
  SchoolClass? _promoteTargetClass;
  List<Student> _promoteSourceStudents = [];
  Set<String> _selectedPromoteStudentIds = {};
  bool _loadingPromoteStudents = false;
  bool _promoting = false;

  int _studentOperationMode =
      0; // 0: Move (Same Session), 1: Promote (Cross Session)

  void _showCreateYearDialog() {
    final nameCtrl = TextEditingController();
    final startCtrl = TextEditingController(text: '2026-06-01');
    final endCtrl = TextEditingController(text: '2027-03-31');
    bool isCurrent = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setD) => AlertDialog(
          title: const Text('Create New Academic Session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Session Name (e.g. 2026-2027)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: startCtrl,
                decoration: const InputDecoration(
                  labelText: 'Start Date (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: endCtrl,
                decoration: const InputDecoration(
                  labelText: 'End Date (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('Set as Active Current Session'),
                value: isCurrent,
                onChanged: (v) => setD(() => isCurrent = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final nav = Navigator.of(dialogCtx);
                try {
                  await widget.api.createAcademicYear({
                    'name': name,
                    'start_date': startCtrl.text.trim(),
                    'end_date': endCtrl.text.trim(),
                    'is_current': isCurrent,
                  });
                  nav.pop();
                  widget.snack(
                    'Academic session created successfully',
                    error: false,
                  );
                  widget.onRefresh();
                } catch (e) {
                  widget.snack('Failed to create session: $e');
                }
              },
              child: const Text('CREATE'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeCopyClasses() async {
    if (_copyClassSourceYear == null || _copyClassTargetYear == null) {
      widget.snack('Please select both source and target sessions');
      return;
    }
    if (_copyClassSourceYear!.id == _copyClassTargetYear!.id) {
      widget.snack('Source and target sessions must be different');
      return;
    }

    setState(() => _copyingClasses = true);
    try {
      final res = await widget.api.copyClasses({
        'source_academic_year_id': _copyClassSourceYear!.id,
        'target_academic_year_id': _copyClassTargetYear!.id,
      });
      final count = res is Map ? res['copied'] : 0;
      widget.snack(
        'Successfully copied $count class structures to ${_copyClassTargetYear!.name}',
        error: false,
      );
      widget.onRefresh();
    } catch (e) {
      widget.snack('Failed to copy classes: $e');
    } finally {
      if (mounted) setState(() => _copyingClasses = false);
    }
  }

  Future<void> _executeTeacherRollover() async {
    if (_copyTeacherSourceYear == null || _copyTeacherTargetYear == null) {
      widget.snack('Please select source and target academic sessions');
      return;
    }
    if (_copyTeacherSourceYear!.id == _copyTeacherTargetYear!.id) {
      widget.snack('Source and target sessions must be different');
      return;
    }

    setState(() => _copyingTeachers = true);
    try {
      final res = await widget.api.copyTeachers({
        'source_academic_year_id': _copyTeacherSourceYear!.id,
        'target_academic_year_id': _copyTeacherTargetYear!.id,
      });
      final copied = res is Map ? res['copied'] : 0;
      widget.snack(
        'Teacher assignments copied to ${_copyTeacherTargetYear!.name} ($copied class assignments mapped)',
        error: false,
      );
      widget.onRefresh();
    } catch (e) {
      widget.snack('Failed to copy teacher assignments: $e');
    } finally {
      if (mounted) setState(() => _copyingTeachers = false);
    }
  }

  Future<void> _loadMoveSourceStudents() async {
    if (_moveSourceClass == null) {
      setState(() {
        _moveSourceStudents = [];
        _selectedMoveStudentIds.clear();
      });
      return;
    }
    setState(() => _loadingMoveStudents = true);
    try {
      final res = await widget.api.listStudents(
        classId: _moveSourceClass!.id,
        pageSize: 100,
      );
      final students = res.data.map((x) => Student.fromJson(x)).toList();
      setState(() {
        _moveSourceStudents = students;
        _selectedMoveStudentIds = students.map((s) => s.id).toSet();
      });
    } catch (e) {
      widget.snack('Failed to load students: $e');
    } finally {
      if (mounted) setState(() => _loadingMoveStudents = false);
    }
  }

  Future<void> _executeMoveStudents() async {
    if (_moveSourceClass == null || _moveTargetClass == null) {
      widget.snack('Select both source and target classes');
      return;
    }
    if (_moveSourceClass!.id == _moveTargetClass!.id) {
      widget.snack('Source and target classes must be different');
      return;
    }
    if (_selectedMoveStudentIds.isEmpty) {
      widget.snack('Select at least one student to move');
      return;
    }

    setState(() => _moving = true);
    try {
      final res = await widget.api.promoteStudents({
        'source_class_id': _moveSourceClass!.id,
        'target_class_id': _moveTargetClass!.id,
        'student_ids': _selectedMoveStudentIds.toList(),
      });
      final count = res is Map
          ? res['promoted']
          : _selectedMoveStudentIds.length;
      widget.snack(
        'Successfully moved $count students to ${_moveTargetClass!.displayName}',
        error: false,
      );
      _loadMoveSourceStudents();
      widget.onRefresh();
    } catch (e) {
      widget.snack('Failed to move students: $e');
    } finally {
      if (mounted) setState(() => _moving = false);
    }
  }

  Future<void> _loadPromoteClasses(AcademicYear? year, bool isSource) async {
    if (year == null) return;
    try {
      final cp = await widget.api.listClasses(
        academicYearId: year.id,
        pageSize: 100,
      );
      final clsList = cp.data.map((x) => SchoolClass.fromJson(x)).toList();
      setState(() {
        if (isSource) {
          _promoteSourceClasses = clsList;
          _promoteSourceClass = null;
          _promoteSourceStudents = [];
          _selectedPromoteStudentIds.clear();
        } else {
          _promoteTargetClasses = clsList;
          _promoteTargetClass = null;
        }
      });
    } catch (e) {
      widget.snack('Failed to load classes for ${year.name}: $e');
    }
  }

  Future<void> _loadPromoteSourceStudents() async {
    if (_promoteSourceClass == null) {
      setState(() {
        _promoteSourceStudents = [];
        _selectedPromoteStudentIds.clear();
      });
      return;
    }
    setState(() => _loadingPromoteStudents = true);
    try {
      final res = await widget.api.listStudents(
        classId: _promoteSourceClass!.id,
        pageSize: 100,
      );
      final students = res.data.map((x) => Student.fromJson(x)).toList();
      setState(() {
        _promoteSourceStudents = students;
        _selectedPromoteStudentIds = students.map((s) => s.id).toSet();
      });
    } catch (e) {
      widget.snack('Failed to load students for promotion: $e');
    } finally {
      if (mounted) setState(() => _loadingPromoteStudents = false);
    }
  }

  Future<void> _executePromoteStudents() async {
    if (_promoteSourceClass == null || _promoteTargetClass == null) {
      widget.snack('Select both source and target classes for promotion');
      return;
    }
    if (_selectedPromoteStudentIds.isEmpty) {
      widget.snack('Select at least one student to promote');
      return;
    }

    setState(() => _promoting = true);
    try {
      final res = await widget.api.promoteStudents({
        'source_class_id': _promoteSourceClass!.id,
        'target_class_id': _promoteTargetClass!.id,
        'student_ids': _selectedPromoteStudentIds.toList(),
      });
      final count = res is Map
          ? res['promoted']
          : _selectedPromoteStudentIds.length;
      widget.snack(
        'Successfully promoted $count students to ${_promoteTargetClass!.displayName} (${_promoteTargetYear?.name})',
        error: false,
      );
      _loadPromoteSourceStudents();
      widget.onRefresh();
    } catch (e) {
      widget.snack('Failed to promote students: $e');
    } finally {
      if (mounted) setState(() => _promoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            elevation: 0,
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.school,
                    size: 36,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Academic Sessions & Year Management',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage school academic sessions, duplicate class structures, copy staff assignments, and handle student movement or promotions.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Session'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _showCreateYearDialog,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ─── Section 1: Academic Sessions ──────────────────────────────
          Text(
            'Academic Sessions',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (widget.years.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No academic sessions created yet.'),
              ),
            )
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: widget.years.map((y) {
                final isSelected = widget.selectedYear?.id == y.id;
                return Container(
                  width: 290,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.08)
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              y.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (y.isCurrent)
                            Chip(
                              label: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: Colors.green,
                              visualDensity: VisualDensity.compact,
                            ),
                          if (y.isArchived) ...[
                            const SizedBox(width: 4),
                            Chip(
                              label: const Text(
                                'ARCHIVED 🔒',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: Colors.orange.shade800,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Period: ${y.startDate} to ${y.endDate}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (!y.isCurrent)
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () async {
                                try {
                                  await widget.api.setAcademicYearCurrent(y.id);
                                  widget.snack(
                                    'Set ${y.name} as active session',
                                    error: false,
                                  );
                                  widget.onRefresh();
                                } catch (e) {
                                  widget.snack(
                                    'Failed to set active session: $e',
                                  );
                                }
                              },
                              child: const Text(
                                'Set Active',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          const Spacer(),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () async {
                              try {
                                if (y.isArchived) {
                                  await widget.api.unarchiveAcademicYear(y.id);
                                  widget.snack(
                                    'Unarchived ${y.name}',
                                    error: false,
                                  );
                                } else {
                                  await widget.api.archiveAcademicYear(y.id);
                                  widget.snack(
                                    'Archived ${y.name} (read-only)',
                                    error: false,
                                  );
                                }
                                widget.onRefresh();
                              } catch (e) {
                                widget.snack('Failed to toggle archive: $e');
                              }
                            },
                            child: Text(
                              y.isArchived ? 'Unarchive' : 'Archive',
                              style: TextStyle(
                                fontSize: 11,
                                color: y.isArchived
                                    ? Colors.blue
                                    : Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          const Divider(height: 48),

          // ─── Section 2: Quick Session Setup Tools ─────────────────────
          Text(
            'Session Setup Tools (Avoid Redundant Manual Setup)',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tool 1: Copy Classes
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.copy_all, color: Colors.blue),
                                SizedBox(width: 8),
                                Text(
                                  'Copy Classes to New Session',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Duplicate all grade levels and sections from a past session to a new session in 1 click.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SearchableDropdown<AcademicYear>(
                              value: _copyClassSourceYear,
                              labelText: 'Source Session (Past)',
                              isDense: true,
                              items: widget.years,
                              itemAsString: (y) => y.name,
                              onChanged: (v) =>
                                  setState(() => _copyClassSourceYear = v),
                            ),
                            const SizedBox(height: 8),
                            SearchableDropdown<AcademicYear>(
                              value: _copyClassTargetYear,
                              labelText: 'Target Session (New)',
                              isDense: true,
                              items: widget.years,
                              itemAsString: (y) => y.name,
                              onChanged: (v) =>
                                  setState(() => _copyClassTargetYear = v),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: _copyingClasses
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.file_copy, size: 16),
                                label: const Text('Copy Classes'),
                                onPressed:
                                    _copyingClasses ||
                                        _copyClassSourceYear == null ||
                                        _copyClassTargetYear == null
                                    ? null
                                    : _executeCopyClasses,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (isWide)
                    const SizedBox(width: 16)
                  else
                    const SizedBox(height: 12),
                  // Tool 2: Copy Teachers
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.badge, color: Colors.indigo),
                                SizedBox(width: 8),
                                Text(
                                  'Copy Teacher Assignments',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Copy class teacher assignments from a past session to matching classes in a new session.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SearchableDropdown<AcademicYear>(
                              value: _copyTeacherSourceYear,
                              labelText: 'Source Session (Past)',
                              isDense: true,
                              items: widget.years,
                              itemAsString: (y) => y.name,
                              onChanged: (v) =>
                                  setState(() => _copyTeacherSourceYear = v),
                            ),
                            const SizedBox(height: 8),
                            SearchableDropdown<AcademicYear>(
                              value: _copyTeacherTargetYear,
                              labelText: 'Target Session (New)',
                              isDense: true,
                              items: widget.years,
                              itemAsString: (y) => y.name,
                              onChanged: (v) =>
                                  setState(() => _copyTeacherTargetYear = v),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: _copyingTeachers
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.people_outline,
                                        size: 16,
                                      ),
                                label: const Text('Copy Teacher Assignments'),
                                onPressed:
                                    _copyingTeachers ||
                                        _copyTeacherSourceYear == null ||
                                        _copyTeacherTargetYear == null
                                    ? null
                                    : _executeTeacherRollover,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const Divider(height: 48),

          // ─── Section 3: Student Operations (Move vs Promote) ───────────
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Student Operations & Transitions',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('Move (Same Session)'),
                    icon: Icon(Icons.swap_horiz, size: 16),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('Promote (Cross Session)'),
                    icon: Icon(Icons.school, size: 16),
                  ),
                ],
                selected: {_studentOperationMode},
                onSelectionChanged: (setVal) {
                  setState(() => _studentOperationMode = setVal.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_studentOperationMode == 0) ...[
            // MOVE STUDENTS WITHIN SAME SESSION
            Text(
              'Move students between classes/sections within the same academic session.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 250,
                  child: SearchableDropdown<SchoolClass>(
                    value: _moveSourceClass,
                    labelText: 'Source Class (Current Session)',
                    isDense: true,
                    items: widget.classes,
                    itemAsString: (c) => c.displayName,
                    onChanged: (v) {
                      setState(() => _moveSourceClass = v);
                      _loadMoveSourceStudents();
                    },
                  ),
                ),
                const Icon(Icons.arrow_forward),
                SizedBox(
                  width: 250,
                  child: SearchableDropdown<SchoolClass>(
                    value: _moveTargetClass,
                    labelText: 'Target Class (Current Session)',
                    isDense: true,
                    items: widget.classes,
                    itemAsString: (c) => c.displayName,
                    onChanged: (v) => setState(() => _moveTargetClass = v),
                  ),
                ),
                ElevatedButton.icon(
                  icon: _moving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Move Selected Students'),
                  onPressed: _moving || _selectedMoveStudentIds.isEmpty
                      ? null
                      : _executeMoveStudents,
                ),
              ],
            ),

            if (_moveSourceClass != null) ...[
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Container(
                      color: Colors.grey.shade100,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Students in ${_moveSourceClass!.displayName} (${_moveSourceStudents.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedMoveStudentIds =
                                        _moveSourceStudents
                                            .map((s) => s.id)
                                            .toSet();
                                  });
                                },
                                child: const Text('Select All'),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(
                                    () => _selectedMoveStudentIds.clear(),
                                  );
                                },
                                child: const Text('Deselect All'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_loadingMoveStudents)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      )
                    else if (_moveSourceStudents.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No students found in this class.'),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _moveSourceStudents.length,
                        itemBuilder: (_, i) {
                          final st = _moveSourceStudents[i];
                          final isSel = _selectedMoveStudentIds.contains(st.id);
                          return CheckboxListTile(
                            dense: true,
                            title: Text('${st.rollNumber} - ${st.fullName}'),
                            subtitle: Text(
                              'Admission No: ${st.admissionNumber}',
                            ),
                            value: isSel,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedMoveStudentIds.add(st.id);
                                } else {
                                  _selectedMoveStudentIds.remove(st.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ] else ...[
            // PROMOTE STUDENTS ACROSS DIFFERENT SESSIONS
            Text(
              'Promote students from a class in a past session to a class in a new academic session.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: SearchableDropdown<AcademicYear>(
                    value: _promoteSourceYear,
                    labelText: 'Source Session (Past)',
                    isDense: true,
                    items: widget.years,
                    itemAsString: (y) => y.name,
                    onChanged: (v) {
                      setState(() => _promoteSourceYear = v);
                      _loadPromoteClasses(v, true);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: SearchableDropdown<SchoolClass>(
                    value: _promoteSourceClass,
                    labelText: 'Source Class',
                    isDense: true,
                    items: _promoteSourceClasses,
                    itemAsString: (c) => c.displayName,
                    onChanged: (v) {
                      setState(() => _promoteSourceClass = v);
                      _loadPromoteSourceStudents();
                    },
                  ),
                ),
                const Icon(Icons.trending_up, color: Colors.green),
                SizedBox(
                  width: 220,
                  child: SearchableDropdown<AcademicYear>(
                    value: _promoteTargetYear,
                    labelText: 'Target Session (New)',
                    isDense: true,
                    items: widget.years,
                    itemAsString: (y) => y.name,
                    onChanged: (v) {
                      setState(() => _promoteTargetYear = v);
                      _loadPromoteClasses(v, false);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: SearchableDropdown<SchoolClass>(
                    value: _promoteTargetClass,
                    labelText: 'Target Class',
                    isDense: true,
                    items: _promoteTargetClasses,
                    itemAsString: (c) => c.displayName,
                    onChanged: (v) => setState(() => _promoteTargetClass = v),
                  ),
                ),
                ElevatedButton.icon(
                  icon: _promoting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.school, size: 18),
                  label: const Text('Promote Selected Students'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _promoting || _selectedPromoteStudentIds.isEmpty
                      ? null
                      : _executePromoteStudents,
                ),
              ],
            ),

            if (_promoteSourceClass != null) ...[
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Container(
                      color: Colors.grey.shade100,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Students in ${_promoteSourceClass!.displayName} (${_promoteSourceYear?.name}) [${_promoteSourceStudents.length}]',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedPromoteStudentIds =
                                        _promoteSourceStudents
                                            .map((s) => s.id)
                                            .toSet();
                                  });
                                },
                                child: const Text('Select All'),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(
                                    () => _selectedPromoteStudentIds.clear(),
                                  );
                                },
                                child: const Text('Deselect All'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_loadingPromoteStudents)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      )
                    else if (_promoteSourceStudents.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No students found in this class.'),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _promoteSourceStudents.length,
                        itemBuilder: (_, i) {
                          final st = _promoteSourceStudents[i];
                          final isSel = _selectedPromoteStudentIds.contains(
                            st.id,
                          );
                          return CheckboxListTile(
                            dense: true,
                            title: Text('${st.rollNumber} - ${st.fullName}'),
                            subtitle: Text(
                              'Admission No: ${st.admissionNumber}',
                            ),
                            value: isSel,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedPromoteStudentIds.add(st.id);
                                } else {
                                  _selectedPromoteStudentIds.remove(st.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ─── School Days & Holidays Tab ──────────────────────────────────────────────────

class _SchoolDaysTab extends StatefulWidget {
  final ApiService api;
  final AcademicYear? selectedYear;
  final void Function(String msg, {bool error}) snack;

  const _SchoolDaysTab({
    required this.api,
    this.selectedYear,
    required this.snack,
  });

  @override
  State<_SchoolDaysTab> createState() => _SchoolDaysTabState();
}

class _SchoolDaysTabState extends State<_SchoolDaysTab> {
  bool _loadingWeekly = false;
  bool _savingWeekly = false;
  bool _loadingHolidays = false;

  // Default weekly schedule: 0=Sun (false), 1=Mon(true), 2=Tue(true), 3=Wed(true), 4=Thu(true), 5=Fri(true), 6=Sat(true)
  List<WeeklyDaySchedule> _weeklySchedules = [
    WeeklyDaySchedule(dayOfWeek: 0, dayName: 'Sunday', isWorkingDay: false),
    WeeklyDaySchedule(dayOfWeek: 1, dayName: 'Monday', isWorkingDay: true),
    WeeklyDaySchedule(dayOfWeek: 2, dayName: 'Tuesday', isWorkingDay: true),
    WeeklyDaySchedule(dayOfWeek: 3, dayName: 'Wednesday', isWorkingDay: true),
    WeeklyDaySchedule(dayOfWeek: 4, dayName: 'Thursday', isWorkingDay: true),
    WeeklyDaySchedule(dayOfWeek: 5, dayName: 'Friday', isWorkingDay: true),
    WeeklyDaySchedule(dayOfWeek: 6, dayName: 'Saturday', isWorkingDay: true),
  ];

  List<SchoolHoliday> _holidays = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void didUpdateWidget(covariant _SchoolDaysTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedYear?.id != widget.selectedYear?.id) {
      _loadAllData();
    }
  }

  Future<void> _loadAllData() async {
    await Future.wait([_loadWeeklySchedule(), _loadHolidays()]);
  }

  Future<void> _loadWeeklySchedule() async {
    setState(() => _loadingWeekly = true);
    try {
      final res = await widget.api.getWeeklySchedule();
      if (res is List) {
        final loaded = res
            .map((x) => WeeklyDaySchedule.fromJson(x as Map<String, dynamic>))
            .toList();
        if (loaded.isNotEmpty) {
          // Merge loaded with default 7 days ensuring all 0-6 days exist
          final map = {for (var item in loaded) item.dayOfWeek: item};
          setState(() {
            _weeklySchedules = List.generate(7, (d) {
              if (map.containsKey(d)) return map[d]!;
              final name = const [
                'Sunday',
                'Monday',
                'Tuesday',
                'Wednesday',
                'Thursday',
                'Friday',
                'Saturday',
              ][d];
              return WeeklyDaySchedule(
                dayOfWeek: d,
                dayName: name,
                isWorkingDay: d != 0,
              );
            });
          });
        }
      }
    } catch (e) {
      widget.snack('Error loading weekly schedule: $e');
    } finally {
      if (mounted) setState(() => _loadingWeekly = false);
    }
  }

  Future<void> _saveWeeklySchedule() async {
    setState(() => _savingWeekly = true);
    try {
      final payload = _weeklySchedules.map((s) => s.toJson()).toList();
      final res = await widget.api.updateWeeklySchedule(payload);
      if (res is List) {
        final loaded = res
            .map((x) => WeeklyDaySchedule.fromJson(x as Map<String, dynamic>))
            .toList();
        final map = {for (var item in loaded) item.dayOfWeek: item};
        setState(() {
          _weeklySchedules = List.generate(7, (d) {
            if (map.containsKey(d)) return map[d]!;
            final name = const [
              'Sunday',
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
              'Saturday',
            ][d];
            return WeeklyDaySchedule(
              dayOfWeek: d,
              dayName: name,
              isWorkingDay: d != 0,
            );
          });
        });
      }
      widget.snack('Weekly schedule updated successfully!', error: false);
    } catch (e) {
      widget.snack('Error saving weekly schedule: $e');
    } finally {
      if (mounted) setState(() => _savingWeekly = false);
    }
  }

  Future<void> _loadHolidays() async {
    setState(() => _loadingHolidays = true);
    try {
      final res = await widget.api.getSchoolHolidays();
      if (res is List) {
        setState(() {
          _holidays = res
              .map((x) => SchoolHoliday.fromJson(x as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      widget.snack('Error loading holidays: $e');
    } finally {
      if (mounted) setState(() => _loadingHolidays = false);
    }
  }

  Future<void> _showAddHolidayDialog({
    DateTime? initialDate,
    String? initialTitle,
  }) async {
    final titleCtrl = TextEditingController(text: initialTitle ?? '');
    final descCtrl = TextEditingController();
    DateTime selectedDate = initialDate ?? DateTime.now();
    bool isHoliday = true;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final dateStr =
                "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
            final dayOfWeekName = const [
              'Sunday',
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
              'Saturday',
            ][selectedDate.weekday % 7];

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.event, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  const Text('Declare School Holiday / Exception'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configure a specific calendar date as a holiday or special working day.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Holiday Title *',
                        hintText: 'e.g. Diwali - Public Holiday in Maharashtra',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText:
                            'e.g. School closed for Diwali festival celebration',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2025, 1, 1),
                          lastDate: DateTime(2030, 12, 31),
                        );
                        if (picked != null) {
                          setDlgState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Selected Date',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  '$dateStr ($dayOfWeekName)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.calendar_month,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Is Holiday / School Closed'),
                      subtitle: Text(
                        isHoliday
                            ? 'Students and staff have off on this date.'
                            : 'Special working day override.',
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: isHoliday,
                      onChanged: (val) => setDlgState(() => isHoliday = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) {
                      widget.snack('Please enter a holiday title');
                      return;
                    }
                    Navigator.pop(ctx);
                    try {
                      await widget.api.addSchoolHoliday(
                        holidayDate: dateStr,
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim(),
                        isHoliday: isHoliday,
                      );
                      widget.snack(
                        'Holiday declared successfully!',
                        error: false,
                      );
                      _loadHolidays();
                    } catch (e) {
                      widget.snack('Error creating holiday: $e');
                    }
                  },
                  child: const Text('Save Holiday'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteHoliday(SchoolHoliday h) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Holiday'),
        content: Text(
          'Are you sure you want to remove the holiday "${h.title}" for ${h.holidayDate}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.api.deleteSchoolHoliday(h.id);
        widget.snack('Holiday removed', error: false);
        _loadHolidays();
      } catch (e) {
        widget.snack('Error deleting holiday: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header banner
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.calendar_month,
                      size: 32,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Configure School Days & Holidays',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Set regular weekly school days (e.g. Mon–Sat as school days, Sunday as holiday) and add specific public or regional holiday overrides (e.g. Diwali).',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ─── Section 1: Weekly Working Days ──────────────────────────────────────
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.view_week, color: Colors.indigo),
                          SizedBox(width: 8),
                          Text(
                            'Weekly Working Days Configuration',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        icon: _savingWeekly
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save, size: 18),
                        label: const Text('Save Weekly Schedule'),
                        onPressed: _savingWeekly ? null : _saveWeeklySchedule,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Toggle which days of the week are default school working days vs weekly holidays.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const Divider(height: 24),
                  if (_loadingWeekly)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: List.generate(_weeklySchedules.length, (index) {
                        final item = _weeklySchedules[index];
                        final isSun = item.dayOfWeek == 0;

                        return Container(
                          width: 170,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: item.isWorkingDay
                                ? Colors.green.withValues(alpha: 0.05)
                                : Colors.orange.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: item.isWorkingDay
                                  ? Colors.green.withValues(alpha: 0.3)
                                  : Colors.orange.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.dayName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isSun ? Colors.deepOrange : null,
                                    ),
                                  ),
                                  Switch(
                                    value: item.isWorkingDay,
                                    activeThumbColor: Colors.green,
                                    inactiveThumbColor: Colors.orange,
                                    onChanged: (val) {
                                      setState(() {
                                        _weeklySchedules[index] = item.copyWith(
                                          isWorkingDay: val,
                                        );
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: item.isWorkingDay
                                      ? Colors.green.shade100
                                      : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.isWorkingDay
                                      ? 'School Day'
                                      : 'Holiday (Off)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: item.isWorkingDay
                                        ? Colors.green.shade900
                                        : Colors.orange.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  const SizedBox(height: 12),
                  // Preset hint/scenario helper
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.tune, size: 16),
                        label: const Text(
                          'Preset: Mon–Sat School Days, Sunday Holiday',
                        ),
                        onPressed: () {
                          setState(() {
                            _weeklySchedules = List.generate(7, (d) {
                              final name = const [
                                'Sunday',
                                'Monday',
                                'Tuesday',
                                'Wednesday',
                                'Thursday',
                                'Friday',
                                'Saturday',
                              ][d];
                              return WeeklyDaySchedule(
                                dayOfWeek: d,
                                dayName: name,
                                isWorkingDay: d != 0,
                              );
                            });
                          });
                          widget.snack(
                            'Preset applied! Click "Save Weekly Schedule" to persist.',
                            error: false,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ─── Section 2: Specific Date Holidays & Exception Days ─────────────────
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.beach_access, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            'Specific Date Holidays & Overrides',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.orange,
                            ),
                            label: const Text('Add Diwali Holiday Example'),
                            onPressed: () {
                              // Find upcoming Monday or today
                              final now = DateTime.now();
                              int daysUntilMon =
                                  (DateTime.monday - now.weekday + 7) % 7;
                              if (daysUntilMon == 0) daysUntilMon = 7;
                              final nextMon = now.add(
                                Duration(days: daysUntilMon),
                              );
                              _showAddHolidayDialog(
                                initialDate: nextMon,
                                initialTitle:
                                    'Diwali - Public Holiday in Maharashtra',
                              );
                            },
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Declare Holiday'),
                            onPressed: () => _showAddHolidayDialog(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Declare public holidays, regional holidays, or custom school closed days for specific calendar dates.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const Divider(height: 24),

                  if (_loadingHolidays)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_holidays.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: const [
                          Icon(
                            Icons.event_available,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No specific date holidays configured yet.',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Click "+ Declare Holiday" or use the Diwali example button to declare date-specific holidays.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _holidays.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final h = _holidays[idx];
                        final dt = DateTime.tryParse(h.holidayDate);
                        String dayName = '';
                        if (dt != null) {
                          dayName = const [
                            'Sunday',
                            'Monday',
                            'Tuesday',
                            'Wednesday',
                            'Thursday',
                            'Friday',
                            'Saturday',
                          ][dt.weekday % 7];
                        }

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: h.isHoliday
                                  ? Colors.orange.withValues(alpha: 0.1)
                                  : Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              h.isHoliday ? Icons.beach_access : Icons.work,
                              color: h.isHoliday ? Colors.orange : Colors.blue,
                            ),
                          ),
                          title: Text(
                            h.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Date: ${h.holidayDate} (${dayName.isNotEmpty ? dayName : 'Holiday'})'
                            '${h.description != null && h.description!.isNotEmpty ? '\n${h.description}' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: h.isHoliday
                                      ? Colors.orange.shade100
                                      : Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  h.isHoliday ? 'Holiday (Off)' : 'Working Day',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: h.isHoliday
                                        ? Colors.orange.shade900
                                        : Colors.blue.shade900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                tooltip: 'Remove Holiday',
                                onPressed: () => _deleteHoliday(h),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

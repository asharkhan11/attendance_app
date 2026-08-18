import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as rp;
import '../providers/auth_provider.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../utils/app_logger.dart';
import '../services/download_helper.dart';
import '../widgets/profile_modal.dart';
import 'mark_attendance_screen.dart';

import '../design_system/app_breakpoints.dart';
import '../design_system/app_spacing.dart';
import '../design_system/attendance_theme.dart';
import '../features/teacher/domain/entities/student_monthly_row.dart';
import '../features/teacher/presentation/screens/student_profile_screen.dart';
import '../features/teacher/presentation/widgets/defaulter_card.dart';
import '../features/teacher/presentation/widgets/monthly_grid_student_card.dart';
import '../features/teacher/presentation/widgets/period_selector.dart';
import '../features/teacher/presentation/widgets/teacher_dashboard_skeleton.dart';
import '../features/teacher/presentation/widgets/teacher_navigation.dart';
import '../providers/app_providers.dart';
import '../shared/domain/entities/defaulter_entry.dart';
import '../shared/domain/entities/kpi_metric.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  int _navIndex = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Navigation & Session State
  AttendanceSession? _activeMarkingSession;

  // Grid Selection Highlights (Desktop Matrix view only)
  int? _selectedColumnDay;
  String? _selectedRowStudentId;

  // State selection
  DateTime _selectedDate = DateTime.now();
  int _selectedPeriod = 1;
  SchoolClass? _selectedClass;
  List<SchoolClass> _availableClasses = [];
  bool _isLoadingClasses = true;

  // Diagnostics & Error state
  String? _errorMsg;
  String? _sessionDiagnosticError;
  bool _isStartingSession = false;

  // Analytics & Data
  ClassSummary? _summary;
  List<Defaulter> _defaulters = [];
  List<Student> _rosterStudents = [];
  dynamic _monthlyGridData;
  Map<int, AttendanceSession> _dailySessions = {};
  bool _loadingAnalytics = false;

  int? _todayPresent;
  int? _todayAbsent;
  int? _todayLateExcused;

  // Calendar & Holidays
  List<WeeklyDaySchedule> _weeklySchedules = [];
  List<SchoolHoliday> _schoolHolidays = [];

  @override
  void initState() {
    super.initState();
    AppLogger.d(
      'TeacherDashboard',
      'Initializing Enterprise Teacher Dashboard',
    );
    _loadTeacherData();
  }

  Future<void> _loadCalendarData() async {
    try {
      final wRes = await _apiService.getWeeklySchedule();
      if (wRes is List) {
        _weeklySchedules = wRes
            .map((x) => WeeklyDaySchedule.fromJson(x as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      AppLogger.w('TeacherDashboard', 'Could not load weekly schedule: $e');
    }

    try {
      final hRes = await _apiService.getSchoolHolidays();
      if (hRes is List) {
        _schoolHolidays = hRes
            .map((x) => SchoolHoliday.fromJson(x as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      AppLogger.w('TeacherDashboard', 'Could not load holidays: $e');
    }
  }

  (bool, String) _getHolidayInfoForDate(DateTime date) {
    final dateStr =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    // 1. Check date-specific holidays
    final match = _schoolHolidays
        .where((h) => h.holidayDate == dateStr)
        .firstOrNull;
    if (match != null) {
      if (match.isHoliday) {
        return (true, match.title);
      } else {
        return (false, ''); // Special working day override
      }
    }

    // 2. Check weekly schedule
    final dayOfWeek = date.weekday % 7; // 0=Sun, 1=Mon, ..., 6=Sat
    final wDay = _weeklySchedules
        .where((w) => w.dayOfWeek == dayOfWeek)
        .firstOrNull;
    if (wDay != null && !wDay.isWorkingDay) {
      return (true, "${wDay.dayName} is a weekly holiday (off)");
    } else if (wDay == null && dayOfWeek == 0) {
      return (true, "Sunday is a weekly holiday (off)");
    }

    return (false, '');
  }

  Future<void> _loadTeacherData() async {
    setState(() {
      _isLoadingClasses = true;
      _errorMsg = null;
      _sessionDiagnosticError = null;
    });

    try {
      await _loadCalendarData();

      // 1. Try loading primary assigned class
      try {
        final res = await _apiService.getMyClass();
        if (res != null) {
          _selectedClass = SchoolClass.fromJson(res);
          AppLogger.i(
            'TeacherDashboard',
            'Assigned class loaded: ${_selectedClass?.displayName}',
          );
        }
      } catch (e) {
        AppLogger.w(
          'TeacherDashboard',
          'No single assigned class found via getMyClass: $e',
        );
      }

      // 2. Fetch all available classes for multi-class teaching support
      try {
        final page = await _apiService.listClasses(pageSize: 100);
        if (mounted) {
          final classList = page.data
              .map((x) => SchoolClass.fromJson(x))
              .toList();
          setState(() {
            _availableClasses = classList;
            if (_selectedClass == null && _availableClasses.isNotEmpty) {
              _selectedClass = _availableClasses.first;
            }
          });
        }
      } on ApiException catch (e) {
        if (e.statusCode == 403) {
          AppLogger.i(
            'TeacherDashboard',
            'Teacher has assigned class scope only (403 on listClasses).',
          );
          if (_selectedClass != null) {
            setState(() {
              _availableClasses = [_selectedClass!];
            });
          }
        } else {
          rethrow;
        }
      } catch (e) {
        AppLogger.w('TeacherDashboard', 'Could not list extra classes: $e');
        if (_selectedClass != null) {
          setState(() {
            _availableClasses = [_selectedClass!];
          });
        }
      }

      if (_selectedClass != null) {
        await _loadClassDataAndAnalytics();
      } else {
        setState(() {
          _errorMsg =
              'No class assigned to your teacher account. Please contact your administrator to assign a class.';
        });
      }
    } catch (e, stack) {
      AppLogger.e(
        'TeacherDashboard',
        'Error loading teacher dashboard data',
        error: e,
        stackTrace: stack,
      );
      if (mounted) {
        setState(() {
          _errorMsg = 'Failed to load teacher dashboard: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingClasses = false);
    }
  }

  Future<void> _loadClassDataAndAnalytics() async {
    if (_selectedClass == null) return;
    
    final requestDate = _selectedDate;
    final requestPeriod = _selectedPeriod;
    final requestClass = _selectedClass!;

    setState(() {
      _loadingAnalytics = true;
      _sessionDiagnosticError = null;
      _activeMarkingSession = null;
      _todayPresent = null;
      _todayAbsent = null;
      _todayLateExcused = null;
    });

    final now = requestDate;
    final from = "${now.year}-${now.month.toString().padLeft(2, '0')}-01";
    final to =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    try {
      // 1. Fetch Class Summary
      try {
        final summaryData = await _apiService.getClassSummary(
          requestClass.id,
          from: from,
          to: to,
        );
        if (summaryData != null &&
            mounted &&
            _selectedDate == requestDate &&
            _selectedPeriod == requestPeriod &&
            _selectedClass?.id == requestClass.id) {
          final sMap = summaryData is Map
              ? (summaryData['data'] ?? summaryData)
              : summaryData;
          setState(() {
            _summary = ClassSummary.fromJson(sMap);
          });
        }
      } catch (e) {
        AppLogger.w('TeacherDashboard', 'Class summary load warning: $e');
      }

      // 2. Fetch Defaulters List
      try {
        final defaultersData = await _apiService.getClassDefaulters(
          requestClass.id,
          threshold: 75,
          from: from,
          to: to,
        );
        if (defaultersData != null &&
            mounted &&
            _selectedDate == requestDate &&
            _selectedPeriod == requestPeriod &&
            _selectedClass?.id == requestClass.id) {
          final dList = defaultersData is Map
              ? (defaultersData['data'] as List? ?? [])
              : (defaultersData as List? ?? []);
          setState(() {
            _defaulters = dList.map((x) => Defaulter.fromJson(x)).toList();
          });
        }
      } catch (e) {
        AppLogger.w('TeacherDashboard', 'Class defaulters load warning: $e');
      }

      // 3. Fetch Roster Students
      try {
        final rosterPage = await _apiService.getClassRoster(
          requestClass.id,
          pageSize: 100,
        );
        if (mounted &&
            _selectedDate == requestDate &&
            _selectedPeriod == requestPeriod &&
            _selectedClass?.id == requestClass.id) {
          setState(() {
            _rosterStudents = rosterPage.data
                .map((x) => Student.fromJson(x))
                .toList();
          });
        }
      } catch (e) {
        AppLogger.w('TeacherDashboard', 'Class roster load warning: $e');
      }

      // 4. Fetch Monthly Grid Sheet
      try {
        final gridRes = await _apiService.getMonthlyMatrix(
          requestClass.id,
          year: now.year,
          month: now.month,
        );
        if (mounted &&
            gridRes != null &&
            _selectedDate == requestDate &&
            _selectedPeriod == requestPeriod &&
            _selectedClass?.id == requestClass.id) {
          setState(() {
            _monthlyGridData = gridRes is Map
                ? (gridRes['data'] ?? gridRes)
                : gridRes;
          });
        }
      } catch (_) {}

      // 5. Fetch Today's Sessions & Roster Marks for Dynamic Cards
      try {
        final selectedDateStr =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        final sessionsPage = await _apiService.listSessions(
          classId: requestClass.id,
          from: selectedDateStr,
          to: selectedDateStr,
          pageSize: 100,
        );
        if (mounted &&
            _selectedDate == requestDate &&
            _selectedPeriod == requestPeriod &&
            _selectedClass?.id == requestClass.id) {
          final sessionMap = <int, AttendanceSession>{};
          for (final raw in sessionsPage.data) {
            final sess = AttendanceSession.fromJson(raw);
            sessionMap[sess.periodNumber] = sess;
          }
          setState(() {
            _dailySessions = sessionMap;
          });

          // Fetch session roster marks if session exists for selected date and period
          if (_dailySessions.containsKey(requestPeriod)) {
            final sess = _dailySessions[requestPeriod]!;
            setState(() {
              _activeMarkingSession = sess;
            });
            try {
              final sessDetail = await _apiService.getAttendanceSession(
                sess.id,
              );
              if (mounted &&
                  sessDetail != null &&
                  _selectedDate == requestDate &&
                  _selectedPeriod == requestPeriod &&
                  _selectedClass?.id == requestClass.id) {
                final rosterData = sessDetail is Map
                    ? sessDetail['roster']
                    : null;
                if (rosterData is List) {
                  int pCount = 0;
                  int aCount = 0;
                  int leCount = 0;
                  for (final item in rosterData) {
                    final st = item['status'];
                    if (st == 'present') {
                      pCount++;
                    } else if (st == 'absent') {
                      aCount++;
                    } else if (st == 'late' || st == 'excused') {
                      leCount++;
                    }
                  }
                  setState(() {
                    _todayPresent = pCount;
                    _todayAbsent = aCount;
                    _todayLateExcused = leCount;
                  });
                }
              }
            } catch (e) {
              AppLogger.w(
                'TeacherDashboard',
                'Session roster details load warning: $e',
              );
            }
          } else {
            setState(() {
              _activeMarkingSession = null;
              _todayPresent = null;
              _todayAbsent = null;
              _todayLateExcused = null;
            });
          }
        }
      } catch (e) {
        AppLogger.w('TeacherDashboard', 'Daily sessions list load warning: $e');
      }
    } finally {
      if (mounted &&
          _selectedDate == requestDate &&
          _selectedPeriod == requestPeriod &&
          _selectedClass?.id == requestClass.id) {
        setState(() => _loadingAnalytics = false);

        // Auto-start session if we are on the Mark tab and no active session exists
        if (_navIndex == 1 &&
            _activeMarkingSession == null &&
            !_isStartingSession &&
            _sessionDiagnosticError == null) {
          Future.microtask(() => _startSession());
        }
      }
    }
  }

  Future<void> _exportClassCSV() async {
    if (_selectedClass == null) return;
    try {
      final file = await _apiService.exportClassReport(
        _selectedClass!.id,
        format: 'csv',
      );
      triggerDownload(
        file.bytes,
        file.fileName ?? '${_selectedClass!.displayName}_attendance.csv',
        file.contentType ?? 'text/csv',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Downloaded attendance CSV for ${_selectedClass!.displayName}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export CSV: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _startSession() async {
    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a class first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isStartingSession || _activeMarkingSession != null) {
      return;
    }

    final formattedDate =
        "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    setState(() {
      _isStartingSession = true;
      _sessionDiagnosticError = null;
    });

    AppLogger.i(
      'TeacherDashboard',
      'Starting daily attendance session for ${_selectedClass!.displayName}, Date: $formattedDate',
    );

    try {
      final res = await _apiService.createAttendanceSession({
        'class_id': _selectedClass!.id,
        'session_date': formattedDate,
        'period_number': _selectedPeriod,
      });

      if (res != null && mounted) {
        final sessionData = res is Map && res['data'] != null
            ? res['data']
            : res;
        final session = AttendanceSession.fromJson(sessionData);

        AppLogger.i(
          'TeacherDashboard',
          'Daily attendance session opened successfully (ID: ${session.id})',
        );

        setState(() {
          _activeMarkingSession = session;
          _navIndex = 1;
        });
        _loadClassDataAndAnalytics();
      }
    } on ApiException catch (e) {
      AppLogger.e(
        'TeacherDashboard',
        'API error on session creation: ${e.code} (${e.statusCode}) - ${e.message}',
      );
      if (mounted) {
        setState(() {
          if (e.statusCode == 500) {
            _sessionDiagnosticError =
                'Server Error (500): The backend failed to initialize the attendance session for ${_selectedClass!.displayName}.\n\n'
                'Troubleshooting Checklist:\n'
                '• Ensure an Academic Session/Year is created and marked as "Current" in the Admin Dashboard.\n'
                '• Confirm your teacher account is assigned to this class.';
          } else {
            _sessionDiagnosticError =
                'Failed to open session (${e.statusCode}): ${e.message}';
          }
        });
      }
    } catch (e, stack) {
      AppLogger.e(
        'TeacherDashboard',
        'Unexpected exception on session creation',
        error: e,
        stackTrace: stack,
      );
      if (mounted) {
        setState(() {
          _sessionDiagnosticError =
              'Server Connection Error (500 / Exception): ${e.toString().replaceAll('Exception: ', '')}\n\n'
              'Check backend server status at ${ApiService.baseUrl} and ensure an Academic Session is active in Admin Dashboard.';
        });
      }
    } finally {
      if (mounted) setState(() => _isStartingSession = false);
    }
  }

  void _showStudentProfileModal(
    Student student, {
    Map<String, dynamic>? gridStudentData,
  }) {
    double pct = 100.0;
    int totP = 0;
    int totA = 0;
    int totL = 0;
    int totE = 0;
    int totalSessions = 0;
    bool hasSessionData = false;

    // 1. Check passed grid data or search _monthlyGridData
    Map? stData = gridStudentData;
    if (stData == null && _monthlyGridData is Map) {
      final stList = (_monthlyGridData['students'] as List?) ?? [];
      stData =
          stList.where((x) {
                if (x is! Map) return false;
                final id = (x['student_id'] ?? x['id'])?.toString();
                final roll = x['roll_number']?.toString();
                return id == student.id ||
                    (roll != null && roll == student.rollNumber);
              }).firstOrNull
              as Map?;
    }

    if (stData != null) {
      totP = (stData['total_present'] as num?)?.toInt() ?? 0;
      totA = (stData['total_absent'] as num?)?.toInt() ?? 0;
      totL = (stData['total_late'] as num?)?.toInt() ?? 0;
      totE = (stData['total_excused'] as num?)?.toInt() ?? 0;
      totalSessions = totP + totA + totL + totE;
      if (totalSessions > 0) {
        hasSessionData = true;
        pct = ((totP + totL + totE) / totalSessions) * 100.0;
      }
    }

    if (!hasSessionData) {
      final def = _defaulters
          .where((d) => d.studentId == student.id)
          .firstOrNull;
      if (def != null) {
        pct = def.attendancePercentage;
        totP = def.present;
        totA = def.absent;
        totalSessions = def.totalSessions;
        hasSessionData = true;
      }
    }

    StudentProfileScreen.show(
      context,
      student: student,
      className: _selectedClass?.displayName ?? '',
      attendancePct: pct,
      totalPresent: totP,
      totalAbsent: totA,
      totalLate: totL,
      totalExcused: totE,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final isWide = !context.isMobile;
    final attendanceTheme = Theme.of(context).extension<AttendanceTheme>();

    Widget bodyContent;
    if (_navIndex == 1) {
      // Index 1: Mark Attendance Workstation
      if (_activeMarkingSession != null && _selectedClass != null) {
        bodyContent = MarkAttendanceScreen(
          key: ValueKey(
            'mark_session_${_activeMarkingSession!.id}_${_activeMarkingSession!.sessionDate}',
          ),
          session: _activeMarkingSession!,
          schoolClass: _selectedClass!,
          onSessionUpdated: _loadClassDataAndAnalytics,
        );
      } else if (_isStartingSession || _loadingAnalytics || _isLoadingClasses) {
        bodyContent = const Center(child: CircularProgressIndicator());
      } else if (_sessionDiagnosticError != null) {
        bodyContent = Center(
          child: Card(
            elevation: 1,
            color: Colors.red.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.red.shade200),
            ),
            margin: const EdgeInsets.all(AppSpacing.lg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade800,
                    size: 48,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Failed to Open Attendance Session',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.red.shade900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _sessionDiagnosticError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry Opening Session'),
                    onPressed: () {
                      setState(() {
                        _sessionDiagnosticError = null;
                      });
                      _startSession();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (_selectedClass == null) {
        bodyContent = const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'No class assigned to your teacher account.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else {
        bodyContent = const Center(child: CircularProgressIndicator());
      }
    } else if (_navIndex == 2) {
      // Index 2: Monthly Register Grid View
      bodyContent = _monthlyGridData != null
          ? _buildMonthlyRegisterGridSection(context)
          : const Center(
              child: Text('No monthly attendance register data loaded'),
            );
    } else if (_navIndex == 3) {
      // Index 3: Defaulters Roster View (< 75%)
      bodyContent = _defaulters.isNotEmpty
          ? SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: _buildDefaultersSection(context),
            )
          : Center(
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.green.shade600,
                        size: 48,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'No Attendance Defaulters',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'All students in ${_selectedClass?.displayName ?? "this class"} meet the mandatory 75% attendance threshold.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
    } else {
      // Index 0: Workstation Overview
      bodyContent = _monthlyGridData != null
          ? _buildMonthlyRegisterGridSection(context)
          : (_defaulters.isNotEmpty
                ? SingleChildScrollView(child: _buildDefaultersSection(context))
                : const SizedBox.shrink());
    }

    final Widget dashboardBody = _isLoadingClasses
        ? const SafeArea(child: TeacherDashboardSkeleton())
        : SafeArea(
            child: Column(
              children: [
                // Fixed Top AppBar
                AppBar(
                  title: Text(
                    isWide
                        ? 'Teacher Portal & Attendance Workstation'
                        : 'Teacher Portal',
                  ),
                  elevation: 1,
                  actions: [
                    if (_selectedClass != null)
                      IconButton(
                        icon: const Icon(Icons.download_rounded),
                        tooltip: 'Export Class Attendance (CSV)',
                        onPressed: _exportClassCSV,
                      ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadTeacherData,
                      tooltip: 'Refresh Dashboard',
                    ),
                    if (!isWide)
                      rp.Consumer(
                        builder: (context, ref, _) {
                          final isDark =
                              ref.watch(themeProvider) == ThemeMode.dark;
                          final user = Provider.of<AuthProvider>(
                            context,
                          ).currentUser;
                          final initial = user?.fullName.isNotEmpty == true
                              ? user!.fullName[0].toUpperCase()
                              : 'U';

                          return PopupMenuButton<String>(
                            offset: const Offset(0, 48),
                            icon: CircleAvatar(
                              radius: 16,
                              backgroundColor: Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.2),
                              child: Text(
                                initial,
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            onSelected: (value) {
                              if (value == 'profile') {
                                ProfileModal.show(
                                  context,
                                  onProfileUpdated: _loadTeacherData,
                                );
                              } else if (value == 'theme') {
                                ref.read(themeProvider.notifier).toggle();
                              } else if (value == 'logout') {
                                Provider.of<AuthProvider>(
                                  context,
                                  listen: false,
                                ).logout();
                              }
                            },
                            itemBuilder: (BuildContext context) =>
                                <PopupMenuEntry<String>>[
                                  PopupMenuItem<String>(
                                    value: 'profile',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.person_outline,
                                          color: Theme.of(
                                            context,
                                          ).iconTheme.color,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text('Profile Settings'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'theme',
                                    child: Row(
                                      children: [
                                        Icon(
                                          isDark
                                              ? Icons.light_mode_outlined
                                              : Icons.dark_mode_outlined,
                                          color: Theme.of(
                                            context,
                                          ).iconTheme.color,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isDark ? 'Light Mode' : 'Dark Mode',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                  PopupMenuItem<String>(
                                    value: 'logout',
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.logout,
                                          color: Colors.redAccent,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Logout',
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                          );
                        },
                      ),
                  ],
                ),

                // Fixed Control Toolbar & Micro Stat Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSingleControlToolbar(isWide),
                      const SizedBox(height: AppSpacing.xs),

                      if (_sessionDiagnosticError != null) ...[
                        _buildDiagnosticErrorCard(),
                        const SizedBox(height: AppSpacing.xs),
                      ],

                      if (_errorMsg != null) ...[
                        Card(
                          color: Colors.orange.shade50,
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange.shade800,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    _errorMsg!,
                                    style: TextStyle(
                                      color: Colors.orange.shade900,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],

                      if (_summary != null && _navIndex != 1) ...[
                        _buildMicroStatBar(attendanceTheme),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                    ],
                  ),
                ),

                // Dynamic Body Content based on Navigation Selection
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: bodyContent,
                  ),
                ),
              ],
            ),
          );

    return TeacherNavigation(
      selectedIndex: _navIndex,
      userFullName: user?.fullName,
      onProfileTap: () =>
          ProfileModal.show(context, onProfileUpdated: _loadTeacherData),
      onRefreshTap: _loadTeacherData,
      onLogoutTap: () =>
          Provider.of<AuthProvider>(context, listen: false).logout(),
      onDestinationSelected: (idx) {
        setState(() => _navIndex = idx);
        if (idx == 1 &&
            _activeMarkingSession == null &&
            _selectedClass != null &&
            !_isStartingSession) {
          _startSession();
        }
      },
      body: dashboardBody,
    );
  }

  List<KpiMetric> _buildKpiMetricList(AttendanceTheme? theme) {
    final s = _summary!;
    final totalStr = _rosterStudents.isEmpty ? 1 : _rosterStudents.length;
    final presentPct = _todayPresent != null
        ? ((_todayPresent! / totalStr) * 100).toStringAsFixed(0)
        : '0';

    return [
      KpiMetric(
        title: 'Attendance Rate',
        value: '${s.attendancePercentage.toStringAsFixed(1)}%',
        subtitle: 'Monthly Avg',
        icon: Icons.show_chart,
        color: s.attendancePercentage >= 85
            ? (theme?.present ?? Colors.green.shade700)
            : (s.attendancePercentage >= 75
                  ? (theme?.late ?? Colors.orange.shade800)
                  : (theme?.absent ?? Colors.red.shade700)),
      ),
      KpiMetric(
        title: 'Enrolled Students',
        value: '${_rosterStudents.length}',
        subtitle: 'Class Strength',
        icon: Icons.groups,
        color: Colors.blue.shade700,
      ),
      KpiMetric(
        title: 'Present Today',
        value: _todayPresent != null ? '$_todayPresent' : '--',
        subtitle: _todayPresent != null ? '$presentPct% present' : 'Not marked',
        icon: Icons.check_circle_outline,
        color: _todayPresent != null
            ? (theme?.present ?? Colors.green.shade700)
            : Colors.grey.shade600,
      ),
      KpiMetric(
        title: 'Absent Today',
        value: _todayAbsent != null ? '$_todayAbsent' : '--',
        subtitle: _todayAbsent != null
            ? '$_todayAbsent student${_todayAbsent == 1 ? '' : 's'}'
            : 'Not marked',
        icon: Icons.cancel_outlined,
        color: _todayAbsent != null && _todayAbsent! > 0
            ? (theme?.absent ?? Colors.red.shade700)
            : Colors.grey.shade600,
      ),
      KpiMetric(
        title: 'Late / Excused',
        value: _todayLateExcused != null ? '$_todayLateExcused' : '--',
        subtitle: _todayLateExcused != null ? 'Special status' : 'Not marked',
        icon: Icons.access_time_outlined,
        color: _todayLateExcused != null && _todayLateExcused! > 0
            ? (theme?.late ?? Colors.orange.shade800)
            : Colors.grey.shade600,
      ),
      KpiMetric(
        title: 'Defaulters (<75%)',
        value: '${_defaulters.length}',
        subtitle: _defaulters.isNotEmpty ? 'Action Needed' : 'All Clear',
        icon: Icons.warning_amber_rounded,
        color: _defaulters.isNotEmpty
            ? (theme?.absent ?? Colors.red.shade700)
            : (theme?.present ?? Colors.green.shade700),
      ),
    ];
  }

  Future<void> _reopenSession(String sessionId) async {
    try {
      await _apiService.reopenAttendanceSession(sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session unlocked! You can now edit attendance.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadClassDataAndAnalytics();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unlock session: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildSingleControlToolbar(bool isWide) {
    final dailySession = _dailySessions[_selectedPeriod];
    final isClosed = dailySession?.status == 'closed';
    final isOpen = dailySession?.status == 'open';
    final (isHoliday, holidayReason) = _getHolidayInfoForDate(_selectedDate);

    Color statusColor = Colors.green.shade700;
    String statusLabel = 'Session Active (Open)';
    IconData statusIcon = Icons.check_circle_outline;
    String buttonText = 'CONTINUE / EDIT ATTENDANCE';

    if (isHoliday && !isOpen && !isClosed) {
      statusColor = Colors.orange.shade800;
      statusLabel = 'Holiday ($holidayReason)';
      statusIcon = Icons.beach_access;
      buttonText = 'OVERRIDE & START';
    } else if (isClosed) {
      statusColor = Colors.amber.shade900;
      statusLabel = 'Finalized (Locked)';
      statusIcon = Icons.lock;
      buttonText = 'VIEW RECORD';
    } else if (!isOpen) {
      statusColor = Colors.blue.shade700;
      statusLabel = 'Not Started';
      statusIcon = Icons.edit_calendar;
      buttonText = 'START ATTENDANCE';
    }

    final dateFormatted =
        "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    // Mobile layout: No horizontal scrolling! Native stacked responsive controls
    if (!isWide) {
      return Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Class Name & Date Picker Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.class_,
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _selectedClass?.displayName ?? 'No Class Assigned',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.calendar_today, size: 14),
                      label: Text(
                        dateFormatted,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                          });
                          await _loadClassDataAndAnalytics();
                        }
                      },
                    ),
                  ),
                ],
              ),

              if (_navIndex != 1) ...[
                const SizedBox(height: 10),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final colWidth = (constraints.maxWidth - 16) / 3;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        // Column 1: Session Status & Unlock action
                        SizedBox(
                          width: colWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'STATUS',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    statusIcon,
                                    size: 13,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: statusColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (isClosed && dailySession != null) ...[
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () => _reopenSession(dailySession.id),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.lock_open,
                                        size: 12,
                                        color: Colors.blue,
                                      ),
                                      SizedBox(width: 2),
                                      Text(
                                        'Unlock',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Column 2: Stats
                        SizedBox(
                          width: colWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'STATS',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rate: ${_summary != null ? "${_summary!.attendancePercentage.toStringAsFixed(1)}%" : "--"}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Total: ${_rosterStudents.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Column 3: Present Count & CTA Action
                        SizedBox(
                          width: colWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TODAY',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Present: ${_todayPresent ?? "--"}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _navIndex = 1;
                                  });
                                  if (_activeMarkingSession == null &&
                                      !_isStartingSession) {
                                    _startSession();
                                  }
                                },
                                child: Text(
                                  isClosed ? 'View Record' : 'Mark Attendance',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Desktop wide layout
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // 1. Search Student Field (Height 40px)
              if (_navIndex != 1) ...[
                SizedBox(
                  width: 170,
                  height: 40,
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search student...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    onChanged: (val) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Read-only Class Label (Height 40px)
              if (_selectedClass != null) ...[
                Container(
                  height: 40,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.class_,
                        color: Theme.of(context).primaryColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selectedClass!.displayName,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // 3. Date Picker Button (Height 40px)
              SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_today, size: 14),
                  label: Text(
                    dateFormatted,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                        _selectedColumnDay = picked.day;
                      });
                      await _loadClassDataAndAnalytics();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Period Selector
              PeriodSelector(
                selectedPeriod: _selectedPeriod,
                onPeriodChanged: (p) {
                  setState(() => _selectedPeriod = p);
                  _loadClassDataAndAnalytics();
                },
              ),
              const SizedBox(width: 8),

              // 4. Session Status Chip (Height 40px)
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // 5. Action CTA Button & Unlock Icon
              if (isClosed && dailySession != null) ...[
                IconButton(
                  icon: const Icon(Icons.lock_open, size: 16),
                  tooltip: 'Unlock Session',
                  onPressed: () => _reopenSession(dailySession.id),
                ),
                const SizedBox(width: 4),
              ],
              SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: _isStartingSession
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          isClosed ? Icons.lock : Icons.how_to_reg,
                          size: 15,
                        ),
                  label: Text(
                    buttonText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  onPressed: _isStartingSession ? null : () => _startSession(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosticErrorCard() {
    if (_sessionDiagnosticError == null) return const SizedBox.shrink();

    return Card(
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.red.shade200),
      ),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade800, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _sessionDiagnosticError!,
                style: TextStyle(
                  color: Colors.red.shade900,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: Colors.red.shade800),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Dismiss',
              onPressed: () {
                setState(() {
                  _sessionDiagnosticError = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicroStatBar(AttendanceTheme? theme) {
    if (context.isMobile) {
      return const SizedBox.shrink();
    }
    final metrics = _buildKpiMetricList(theme);

    final chipList = metrics.map((m) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: m.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: m.color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(m.icon, size: 14, color: m.color),
            const SizedBox(width: 6),
            Text(
              m.title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              m.value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: m.color,
              ),
            ),
          ],
        ),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Wrap(spacing: 8, runSpacing: 6, children: chipList),
    );
  }

  Widget _buildMonthlyRegisterGridSection(BuildContext context) {
    if (_monthlyGridData is! Map) return const SizedBox();
    final data = _monthlyGridData as Map;
    final rawStudents = (data['students'] as List?) ?? [];
    final searchQuery = _searchCtrl.text.trim().toLowerCase();
    final students = rawStudents.where((st) {
      if (searchQuery.isEmpty) return true;
      if (st is! Map) return false;
      final name = (st['full_name'] ?? st['name'] ?? '')
          .toString()
          .toLowerCase();
      final roll = (st['roll_number'] ?? '').toString().toLowerCase();
      final adm = (st['admission_number'] ?? '').toString().toLowerCase();
      return name.contains(searchQuery) ||
          roll.contains(searchQuery) ||
          adm.contains(searchQuery);
    }).toList();
    final daysInMonth = (data['days_in_month'] as num?)?.toInt() ?? 30;
    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final monthName = monthNames[(_selectedDate.month - 1).clamp(0, 11)];
    final isMobile = context.isMobile;
    final isWide = !isMobile;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.grid_on, color: Colors.blue, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      isMobile
                          ? 'Monthly Register'
                          : 'Monthly Attendance Register',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    '$monthName ${_selectedDate.year}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Legend Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _gridLegendItem('P', 'Present', Colors.green),
                  const SizedBox(width: 8),
                  _gridLegendItem('A', 'Absent', Colors.red),
                  const SizedBox(width: 8),
                  _gridLegendItem('L', 'Late', Colors.orange),
                  const SizedBox(width: 8),
                  _gridLegendItem('E', 'Excused', Colors.blue),
                  const SizedBox(width: 8),
                  _gridLegendItem('-', 'No Session', Colors.grey),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Responsive view branching: Mobile Cards vs Desktop DataTable
            if (isMobile)
              Expanded(
                child: ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (ctx, i) {
                    final st = students[i];
                    final roll = (st['roll_number'] ?? '').toString();
                    final name = (st['full_name'] ?? '').toString();
                    final stId = (st['student_id'] ?? st['id'] ?? '')
                        .toString();
                    final dailyMap = Map<String, String>.from(
                      (st['daily_status'] as Map?) ??
                          (st['daily'] as Map?) ??
                          {},
                    );

                    final monthlyRow = StudentMonthlyRow(
                      studentId: stId,
                      fullName: name,
                      rollNumber: roll,
                      admissionNumber: (st['admission_number'] ?? 'N/A')
                          .toString(),
                      dailyStatus: dailyMap,
                      totalPresent: (st['total_present'] as num?)?.toInt() ?? 0,
                      totalAbsent: (st['total_absent'] as num?)?.toInt() ?? 0,
                      totalLate: (st['total_late'] as num?)?.toInt() ?? 0,
                      totalExcused: (st['total_excused'] as num?)?.toInt() ?? 0,
                    );

                    final studentMatch =
                        _rosterStudents
                            .where((s) => s.id == stId || s.rollNumber == roll)
                            .firstOrNull ??
                        Student(
                          id: stId,
                          schoolId: '',
                          classId: _selectedClass?.id ?? '',
                          admissionNumber: (st['admission_number'] ?? 'N/A')
                              .toString(),
                          rollNumber: roll,
                          fullName: name,
                          gender: 'other',
                          isActive: true,
                          createdAt: DateTime.now().toIso8601String(),
                        );

                    return MonthlyGridStudentCard(
                      student: monthlyRow,
                      daysInMonth: daysInMonth,
                      selectedDate: _selectedDate,
                      onTap: () => _showStudentProfileModal(
                        studentMatch,
                        gridStudentData: st is Map<String, dynamic>
                            ? st
                            : Map<String, dynamic>.from(st as Map),
                      ),
                    );
                  },
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. PINNED / FIXED DATE HEADER BAR
                      Container(
                        color: Theme.of(context).cardColor,
                        child: DataTable(
                          showCheckboxColumn: false,
                          columnSpacing: 8,
                          headingRowHeight: 36,
                          dataRowMinHeight: 0,
                          dataRowMaxHeight: 0,
                          columns: [
                            const DataColumn(
                              label: SizedBox(
                                width: 30,
                                child: Text(
                                  'Roll',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const DataColumn(
                              label: SizedBox(
                                width: 140,
                                child: Text(
                                  'Student Name',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            ...List.generate(daysInMonth, (i) {
                              final dayNum = i + 1;
                              final isColSelected =
                                  isWide && (_selectedColumnDay == dayNum);
                              final primaryColor = Theme.of(
                                context,
                              ).primaryColor;

                              return DataColumn(
                                label: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedColumnDay =
                                          (_selectedColumnDay == dayNum)
                                          ? null
                                          : dayNum;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    alignment: Alignment.center,
                                    width: 22,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    decoration: isColSelected
                                        ? BoxDecoration(
                                            color: primaryColor.withValues(
                                              alpha: 0.25,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: primaryColor,
                                              width: 1.5,
                                            ),
                                          )
                                        : null,
                                    child: Text(
                                      '$dayNum',
                                      style: TextStyle(
                                        fontSize: isColSelected ? 11 : 10,
                                        fontWeight: FontWeight.bold,
                                        color: isColSelected
                                            ? primaryColor
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                            const DataColumn(
                              label: SizedBox(
                                width: 36,
                                child: Text(
                                  'Tot P',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ),
                            const DataColumn(
                              label: SizedBox(
                                width: 36,
                                child: Text(
                                  'Tot A',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          rows: const [],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1),

                      // 2. SCROLLABLE STUDENT ROWS (ONLY vertical scrolling here!)
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            showCheckboxColumn: false,
                            columnSpacing: 8,
                            headingRowHeight: 0,
                            dataRowMinHeight: 36,
                            dataRowMaxHeight: 36,
                            columns: [
                              const DataColumn(label: SizedBox(width: 30)),
                              const DataColumn(label: SizedBox(width: 140)),
                              ...List.generate(
                                daysInMonth,
                                (i) => const DataColumn(
                                  label: SizedBox(width: 22),
                                ),
                              ),
                              const DataColumn(label: SizedBox(width: 36)),
                              const DataColumn(label: SizedBox(width: 36)),
                            ],
                            rows: students.map<DataRow>((st) {
                              final roll = (st['roll_number'] ?? '').toString();
                              final name = (st['full_name'] ?? '').toString();
                              final stId =
                                  (st['student_id'] ?? st['id'] ?? roll)
                                      .toString();
                              final isRowSelected =
                                  _selectedRowStudentId == stId;
                              final dailyMap =
                                  (st['daily_status'] as Map?) ??
                                  (st['daily'] as Map?) ??
                                  {};
                              final totP = st['total_present'] ?? 0;
                              final totA = st['total_absent'] ?? 0;
                              final primaryColor = Theme.of(
                                context,
                              ).primaryColor;

                              return DataRow(
                                color: WidgetStateProperty.resolveWith<Color?>((
                                  states,
                                ) {
                                  if (isRowSelected) {
                                    return primaryColor.withValues(alpha: 0.08);
                                  }
                                  return null;
                                }),
                                cells: [
                                  DataCell(
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedRowStudentId = isRowSelected
                                              ? null
                                              : stId;
                                        });
                                      },
                                      child: SizedBox(
                                        width: 30,
                                        child: Text(
                                          roll,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: isRowSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isRowSelected
                                                ? primaryColor
                                                : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedRowStudentId = isRowSelected
                                              ? null
                                              : stId;
                                        });
                                      },
                                      child: SizedBox(
                                        width: 140,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isRowSelected
                                                      ? primaryColor
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            IconButton(
                                              icon: Icon(
                                                Icons.info_outline,
                                                size: 13,
                                                color: primaryColor,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () {
                                                final studentMatch =
                                                    _rosterStudents
                                                        .where(
                                                          (s) =>
                                                              s.id == stId ||
                                                              s.rollNumber ==
                                                                  roll,
                                                        )
                                                        .firstOrNull ??
                                                    Student(
                                                      id: stId,
                                                      schoolId: '',
                                                      classId:
                                                          _selectedClass?.id ??
                                                          '',
                                                      admissionNumber:
                                                          (st['admission_number'] ??
                                                                  'N/A')
                                                              .toString(),
                                                      rollNumber: roll,
                                                      fullName: name,
                                                      gender: 'other',
                                                      isActive: true,
                                                      createdAt: DateTime.now()
                                                          .toIso8601String(),
                                                    );
                                                _showStudentProfileModal(
                                                  studentMatch,
                                                  gridStudentData:
                                                      st is Map<String, dynamic>
                                                      ? st
                                                      : Map<
                                                          String,
                                                          dynamic
                                                        >.from(st as Map),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  ...List.generate(daysInMonth, (i) {
                                    final dayNum = i + 1;
                                    final isColSelected =
                                        isWide &&
                                        (_selectedColumnDay == dayNum);
                                    final dStr =
                                        "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}";
                                    final code =
                                        (dailyMap[dStr] ??
                                                dailyMap[dayNum.toString()] ??
                                                '-')
                                            .toString();

                                    Color badgeBg = Colors.grey.shade100;
                                    Color textColor = Colors.grey.shade600;

                                    if (code == 'P') {
                                      badgeBg = Colors.green.shade100;
                                      textColor = Colors.green.shade900;
                                    } else if (code == 'A') {
                                      badgeBg = Colors.red.shade100;
                                      textColor = Colors.red.shade900;
                                    } else if (code == 'L') {
                                      badgeBg = Colors.orange.shade100;
                                      textColor = Colors.orange.shade900;
                                    } else if (code == 'E') {
                                      badgeBg = Colors.blue.shade100;
                                      textColor = Colors.blue.shade900;
                                    }

                                    return DataCell(
                                      Container(
                                        alignment: Alignment.center,
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: badgeBg,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: isColSelected
                                              ? Border.all(
                                                  color: primaryColor,
                                                  width: 2.0,
                                                )
                                              : (isRowSelected
                                                    ? Border.all(
                                                        color: primaryColor
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                        width: 1.0,
                                                      )
                                                    : null),
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
                                    );
                                  }),
                                  DataCell(
                                    SizedBox(
                                      width: 36,
                                      child: Text(
                                        '$totP',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 36,
                                      child: Text(
                                        '$totA',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
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

  Widget _gridLegendItem(String code, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            code,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildDefaultersSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Attendance Defaulters (< 75%)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _defaulters.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
          itemBuilder: (ctx, i) {
            final d = _defaulters[i];
            final studentMatch = _rosterStudents
                .where((s) => s.id == d.studentId)
                .firstOrNull;

            final defaulterEntry = DefaulterEntry(
              studentId: d.studentId,
              fullName: d.fullName,
              rollNumber: d.rollNumber,
              admissionNumber: studentMatch?.admissionNumber ?? 'N/A',
              className: _selectedClass?.displayName ?? '',
              presentCount: d.present,
              totalSessions: d.totalSessions,
              attendancePercentage: d.attendancePercentage,
            );

            return DefaulterCard(
              defaulter: defaulterEntry,
              onTapProfile: studentMatch != null
                  ? () => _showStudentProfileModal(studentMatch)
                  : null,
            );
          },
        ),
      ],
    );
  }
}

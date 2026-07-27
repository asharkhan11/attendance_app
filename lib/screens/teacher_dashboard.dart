import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../utils/app_logger.dart';
import '../widgets/searchable_dropdown.dart';
import '../widgets/profile_modal.dart';
import 'mark_attendance_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final ApiService _apiService = ApiService();

  // State selection
  DateTime _selectedDate = DateTime.now();
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
    AppLogger.d('TeacherDashboard', 'Initializing Enterprise Teacher Dashboard');
    _loadTeacherData();
  }

  Future<void> _loadCalendarData() async {
    try {
      final wRes = await _apiService.getWeeklySchedule();
      if (wRes is List) {
        _weeklySchedules = wRes.map((x) => WeeklyDaySchedule.fromJson(x as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      AppLogger.w('TeacherDashboard', 'Could not load weekly schedule: $e');
    }

    try {
      final hRes = await _apiService.getSchoolHolidays();
      if (hRes is List) {
        _schoolHolidays = hRes.map((x) => SchoolHoliday.fromJson(x as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      AppLogger.w('TeacherDashboard', 'Could not load holidays: $e');
    }
  }

  (bool, String) _getHolidayInfoForDate(DateTime date) {
    final dateStr =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    // 1. Check date-specific holidays
    final match = _schoolHolidays.where((h) => h.holidayDate == dateStr).firstOrNull;
    if (match != null) {
      if (match.isHoliday) {
        return (true, match.title);
      } else {
        return (false, ''); // Special working day override
      }
    }

    // 2. Check weekly schedule
    final dayOfWeek = date.weekday % 7; // 0=Sun, 1=Mon, ..., 6=Sat
    final wDay = _weeklySchedules.where((w) => w.dayOfWeek == dayOfWeek).firstOrNull;
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
          AppLogger.i('TeacherDashboard', 'Assigned class loaded: ${_selectedClass?.displayName}');
        }
      } catch (e) {
        AppLogger.w('TeacherDashboard', 'No single assigned class found via getMyClass: $e');
      }

      // 2. Fetch all available classes for multi-class teaching support
      try {
        final page = await _apiService.listClasses(pageSize: 100);
        if (mounted) {
          final classList = page.data.map((x) => SchoolClass.fromJson(x)).toList();
          setState(() {
            _availableClasses = classList;
            if (_selectedClass == null && _availableClasses.isNotEmpty) {
              _selectedClass = _availableClasses.first;
            }
          });
        }
      } on ApiException catch (e) {
        if (e.statusCode == 403) {
          AppLogger.i('TeacherDashboard', 'Teacher has assigned class scope only (403 on listClasses).');
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
          _errorMsg = 'No class assigned to your teacher account. Please contact your administrator to assign a class.';
        });
      }
    } catch (e, stack) {
      AppLogger.e('TeacherDashboard', 'Error loading teacher dashboard data', error: e, stackTrace: stack);
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
    setState(() => _loadingAnalytics = true);

    final now = _selectedDate;
    final from = "${now.year}-${now.month.toString().padLeft(2, '0')}-01";
    final to = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    try {
      // 1. Fetch Class Summary
      try {
        final summaryData = await _apiService.getClassSummary(_selectedClass!.id, from: from, to: to);
        if (summaryData != null && mounted) {
          final sMap = summaryData is Map ? (summaryData['data'] ?? summaryData) : summaryData;
          _summary = ClassSummary.fromJson(sMap);
        }
      } catch (e) {
        AppLogger.w('TeacherDashboard', 'Class summary load warning: $e');
      }

      // 2. Fetch Defaulters List
      try {
        final defaultersData = await _apiService.getClassDefaulters(_selectedClass!.id, threshold: 75, from: from, to: to);
        if (defaultersData != null && mounted) {
          final dList = defaultersData is Map ? (defaultersData['data'] as List? ?? []) : (defaultersData as List? ?? []);
          _defaulters = dList.map((x) => Defaulter.fromJson(x)).toList();
        }
      } catch (e) {
        AppLogger.w('TeacherDashboard', 'Class defaulters load warning: $e');
      }

      // 3. Fetch Roster Students
      try {
        final rosterPage = await _apiService.getClassRoster(_selectedClass!.id, pageSize: 100);
        if (mounted) {
          _rosterStudents = rosterPage.data.map((x) => Student.fromJson(x)).toList();
        }
      } catch (e) {
        AppLogger.w('TeacherDashboard', 'Class roster load warning: $e');
      }

      // 4. Fetch Monthly Grid Sheet
      try {
        final gridRes = await _apiService.getMonthlyMatrix(_selectedClass!.id, year: now.year, month: now.month);
        if (mounted && gridRes != null) {
          _monthlyGridData = gridRes is Map ? (gridRes['data'] ?? gridRes) : gridRes;
        }
      } catch (_) {}

      // 5. Fetch Today's Sessions & Roster Marks for Dynamic Cards
      try {
        final selectedDateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        final sessionsPage = await _apiService.listSessions(
          classId: _selectedClass!.id,
          from: selectedDateStr,
          to: selectedDateStr,
          pageSize: 100,
        );
        if (mounted) {
          final sessionMap = <int, AttendanceSession>{};
          for (final raw in sessionsPage.data) {
            final sess = AttendanceSession.fromJson(raw);
            sessionMap[sess.periodNumber] = sess;
          }
          _dailySessions = sessionMap;

          // Fetch session roster marks if session exists for selected date
          if (_dailySessions.containsKey(1)) {
            final sess = _dailySessions[1]!;
            try {
              final sessDetail = await _apiService.getAttendanceSession(sess.id);
              if (mounted && sessDetail != null) {
                final rosterData = sessDetail is Map ? sessDetail['roster'] : null;
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
                  _todayPresent = pCount;
                  _todayAbsent = aCount;
                  _todayLateExcused = leCount;
                }
              }
            } catch (e) {
              AppLogger.w('TeacherDashboard', 'Session roster details load warning: $e');
            }
          } else {
            _todayPresent = null;
            _todayAbsent = null;
            _todayLateExcused = null;
          }
        }
      } catch (e) {
        AppLogger.w('TeacherDashboard', 'Daily sessions list load warning: $e');
      }

    } finally {
      if (mounted) setState(() => _loadingAnalytics = false);
    }
  }

  Future<void> _startSession() async {
    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class first'), backgroundColor: Colors.orange),
      );
      return;
    }

    final formattedDate =
        "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    setState(() {
      _isStartingSession = true;
      _sessionDiagnosticError = null;
    });

    AppLogger.i('TeacherDashboard', 'Starting daily attendance session for ${_selectedClass!.displayName}, Date: $formattedDate');

    try {
      final res = await _apiService.createAttendanceSession({
        'class_id': _selectedClass!.id,
        'session_date': formattedDate,
        'period_number': 1,
      });

      if (res != null && mounted) {
        final sessionData = res is Map && res['data'] != null ? res['data'] : res;
        final session = AttendanceSession.fromJson(sessionData);

        AppLogger.i('TeacherDashboard', 'Daily attendance session opened successfully (ID: ${session.id})');

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MarkAttendanceScreen(
              session: session,
              schoolClass: _selectedClass!,
            ),
          ),
        );
        _loadClassDataAndAnalytics();
      }
    } on ApiException catch (e) {
      AppLogger.e('TeacherDashboard', 'API error on session creation: ${e.code} (${e.statusCode}) - ${e.message}');
      if (mounted) {
        setState(() {
          if (e.statusCode == 500) {
            _sessionDiagnosticError =
                'Server Error (500): The backend failed to initialize the attendance session for ${_selectedClass!.displayName}.\n\n'
                'Troubleshooting Checklist:\n'
                '• Ensure an Academic Session/Year is created and marked as "Current" in the Admin Dashboard.\n'
                '• Confirm your teacher account is assigned to this class.';
          } else {
            _sessionDiagnosticError = 'Failed to open session (${e.statusCode}): ${e.message}';
          }
        });
      }
    } catch (e, stack) {
      AppLogger.e('TeacherDashboard', 'Unexpected exception on session creation', error: e, stackTrace: stack);
      if (mounted) {
        setState(() {
          _sessionDiagnosticError =
              'Server Connection Error (500 / Exception): ${e.toString().replaceAll('Exception: ', '')}\n\n'
              'Check backend server status at http://localhost:8080 and ensure an Academic Session is active in Admin Dashboard.';
        });
      }
    } finally {
      if (mounted) setState(() => _isStartingSession = false);
    }
  }

  void _showStudentProfileModal(Student student, {Map<String, dynamic>? gridStudentData}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
          stData = stList.where((x) {
            if (x is! Map) return false;
            final id = (x['student_id'] ?? x['id'])?.toString();
            final roll = x['roll_number']?.toString();
            return id == student.id || (roll != null && roll == student.rollNumber);
          }).firstOrNull as Map?;
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

        // 2. Fallback to defaulters list if no grid data found
        if (!hasSessionData) {
          final def = _defaulters.where((d) => d.studentId == student.id).firstOrNull;
          if (def != null) {
            pct = def.attendancePercentage;
            totP = def.present;
            totA = def.absent;
            totalSessions = def.totalSessions;
            hasSessionData = true;
          }
        }

        final formattedDob = student.dob != null && student.dob!.isNotEmpty
            ? student.dob!.split('T')[0]
            : 'N/A';

        final rateDisplay = hasSessionData
            ? '${pct.toStringAsFixed(1)}% ($totP/$totalSessions sessions marked)'
            : '100.0% (No sessions marked)';

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : 'S',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('Roll No: ${student.rollNumber} • Admission: ${student.admissionNumber}',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              _profileDetailTile(Icons.class_, 'Class', _selectedClass?.displayName ?? '-'),
              _profileDetailTile(Icons.person_outline, 'Guardian Name', student.guardianName ?? 'N/A'),
              _profileDetailTile(Icons.phone_outlined, 'Guardian Phone', student.guardianPhone ?? 'N/A'),
              _profileDetailTile(Icons.cake_outlined, 'Date of Birth', formattedDob),
              _profileDetailTile(
                Icons.analytics_outlined,
                'Attendance Rate',
                rateDisplay,
                color: pct < 75 ? Colors.red : Colors.green,
              ),
              if (hasSessionData) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    _miniStatChip('Present: $totP', Colors.green),
                    const SizedBox(width: 8),
                    _miniStatChip('Absent: $totA', Colors.red),
                    if (totL > 0) ...[
                      const SizedBox(width: 8),
                      _miniStatChip('Late: $totL', Colors.orange),
                    ],
                    if (totE > 0) ...[
                      const SizedBox(width: 8),
                      _miniStatChip('Excused: $totE', Colors.blue),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('CLOSE'),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniStatChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _profileDetailTile(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final isWide = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Portal & Attendance Workstation'),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => ProfileModal.show(context, onProfileUpdated: _loadTeacherData),
            tooltip: 'My Profile & Security',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTeacherData,
            tooltip: 'Refresh Dashboard',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Provider.of<AuthProvider>(context, listen: false).logout(),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoadingClasses
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile & Welcome Header
                  _buildTeacherHeaderCard(user, isWide),

                  const SizedBox(height: 20),

                  // Diagnostics error alert banner (if 500 or session creation fails)
                  if (_sessionDiagnosticError != null) _buildDiagnosticErrorCard(),

                  // Global error message
                  if (_errorMsg != null) ...[
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMsg!,
                                style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Controls: Class Switcher & Date Picker
                  _buildControlToolbar(isWide),

                  const SizedBox(height: 24),

                  // Daily Attendance Session Card
                  _buildDailyAttendanceCard(isWide),

                  const SizedBox(height: 24),

                  // Analytics deck & KPI Summary
                  if (_loadingAnalytics)
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                  else ...[
                    if (_summary != null) _buildKPICards(isWide),

                    const SizedBox(height: 24),

                    // Interactive Monthly Attendance Register
                    if (_monthlyGridData != null) _buildMonthlyRegisterGrid(),

                    const SizedBox(height: 24),

                    // Defaulters Alert Deck
                    if (_defaulters.isNotEmpty) _buildDefaultersSection(),
                  ],
                ],
              ),
            ),
    );
  }

  Future<void> _reopenSession(String sessionId) async {
    try {
      await _apiService.reopenAttendanceSession(sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session unlocked! You can now edit attendance.'), backgroundColor: Colors.green),
        );
        _loadClassDataAndAnalytics();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unlock session: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildTeacherHeaderCard(User? user, bool isWide) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: EdgeInsets.all(isWide ? 20.0 : 16.0),
        child: isWide
            ? Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: const Icon(Icons.person, size: 36, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back, ${user?.fullName ?? "Teacher"}!',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${user?.email ?? ""} • ${_selectedClass?.displayName ?? "No assigned class"}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.verified, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('CLASS TEACHER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: const Icon(Icons.person, size: 24, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back, ${user?.fullName ?? "Teacher"}!',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedClass?.displayName ?? "No assigned class",
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          user?.email ?? "",
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.verified, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text('CLASS TEACHER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDiagnosticErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Attendance Session Initialization Failure',
                  style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => setState(() => _sessionDiagnosticError = null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _sessionDiagnosticError!,
            style: TextStyle(color: Colors.red.shade900, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('RETRY SESSION OPEN'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _startSession(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlToolbar(bool isWide) {
    final (isHoliday, holidayReason) = _getHolidayInfoForDate(_selectedDate);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Class Selector
            SizedBox(
              width: isWide ? 280 : double.infinity,
              child: SearchableDropdown<SchoolClass>(
                value: _selectedClass,
                labelText: 'Select Class Scope',
                isDense: true,
                items: _availableClasses,
                itemAsString: (c) => c.displayName,
                onChanged: (c) {
                  if (c != null) {
                    setState(() => _selectedClass = c);
                    _loadClassDataAndAnalytics();
                  }
                },
              ),
            ),

            // Date Selector
            SizedBox(
              width: isWide ? 200 : double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                    _loadClassDataAndAnalytics();
                  }
                },
              ),
            ),

            if (isHoliday)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade400),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.beach_access, size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Holiday: $holidayReason',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyAttendanceCard(bool isWide) {
    final dailySession = _dailySessions[1];
    final isClosed = dailySession?.status == 'closed';
    final isOpen = dailySession?.status == 'open';
    final (isHoliday, holidayReason) = _getHolidayInfoForDate(_selectedDate);

    Color cardBg = Colors.blue.shade50;
    Color borderColor = Colors.blue.shade200;
    IconData statusIcon = Icons.event_available;
    String statusTitle = 'Daily Attendance Not Started';
    String statusSubtitle =
        'No attendance recorded for ${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}. Tap below to mark.';
    String buttonText = 'START DAILY ATTENDANCE';
    Color buttonColor = Theme.of(context).primaryColor;

    if (isHoliday && !isOpen && !isClosed) {
      cardBg = Colors.orange.shade50;
      borderColor = Colors.orange.shade300;
      statusIcon = Icons.beach_access;
      statusTitle = 'Holiday / School Closed ($holidayReason)';
      statusSubtitle =
          'This date is configured as a holiday by school administration. Attendance is not required.';
      buttonText = 'START ATTENDANCE ANYWAY (OVERRIDE)';
      buttonColor = Colors.orange.shade900;
    } else if (isClosed) {
      cardBg = Colors.amber.shade50;
      borderColor = Colors.amber.shade300;
      statusIcon = Icons.lock;
      statusTitle = 'Daily Attendance Finalized & Locked';
      statusSubtitle =
          'Attendance record for this date is finalized. Tap view to inspect or tap unlock if you need to modify.';
      buttonText = 'VIEW ATTENDANCE RECORD (LOCKED)';
      buttonColor = Colors.amber.shade900;
    } else if (isOpen) {
      cardBg = Colors.green.shade50;
      borderColor = Colors.green.shade300;
      statusIcon = Icons.check_circle_outline;
      statusTitle = 'Daily Attendance Session Active (Open)';
      statusSubtitle =
          'Attendance session is currently active. You can update or submit student attendance marks.';
      buttonText = 'CONTINUE / EDIT ATTENDANCE';
      buttonColor = Colors.green.shade800;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(isWide ? 20 : 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isWide ? 12 : 10),
                  decoration: BoxDecoration(
                    color: buttonColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: buttonColor, size: isWide ? 28 : 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: TextStyle(
                          fontSize: isWide ? 16 : 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusSubtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: isWide ? WrapAlignment.end : WrapAlignment.center,
              children: [
                if (isClosed && dailySession != null)
                  SizedBox(
                    width: isWide ? null : double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.lock_open, size: 18),
                      label: const Text('UNLOCK SESSION FOR EDITING', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        foregroundColor: Colors.amber.shade900,
                        side: BorderSide(color: Colors.amber.shade900, width: 1.5),
                      ),
                      onPressed: () => _reopenSession(dailySession.id),
                    ),
                  ),
                SizedBox(
                  width: isWide ? null : double.infinity,
                  child: ElevatedButton.icon(
                    icon: _isStartingSession
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(isClosed ? Icons.lock : Icons.how_to_reg, size: 18),
                    label: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isStartingSession ? null : () => _startSession(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPICards(bool isWide) {
    final s = _summary!;
    final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Class Attendance Overview & Daily Snapshot',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              dateStr,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final availableWidth = constraints.maxWidth;
            int crossAxisCount = 6;
            if (availableWidth < 550) {
              crossAxisCount = 2;
            } else if (availableWidth < 900) {
              crossAxisCount = 3;
            }
            final cardWidth = (availableWidth - (crossAxisCount - 1) * 12) / crossAxisCount;

            final totalStr = _rosterStudents.isEmpty ? 1 : _rosterStudents.length;
            final presentPct = _todayPresent != null ? ((_todayPresent! / totalStr) * 100).toStringAsFixed(0) : '0';

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _responsiveKpiCard(
                  'Attendance Rate',
                  '${s.attendancePercentage.toStringAsFixed(1)}%',
                  'Monthly Avg',
                  Icons.show_chart,
                  s.attendancePercentage >= 85
                      ? Colors.green.shade700
                      : (s.attendancePercentage >= 75 ? Colors.orange.shade800 : Colors.red.shade700),
                  cardWidth,
                ),
                _responsiveKpiCard(
                  'Enrolled Students',
                  '${_rosterStudents.length}',
                  'Class Strength',
                  Icons.groups,
                  Colors.blue.shade700,
                  cardWidth,
                ),
                _responsiveKpiCard(
                  'Present Today',
                  _todayPresent != null ? '$_todayPresent' : '--',
                  _todayPresent != null ? '$presentPct% present' : 'Not marked',
                  Icons.check_circle_outline,
                  _todayPresent != null ? Colors.green.shade700 : Colors.grey.shade600,
                  cardWidth,
                ),
                _responsiveKpiCard(
                  'Absent Today',
                  _todayAbsent != null ? '$_todayAbsent' : '--',
                  _todayAbsent != null ? '$_todayAbsent student${_todayAbsent == 1 ? '' : 's'}' : 'Not marked',
                  Icons.cancel_outlined,
                  _todayAbsent != null && _todayAbsent! > 0 ? Colors.red.shade700 : Colors.grey.shade600,
                  cardWidth,
                ),
                _responsiveKpiCard(
                  'Late / Excused',
                  _todayLateExcused != null ? '$_todayLateExcused' : '--',
                  _todayLateExcused != null ? 'Special status' : 'Not marked',
                  Icons.access_time_outlined,
                  _todayLateExcused != null && _todayLateExcused! > 0 ? Colors.orange.shade800 : Colors.grey.shade600,
                  cardWidth,
                ),
                _responsiveKpiCard(
                  'Defaulters (<75%)',
                  '${_defaulters.length}',
                  _defaulters.isNotEmpty ? 'Action Needed' : 'All Clear',
                  Icons.warning_amber_rounded,
                  _defaulters.isNotEmpty ? Colors.red.shade700 : Colors.green.shade700,
                  cardWidth,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _responsiveKpiCard(
    String title,
    String value,
    String badgeText,
    IconData icon,
    Color color,
    double width,
  ) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(icon, color: color, size: 16),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                badgeText,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyRegisterGrid() {
    if (_monthlyGridData is! Map) return const SizedBox();
    final data = _monthlyGridData as Map;
    final students = (data['students'] as List?) ?? [];
    final daysInMonth = (data['days_in_month'] as num?)?.toInt() ?? 30;
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final monthName = monthNames[(_selectedDate.month - 1).clamp(0, 11)];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.grid_on, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Monthly Attendance Grid Register',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    '$monthName ${_selectedDate.year}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Legend Bar
            Row(
              children: [
                _gridLegendItem('P', 'Present', Colors.green),
                const SizedBox(width: 12),
                _gridLegendItem('A', 'Absent', Colors.red),
                const SizedBox(width: 12),
                _gridLegendItem('L', 'Late', Colors.orange),
                const SizedBox(width: 12),
                _gridLegendItem('E', 'Excused', Colors.blue),
                const SizedBox(width: 12),
                _gridLegendItem('-', 'No Session', Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 8,
                headingRowHeight: 36,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 36,
                columns: [
                  const DataColumn(label: Text('Roll', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('Student Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  ...List.generate(daysInMonth, (i) => DataColumn(
                    label: Container(
                      alignment: Alignment.center,
                      width: 20,
                      child: Text('${i + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  )),
                  const DataColumn(label: Text('Tot P', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green))),
                  const DataColumn(label: Text('Tot A', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red))),
                ],
                rows: students.map<DataRow>((st) {
                  final roll = (st['roll_number'] ?? '').toString();
                  final name = (st['full_name'] ?? '').toString();
                  final dailyMap = (st['daily_status'] as Map?) ?? (st['daily'] as Map?) ?? {};
                  final totP = st['total_present'] ?? 0;
                  final totA = st['total_absent'] ?? 0;

                  return DataRow(
                    cells: [
                      DataCell(Text(roll, style: const TextStyle(fontSize: 10))),
                      DataCell(
                        InkWell(
                          onTap: () {
                            final stId = st['student_id'] ?? st['id'];
                            final studentMatch = _rosterStudents.where((s) => s.id == stId || s.rollNumber == roll).firstOrNull ??
                                Student(
                                  id: (stId ?? '').toString(),
                                  schoolId: '',
                                  classId: _selectedClass?.id ?? '',
                                  admissionNumber: (st['admission_number'] ?? 'N/A').toString(),
                                  rollNumber: roll,
                                  fullName: name,
                                  gender: 'other',
                                  isActive: true,
                                  createdAt: DateTime.now().toIso8601String(),
                                );
                            _showStudentProfileModal(
                              studentMatch,
                              gridStudentData: st is Map<String, dynamic>
                                  ? st
                                  : Map<String, dynamic>.from(st as Map),
                            );
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.info_outline, size: 13, color: Theme.of(context).primaryColor),
                              ],
                            ),
                          ),
                        ),
                      ),
                      ...List.generate(daysInMonth, (i) {
                        final dayNum = i + 1;
                        final dStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}";
                        final code = (dailyMap[dStr] ?? dailyMap[dayNum.toString()] ?? '-').toString();

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
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              code,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
                            ),
                          ),
                        );
                      }),
                      DataCell(Text('$totP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800))),
                      DataCell(Text('$totA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade800))),
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

  Widget _gridLegendItem(String code, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(3)),
          child: Text(code, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildDefaultersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              'Attendance Defaulters (< 75%)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _defaulters.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final d = _defaulters[i];
              final studentMatch = _rosterStudents.where((s) => s.id == d.studentId).firstOrNull;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.shade100,
                  child: Text(d.rollNumber, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                ),
                title: Text(d.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Attended: ${d.present} / ${d.totalSessions} sessions'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${d.attendancePercentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: d.attendancePercentage < 50 ? Colors.red : Colors.orange.shade900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (studentMatch != null)
                      IconButton(
                        icon: const Icon(Icons.info_outline, color: Colors.blue),
                        onPressed: () => _showStudentProfileModal(studentMatch),
                        tooltip: 'View Profile',
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }


}

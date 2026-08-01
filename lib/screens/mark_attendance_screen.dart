import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../widgets/searchable_dropdown.dart';

import '../design_system/app_breakpoints.dart';
import '../design_system/app_spacing.dart';
import '../features/attendance/presentation/widgets/counter_header.dart';
import '../features/attendance/presentation/widgets/roster_item.dart';
import '../shared/widgets/app_skeleton.dart';
import '../shared/widgets/app_vertical_navbar.dart';

class MarkAttendanceScreen extends StatefulWidget {
  final AttendanceSession session;
  final SchoolClass schoolClass;

  const MarkAttendanceScreen({
    super.key,
    required this.session,
    required this.schoolClass,
  });

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  List<RosterEntry> _roster = [];
  bool _isClosed = false;
  String _filterStatus =
      'all'; // 'all', 'present', 'absent', 'late', 'excused', 'unmarked'

  @override
  void initState() {
    super.initState();
    _loadSessionRoster();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSessionRoster() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getAttendanceSession(widget.session.id);
      if (data != null) {
        final sessionData = data['session'];
        if (sessionData != null && sessionData['status'] == 'closed') {
          _isClosed = true;
        }

        final rosterList = data['roster'] as List?;
        if (rosterList != null) {
          _roster = rosterList.map((x) => RosterEntry.fromJson(x)).toList();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading session roster: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitBulkMark() async {
    if (_roster.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final marks = _roster
          .map(
            (r) => {
              'student_id': r.studentId,
              'status': r.status,
              if (r.remarks != null && r.remarks!.isNotEmpty)
                'remarks': r.remarks,
            },
          )
          .toList();

      await _apiService.markAttendance(widget.session.id, marks);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('Attendance records saved successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save attendance: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _confirmCloseSession() {
    final presentCount = _roster.where((r) => r.status == 'present').length;
    final absentCount = _roster.where((r) => r.status == 'absent').length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.orange),
            SizedBox(width: 10),
            Text('Lock & Close Session?'),
          ],
        ),
        content: Text(
          'Closing this session will lock the daily attendance record for this date.\n\n'
          'Summary:\n'
          '• Present: $presentCount\n'
          '• Absent: $absentCount\n'
          '• Total Roster: ${_roster.length}\n\n'
          'Are you sure you want to finalize and lock this daily session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _closeSession();
            },
            child: const Text('FINAL LOCK & CLOSE'),
          ),
        ],
      ),
    );
  }

  Future<void> _closeSession() async {
    try {
      await _submitBulkMark();
      await _apiService.closeAttendanceSession(widget.session.id);
      setState(() => _isClosed = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session finalized and locked.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error closing session: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showSingleStudentEditDialog(RosterEntry entry) {
    String selectedStatus = entry.status;
    final remarksCtrl = TextEditingController(text: entry.remarks ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Student Note — ${entry.fullName}'),
        content: StatefulBuilder(
          builder: (_, setD) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Roll No: ${entry.rollNumber}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SearchableDropdown<String>(
                value: selectedStatus,
                labelText: 'Attendance Status',
                items: const ['present', 'absent', 'late', 'excused'],
                itemAsString: (s) => s[0].toUpperCase() + s.substring(1),
                itemBuilder: (ctx, s, isSel) => Text(
                  s[0].toUpperCase() + s.substring(1),
                  style: TextStyle(
                    color: _getStatusColor(s),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onChanged: (v) =>
                    setD(() => selectedStatus = v ?? selectedStatus),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarksCtrl,
                decoration: const InputDecoration(
                  labelText: 'Remarks / Absence Reason',
                  hintText: 'e.g. Doctor note submitted, Parent called',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
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
                final body = <String, dynamic>{'status': selectedStatus};
                final rem = remarksCtrl.text.trim();
                if (rem.isNotEmpty) body['remarks'] = rem;

                await _apiService.updateAttendanceMark(
                  widget.session.id,
                  entry.studentId,
                  body,
                );
                setState(() {
                  entry.status = selectedStatus;
                  entry.remarks = rem.isNotEmpty ? rem : null;
                });
                nav.pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Updated ${entry.fullName}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('SAVE NOTE'),
          ),
        ],
      ),
    );
  }

  void _markAllAs(String status) {
    setState(() {
      for (final entry in _roster) {
        entry.status = status;
      }
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present':
        return Colors.green.shade700;
      case 'absent':
        return Colors.red.shade700;
      case 'late':
        return Colors.orange.shade800;
      case 'excused':
        return Colors.blue.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filteredRoster = _roster.where((r) {
      if (query.isNotEmpty) {
        final searchTarget = '${r.fullName} ${r.rollNumber}'.toLowerCase();
        if (!searchTarget.contains(query)) return false;
      }
      if (_filterStatus != 'all') {
        if (r.status != _filterStatus) return false;
      }
      return true;
    }).toList();

    final presentCount = _roster.where((r) => r.status == 'present').length;
    final absentCount = _roster.where((r) => r.status == 'absent').length;
    final lateCount = _roster.where((r) => r.status == 'late').length;
    final excusedCount = _roster.where((r) => r.status == 'excused').length;

    final mainScaffold = Scaffold(
      appBar: AppBar(
        title: Text('${widget.schoolClass.displayName} • Daily Attendance'),
        actions: [
          if (!_isClosed) ...[
            PopupMenuButton<String>(
              tooltip: 'Bulk Mark All',
              icon: const Icon(Icons.checklist),
              onSelected: _markAllAs,
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'present',
                  child: Text('Mark All Present'),
                ),
                const PopupMenuItem(
                  value: 'absent',
                  child: Text('Mark All Absent'),
                ),
                const PopupMenuItem(
                  value: 'late',
                  child: Text('Mark All Late'),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.lock_outline),
              tooltip: 'Lock & Close Session',
              onPressed: _confirmCloseSession,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: const [
                  AppSkeleton(width: double.infinity, height: 100),
                  SizedBox(height: AppSpacing.md),
                  AppSkeleton(width: double.infinity, height: 50),
                  SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: AppSkeleton(
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ],
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: CustomScrollView(
                  slivers: [
                    // Sticky Header with Summary Stats
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: CounterHeader(
                          dateText: widget.session.sessionDate,
                          isClosed: _isClosed,
                          presentCount: presentCount,
                          absentCount: absentCount,
                          lateCount: lateCount,
                          excusedCount: excusedCount,
                        ),
                      ),
                    ),

                    // Sticky Toolbar with Search & Filter Chips
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                hintText: 'Search student by name or roll number...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _filterChip('all', 'All (${_roster.length})'),
                                  _filterChip('present', 'Present ($presentCount)'),
                                  _filterChip('absent', 'Absent ($absentCount)'),
                                  _filterChip('late', 'Late ($lateCount)'),
                                  _filterChip('excused', 'Excused ($excusedCount)'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Roster list sliver
                    if (filteredRoster.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: Text('No students match the selected filter.'),
                        ),
                      )
                    else
                      SliverFixedExtentList(
                        itemExtent: kRosterItemExtent,
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = filteredRoster[index];
                          return RosterItem(
                            key: ValueKey('roster_item_${item.studentId}'),
                            entry: item,
                            isClosed: _isClosed,
                            onStatusChanged: (newStatus) {
                              setState(() => item.status = newStatus);
                            },
                            onTap: _isClosed
                                ? null
                                : () => _showSingleStudentEditDialog(item),
                          );
                        }, childCount: filteredRoster.length),
                      ),

                    // Bottom padding to ensure last item scrolls clear of sticky save bar
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 88),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _isClosed
          ? null
          : Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSaving ? null : _submitBulkMark,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isSaving ? 'SAVING RECORDS...' : 'SAVE ATTENDANCE RECORDS',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ),
    );

    if (context.isMobile) {
      return mainScaffold;
    }

    return Scaffold(
      body: Row(
        children: [
          AppVerticalNavbar(
            selectedIndex: 1,
            title: 'Workstation',
            subtitle: widget.schoolClass.displayName,
            destinations: const [
              VerticalNavDestination(icon: Icons.arrow_back_rounded, label: 'Back to Portal'),
              VerticalNavDestination(icon: Icons.how_to_reg_rounded, label: 'Mark Attendance'),
              VerticalNavDestination(icon: Icons.refresh_rounded, label: 'Refresh Roster'),
              VerticalNavDestination(icon: Icons.lock_outline, label: 'Lock Session'),
            ],
            onDestinationSelected: (idx) {
              if (idx == 0) {
                Navigator.pop(context);
              } else if (idx == 2) {
                _loadSessionRoster();
              } else if (idx == 3) {
                if (!_isClosed) _confirmCloseSession();
              }
            },
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: mainScaffold),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = _filterStatus == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: isSelected,
        onSelected: (sel) {
          if (sel) setState(() => _filterStatus = key);
        },
      ),
    );
  }
}

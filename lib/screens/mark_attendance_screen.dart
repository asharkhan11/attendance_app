import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../widgets/searchable_dropdown.dart';

import '../design_system/app_breakpoints.dart';
import '../design_system/app_spacing.dart';
import '../design_system/attendance_theme.dart';
import '../features/attendance/presentation/widgets/counter_header.dart';
import '../features/attendance/presentation/widgets/roster_item.dart';
import '../shared/widgets/app_skeleton.dart';

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
      'all'; // 'all', 'present', 'absent', 'late', 'excused'

  @override
  void initState() {
    super.initState();
    _loadSessionRoster();
  }

  @override
  void didUpdateWidget(MarkAttendanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.id != widget.session.id ||
        oldWidget.session.sessionDate != widget.session.sessionDate) {
      _isClosed = false;
      _loadSessionRoster();
    }
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
        final attTheme = Theme.of(context).extension<AttendanceTheme>() ?? AttendanceTheme.light;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text('Attendance records saved successfully!'),
              ],
            ),
            backgroundColor: attTheme.present,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save attendance: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_rounded, color: Colors.amber.shade900, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Lock & Close Session?'),
          ],
        ),
        content: Text(
          'Closing this session will lock the daily attendance record for this date.\n\n'
          'Roster Summary:\n'
          '• Present: $presentCount\n'
          '• Absent: $absentCount\n'
          '• Total Students: ${_roster.length}\n\n'
          'Are you sure you want to finalize and lock this daily session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _closeSession();
            },
            icon: const Icon(Icons.lock_rounded, size: 18),
            label: const Text('FINAL LOCK & CLOSE'),
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
            backgroundColor: Colors.amber,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error closing session: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showSingleStudentEditDialog(RosterEntry entry) {
    String selectedStatus = entry.status;
    final remarksCtrl = TextEditingController(text: entry.remarks ?? '');
    final attTheme = Theme.of(context).extension<AttendanceTheme>() ?? AttendanceTheme.light;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: Icon(Icons.person_rounded, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.fullName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Roll No: ${entry.rollNumber}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: StatefulBuilder(
          builder: (_, setD) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SearchableDropdown<String>(
                value: selectedStatus,
                labelText: 'Attendance Status',
                items: const ['present', 'absent', 'late', 'excused'],
                itemAsString: (s) => s[0].toUpperCase() + s.substring(1),
                itemBuilder: (ctx, s, isSel) => Text(
                  s[0].toUpperCase() + s.substring(1),
                  style: TextStyle(
                    color: _getStatusColor(s, attTheme),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onChanged: (v) =>
                    setD(() => selectedStatus = v ?? selectedStatus),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: remarksCtrl,
                decoration: InputDecoration(
                  labelText: 'Remarks / Reason for Absence',
                  hintText: 'e.g. Sick leave, Medical note submitted',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
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
                      backgroundColor: attTheme.present,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update: $e'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('SAVE REMARKS'),
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

  Color _getStatusColor(String status, AttendanceTheme attTheme) {
    switch (status) {
      case 'present':
        return attTheme.present;
      case 'absent':
        return attTheme.absent;
      case 'late':
        return attTheme.late;
      case 'excused':
        return attTheme.excused;
      default:
        return attTheme.noRecord;
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

    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: const [
            AppSkeleton(width: double.infinity, height: 130),
            SizedBox(height: AppSpacing.md),
            AppSkeleton(width: double.infinity, height: 48),
            SizedBox(height: AppSpacing.md),
            Expanded(
              child: AppSkeleton(
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Summary Stat Header Banner
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.sm,
                      left: AppSpacing.sm,
                      right: AppSpacing.sm,
                      bottom: AppSpacing.xs,
                    ),
                    child: CounterHeader(
                      dateText: widget.session.sessionDate,
                      isClosed: _isClosed,
                      presentCount: presentCount,
                      absentCount: absentCount,
                      lateCount: lateCount,
                      excusedCount: excusedCount,
                      onMarkAllPresent: _isClosed ? null : () => _markAllAs('present'),
                      onMarkAllAbsent: _isClosed ? null : () => _markAllAs('absent'),
                      onLockSession: _isClosed ? null : _confirmCloseSession,
                    ),
                  ),
                ),

                // Search & Filter Toolbar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: Container(
                      padding: EdgeInsets.all(context.isMobile ? 8 : 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
                        ),
                      ),
                      child: context.isMobile
                          ? Column(
                              children: [
                                SizedBox(
                                  height: 38,
                                  child: TextField(
                                    controller: _searchCtrl,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: InputDecoration(
                                      hintText: 'Search student by name or roll...',
                                      prefixIcon: const Icon(Icons.search, size: 18),
                                      suffixIcon: _searchCtrl.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, size: 16),
                                              onPressed: () {
                                                _searchCtrl.clear();
                                                setState(() {});
                                              },
                                            )
                                          : null,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
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
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(height: 8),
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
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 38,
                                    child: TextField(
                                      controller: _searchCtrl,
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'Search student by name or roll number...',
                                        prefixIcon: const Icon(Icons.search, size: 18),
                                        suffixIcon: _searchCtrl.text.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear, size: 16),
                                                onPressed: () {
                                                  _searchCtrl.clear();
                                                  setState(() {});
                                                },
                                              )
                                            : null,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
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
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
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
                ),

                // Roster List
                if (filteredRoster.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: Theme.of(context).disabledColor,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No students match filter',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.titleMedium?.color,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try clearing your search query or selecting "All"',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
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

                // Bottom padding to ensure items scroll clear of floating save bar
                SliverToBoxAdapter(
                  child: SizedBox(height: _isClosed ? 24 : 90),
                ),
              ],
            ),
          ),
        ),

        // Floating Bottom Save Action Bar
        if (!_isClosed)
          Positioned(
            left: 0,
            right: 0,
            bottom: context.isMobile ? 6 : 12,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.isMobile ? AppSpacing.sm : AppSpacing.md,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(context.isMobile ? 12 : 16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size.fromHeight(context.isMobile ? 44 : 52),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.isMobile ? 12 : 16),
                        ),
                      ),
                      onPressed: _isSaving ? null : _submitBulkMark,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(Icons.save_rounded, size: context.isMobile ? 18 : 22),
                      label: Text(
                        _isSaving
                            ? 'SAVING...'
                            : 'SAVE ATTENDANCE RECORDS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: context.isMobile ? 13 : 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = _filterStatus == key;
    final attTheme = Theme.of(context).extension<AttendanceTheme>() ?? AttendanceTheme.light;
    Color fgColor;
    Color bgColor;

    switch (key) {
      case 'present':
        fgColor = attTheme.present;
        bgColor = attTheme.presentBg;
        break;
      case 'absent':
        fgColor = attTheme.absent;
        bgColor = attTheme.absentBg;
        break;
      case 'late':
        fgColor = attTheme.late;
        bgColor = attTheme.lateBg;
        break;
      case 'excused':
        fgColor = attTheme.excused;
        bgColor = attTheme.excusedBg;
        break;
      default:
        fgColor = Theme.of(context).primaryColor;
        bgColor = Theme.of(context).primaryColor.withValues(alpha: 0.12);
    }

    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? (key == 'all' ? Colors.white : fgColor)
                : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        selected: isSelected,
        showCheckmark: false,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey.shade800
            : Colors.grey.shade100,
        selectedColor: key == 'all'
            ? Theme.of(context).primaryColor
            : bgColor,
        side: BorderSide(
          color: isSelected
              ? fgColor
              : Theme.of(context).dividerColor,
        ),
        onSelected: (sel) {
          if (sel) setState(() => _filterStatus = key);
        },
      ),
    );
  }
}

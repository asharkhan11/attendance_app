import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../widgets/searchable_dropdown.dart';

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
  String _filterStatus = 'all'; // 'all', 'present', 'absent', 'late', 'excused', 'unmarked'

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
          SnackBar(content: Text('Error loading session roster: $e'), backgroundColor: Colors.redAccent),
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
          .map((r) => {
                'student_id': r.studentId,
                'status': r.status,
                if (r.remarks != null && r.remarks!.isNotEmpty) 'remarks': r.remarks,
              })
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
          SnackBar(content: Text('Failed to save attendance: $e'), backgroundColor: Colors.redAccent),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
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
          const SnackBar(content: Text('Session finalized and locked.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error closing session: $e'), backgroundColor: Colors.redAccent),
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
              Text('Roll No: ${entry.rollNumber}', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SearchableDropdown<String>(
                value: selectedStatus,
                labelText: 'Attendance Status',
                items: const ['present', 'absent', 'late', 'excused'],
                itemAsString: (s) => s[0].toUpperCase() + s.substring(1),
                itemBuilder: (ctx, s, isSel) => Text(
                  s[0].toUpperCase() + s.substring(1),
                  style: TextStyle(color: _getStatusColor(s), fontWeight: FontWeight.bold),
                ),
                onChanged: (v) => setD(() => selectedStatus = v ?? selectedStatus),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              try {
                final body = <String, dynamic>{'status': selectedStatus};
                final rem = remarksCtrl.text.trim();
                if (rem.isNotEmpty) body['remarks'] = rem;

                await _apiService.updateAttendanceMark(widget.session.id, entry.studentId, body);
                setState(() {
                  entry.status = selectedStatus;
                  entry.remarks = rem.isNotEmpty ? rem : null;
                });
                nav.pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Updated ${entry.fullName}'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.redAccent),
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
    final isWide = MediaQuery.of(context).size.width > 700;

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

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.schoolClass.displayName} • Daily Attendance'),
        actions: [
          if (!_isClosed) ...[
            PopupMenuButton<String>(
              tooltip: 'Bulk Mark All',
              icon: const Icon(Icons.checklist),
              onSelected: _markAllAs,
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'present', child: Text('Mark All Present')),
                const PopupMenuItem(value: 'absent', child: Text('Mark All Absent')),
                const PopupMenuItem(value: 'late', child: Text('Mark All Late')),
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
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Live Counter Deck Header
                Container(
                  color: _isClosed ? Colors.amber.shade50 : Colors.blue.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(_isClosed ? Icons.lock : Icons.info_outline,
                              color: _isClosed ? Colors.amber.shade800 : Colors.blue.shade800, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _isClosed
                                  ? 'Session LOCKED — Attendance completed.'
                                  : 'Date: ${widget.session.sessionDate.substring(0, 10)} • Daily Attendance',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _isClosed ? Colors.amber.shade900 : Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _counterChip('Present', '$presentCount', Colors.green),
                          _counterChip('Absent', '$absentCount', Colors.red),
                          _counterChip('Late', '$lateCount', Colors.orange),
                          _counterChip('Excused', '$excusedCount', Colors.blue),
                        ],
                      ),
                    ],
                  ),
                ),

                // Search & Filter Toolbar
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search student name or roll number...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
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
                  ),
                ),

                // Roster list
                Expanded(
                  child: filteredRoster.isEmpty
                      ? const Center(child: Text('No students match the selected filter.'))
                      : ListView.separated(
                          itemCount: filteredRoster.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = filteredRoster[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(item.status).withValues(alpha: 0.15),
                                child: Text(
                                  item.rollNumber,
                                  style: TextStyle(fontWeight: FontWeight.bold, color: _getStatusColor(item.status), fontSize: 13),
                                ),
                              ),
                              title: Text(item.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: item.remarks != null && item.remarks!.isNotEmpty
                                  ? Text('Note: ${item.remarks}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700))
                                  : null,
                              onTap: _isClosed ? null : () => _showSingleStudentEditDialog(item),
                              trailing: _isClosed
                                  ? Chip(
                                      label: Text(item.status.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      backgroundColor: _getStatusColor(item.status).withValues(alpha: 0.2),
                                    )
                                  : isWide
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: ['present', 'absent', 'late', 'excused'].map((st) {
                                            final isSelected = item.status == st;
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                              child: ChoiceChip(
                                                label: Text(st[0].toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                selected: isSelected,
                                                selectedColor: _getStatusColor(st),
                                                onSelected: (selected) {
                                                  if (selected) setState(() => item.status = st);
                                                },
                                              ),
                                            );
                                          }).toList(),
                                        )
                                      : SizedBox(
                                          width: 120,
                                          child: SearchableDropdown<String>(
                                            value: item.status,
                                            isDense: true,
                                            items: const ['present', 'absent', 'late', 'excused'],
                                            itemAsString: (s) => s[0].toUpperCase() + s.substring(1),
                                            itemBuilder: (ctx, s, isSel) => Text(
                                              s[0].toUpperCase() + s.substring(1),
                                              style: TextStyle(color: _getStatusColor(s), fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            onChanged: (v) {
                                              if (v != null) setState(() => item.status = v);
                                            },
                                          ),
                                        ),
                            );
                          },
                        ),
                ),

                // Save button
                if (!_isClosed)
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('SAVE ATTENDANCE RECORDS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isSaving ? null : _submitBulkMark,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _counterChip(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $val',
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
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

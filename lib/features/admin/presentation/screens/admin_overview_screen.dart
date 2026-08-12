import 'package:flutter/material.dart';
import '../../../../design_system/app_breakpoints.dart';
import '../../../../models/app_models.dart';
import '../../../../services/api_service.dart';

/// Admin Overview Dashboard — shows at-a-glance KPIs, today's class session
/// statuses, and quick-action shortcuts. Loaded as the new index-0 admin tab.
class AdminOverviewScreen extends StatefulWidget {
  final ApiService api;
  final AcademicYear? selectedYear;
  final List<SchoolClass> classes;
  final void Function(String msg, {bool error}) snack;
  final void Function(int index) navigateTo;

  const AdminOverviewScreen({
    super.key,
    required this.api,
    required this.selectedYear,
    required this.classes,
    required this.snack,
    required this.navigateTo,
  });

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  bool _loading = false;
  Map<String, dynamic>? _overview;
  List<dynamic> _sessionStatuses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminOverviewScreen old) {
    super.didUpdateWidget(old);
    if (old.selectedYear?.id != widget.selectedYear?.id) _load();
  }

  Future<void> _load() async {
    if (widget.selectedYear == null) return;
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final from = DateTime(
        now.year,
        now.month,
        1,
      ).toIso8601String().split('T')[0];
      final to = now.toIso8601String().split('T')[0];

      final ov = await widget.api.getSchoolOverview(
        academicYearId: widget.selectedYear!.id,
        from: from,
        to: to,
        threshold: 75,
      );
      final sessionsRes = await widget.api.listSessions(
        from: to,
        to: to,
        pageSize: 50,
      );

      setState(() {
        _overview = ov is Map
            ? Map<String, dynamic>.from(ov['data'] ?? ov)
            : <String, dynamic>{};
        _sessionStatuses = sessionsRes.data;
      });
    } catch (e) {
      widget.snack('Failed to load overview: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  num _findNum(List<String> keys) {
    for (final k in keys) {
      final v = _overview?[k];
      if (v is num) return v;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = context.isDesktop;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Greeting Header ─────────────────────────────────────────
            _buildGreetingHeader(theme, greeting),
            const SizedBox(height: 24),

            // ─── KPI Grid ────────────────────────────────────────────────
            if (widget.selectedYear == null)
              _buildNoSessionCard(theme)
            else ...[
              Text(
                'This Month at a Glance',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                _buildKpiGrid(isWide),

              const SizedBox(height: 28),

              // ─── Today's Sessions ─────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Today's Session Status",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Refresh'),
                    onPressed: _load,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildTodaySessionList(theme),

              const SizedBox(height: 28),

              // ─── Quick Actions ────────────────────────────────────────
              Text(
                'Quick Actions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildQuickActions(theme, isWide),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingHeader(ThemeData theme, String greeting) {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              theme.primaryColor,
              theme.primaryColor.withValues(alpha: 0.75),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting 👋',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.selectedYear?.name ?? 'Admin Portal',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.selectedYear != null)
                    Text(
                      '${widget.selectedYear!.startDate.split('T')[0]} → ${widget.selectedYear!.endDate.split('T')[0]}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.school_outlined, color: Colors.white30, size: 64),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSessionCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 56,
                color: Colors.orange.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'No Academic Session Selected',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Please select or create an academic session to see the overview.',
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Go to Sessions'),
                // Tab index 1 = Sessions (after Overview shift)
                onPressed: () => widget.navigateTo(1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiGrid(bool isWide) {
    final overallPct = _findNum([
      'overall_attendance_pct',
      'attendance_percentage',
      'average_attendance',
    ]).toDouble();

    final totalStudents = _findNum([
      'total_students',
      'enrolled_students',
      'student_count',
    ]).toInt();

    final totalSessions = _findNum([
      'total_sessions',
      'sessions_conducted',
    ]).toInt();

    final totalDefaulters = _findNum([
      'total_defaulters',
      'defaulters_count',
    ]).toInt();

    final kpis = [
      _KpiData(
        label: 'Attendance This Month',
        value: '${overallPct.toStringAsFixed(1)}%',
        icon: Icons.trending_up_rounded,
        color: overallPct >= 85
            ? const Color(0xFF059669)
            : overallPct >= 75
            ? const Color(0xFFD97706)
            : const Color(0xFFEF4444),
        subtitle: overallPct >= 85
            ? 'Excellent'
            : overallPct >= 75
            ? 'Satisfactory'
            : 'Needs Attention',
      ),
      _KpiData(
        label: 'Total Students',
        value: '$totalStudents',
        icon: Icons.people_rounded,
        color: const Color(0xFF3B82F6),
        subtitle: '${widget.classes.length} classes',
      ),
      _KpiData(
        label: 'Sessions Conducted',
        value: '$totalSessions',
        icon: Icons.event_available_rounded,
        color: const Color(0xFF8B5CF6),
        subtitle: 'This month',
      ),
      _KpiData(
        label: 'Defaulters (<75%)',
        value: '$totalDefaulters',
        icon: Icons.warning_amber_rounded,
        color: totalDefaulters > 0
            ? const Color(0xFFEF4444)
            : const Color(0xFF059669),
        subtitle: totalDefaulters > 0
            ? 'Requires attention'
            : 'None this month',
      ),
    ];

    if (isWide) {
      return Row(
        children: kpis
            .map(
              (k) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _KpiCard(data: k),
                ),
              ),
            )
            .toList(),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
      physics: const NeverScrollableScrollPhysics(),
      children: kpis.map((k) => _KpiCard(data: k)).toList(),
    );
  }

  Widget _buildTodaySessionList(ThemeData theme) {
    if (widget.classes.isEmpty) {
      return Card(
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('No classes in this session.')),
        ),
      );
    }

    // Build a set of classIds that have a session today
    final sessionClassIds = <String>{};
    final closedClassIds = <String>{};
    for (final s in _sessionStatuses) {
      final cid = s['class_id']?.toString();
      if (cid != null) {
        sessionClassIds.add(cid);
        if (s['status']?.toString() == 'closed') closedClassIds.add(cid);
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.classes.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final cls = widget.classes[i];
            final hasSession = sessionClassIds.contains(cls.id);
            final isClosed = closedClassIds.contains(cls.id);

            final (statusLabel, statusColor, statusIcon) = !hasSession
                ? ('Not Started', Colors.grey, Icons.radio_button_unchecked)
                : isClosed
                ? (
                    'Finalized',
                    const Color(0xFF059669),
                    Icons.check_circle_rounded,
                  )
                : (
                    'Active',
                    const Color(0xFF3B82F6),
                    Icons.play_circle_filled_rounded,
                  );

            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                child: Text(
                  '${cls.gradeLevel}',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              title: Text(
                cls.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                cls.classTeacherName ?? 'No teacher assigned',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Chip(
                avatar: Icon(statusIcon, size: 14, color: statusColor),
                label: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: statusColor.withValues(alpha: 0.1),
                side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme, bool isWide) {
    final actions = [
      _QuickAction(
        icon: Icons.analytics_rounded,
        label: 'View Analytics',
        color: const Color(0xFF4F46E5),
        onTap: () => widget.navigateTo(2), // Analytics = index 2
      ),
      _QuickAction(
        icon: Icons.people_rounded,
        label: 'Manage Students',
        color: const Color(0xFF059669),
        onTap: () => widget.navigateTo(4), // Students = index 4
      ),
      _QuickAction(
        icon: Icons.assessment_rounded,
        label: 'Export Reports',
        color: const Color(0xFF0EA5E9),
        onTap: () => widget.navigateTo(6), // Reports = index 6
      ),
      _QuickAction(
        icon: Icons.class_rounded,
        label: 'Manage Classes',
        color: const Color(0xFF8B5CF6),
        onTap: () => widget.navigateTo(3), // Classes = index 3
      ),
    ];

    if (isWide) {
      return Row(
        children: actions
            .map(
              (a) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _QuickActionCard(action: a),
                ),
              ),
            )
            .toList(),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.85,
      physics: const NeverScrollableScrollPhysics(),
      children: actions.map((a) => _QuickActionCard(action: a)).toList(),
    );
  }
}

// ─── Data classes ────────────────────────────────────────────────────────────

class _KpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _KpiData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
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
                    data.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: data.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(data.icon, size: 14, color: data.color),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              data.value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: data.color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              data.subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _QuickActionCard extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(action.icon, color: action.color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  action.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: action.color.withValues(alpha: 0.6),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

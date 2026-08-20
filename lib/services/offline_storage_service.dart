import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';
import '../utils/app_logger.dart';

/// Representation of an attendance payload saved offline, waiting to be synced to the backend.
class AttendanceSyncQueueItem {
  final String id;
  final String classId;
  final String className;
  final String sessionDate;
  final int periodNumber;
  final List<Map<String, dynamic>> marks;
  final bool shouldClose;
  final String createdAt;
  int retryCount;
  String? lastAttemptAt;
  String? lastError;

  AttendanceSyncQueueItem({
    required this.id,
    required this.classId,
    required this.className,
    required this.sessionDate,
    required this.periodNumber,
    required this.marks,
    this.shouldClose = false,
    required this.createdAt,
    this.retryCount = 0,
    this.lastAttemptAt,
    this.lastError,
  });

  factory AttendanceSyncQueueItem.fromJson(Map<String, dynamic> json) {
    return AttendanceSyncQueueItem(
      id: json['id'] ?? '',
      classId: json['class_id'] ?? '',
      className: json['class_name'] ?? 'Class',
      sessionDate: json['session_date'] ?? '',
      periodNumber: (json['period_number'] as num?)?.toInt() ?? 1,
      marks: (json['marks'] as List<dynamic>?)
              ?.map((m) => Map<String, dynamic>.from(m as Map))
              .toList() ??
          [],
      shouldClose: json['should_close'] == true,
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
      lastAttemptAt: json['last_attempt_at'],
      lastError: json['last_error'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'class_id': classId,
        'class_name': className,
        'session_date': sessionDate,
        'period_number': periodNumber,
        'marks': marks,
        'should_close': shouldClose,
        'created_at': createdAt,
        'retry_count': retryCount,
        'last_attempt_at': lastAttemptAt,
        'last_error': lastError,
      };
}

/// Service managing persistent local cache and the offline synchronization queue.
class OfflineStorageService {
  static final OfflineStorageService _instance = OfflineStorageService._internal();
  factory OfflineStorageService() => _instance;
  OfflineStorageService._internal();

  static const String _kKeyAssignedClasses = 'offline_assigned_classes';
  static const String _kKeyRosterPrefix = 'offline_roster_class_';
  static const String _kKeySessionRosterPrefix = 'offline_session_roster_';
  static const String _kKeySummaryPrefix = 'offline_summary_class_';
  static const String _kKeySyncQueue = 'offline_attendance_sync_queue';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ─── Assigned Classes Cache ────────────────────────────────────────────────

  Future<void> cacheAssignedClasses(List<SchoolClass> classes) async {
    try {
      final prefs = await _getPrefs();
      final jsonList = classes.map((c) => c.toJson()).toList();
      await prefs.setString(_kKeyAssignedClasses, jsonEncode(jsonList));
      AppLogger.d('OfflineStorage', 'Cached ${classes.length} assigned classes locally');
    } catch (e) {
      AppLogger.w('OfflineStorage', 'Error caching classes: $e');
    }
  }

  Future<List<SchoolClass>> getCachedAssignedClasses() async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_kKeyAssignedClasses);
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list.map((x) => SchoolClass.fromJson(Map<String, dynamic>.from(x))).toList();
    } catch (e) {
      AppLogger.w('OfflineStorage', 'Error reading cached classes: $e');
      return [];
    }
  }

  // ─── Class Student Roster Cache ───────────────────────────────────────────

  Future<void> cacheClassRoster(String classId, List<Student> students) async {
    try {
      final prefs = await _getPrefs();
      final jsonList = students.map((s) => s.toJson()).toList();
      await prefs.setString('$_kKeyRosterPrefix$classId', jsonEncode(jsonList));
      AppLogger.d('OfflineStorage', 'Cached ${students.length} students for class $classId');
    } catch (e) {
      AppLogger.w('OfflineStorage', 'Error caching roster for $classId: $e');
    }
  }

  Future<List<Student>> getCachedClassRoster(String classId) async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString('$_kKeyRosterPrefix$classId');
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list.map((x) => Student.fromJson(Map<String, dynamic>.from(x))).toList();
    } catch (e) {
      AppLogger.w('OfflineStorage', 'Error reading cached roster for $classId: $e');
      return [];
    }
  }

  // ─── Session Details & Marks Cache ────────────────────────────────────────

  Future<void> cacheSessionRoster(String sessionId, Map<String, dynamic> data) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString('$_kKeySessionRosterPrefix$sessionId', jsonEncode(data));
    } catch (e) {
      AppLogger.w('OfflineStorage', 'Error caching session roster for $sessionId: $e');
    }
  }

  Future<Map<String, dynamic>?> getCachedSessionRoster(String sessionId) async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString('$_kKeySessionRosterPrefix$sessionId');
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.w('OfflineStorage', 'Error reading session roster for $sessionId: $e');
      return null;
    }
  }

  // ─── Class Summary Analytics Cache ────────────────────────────────────────

  Future<void> cacheClassSummary(String classId, ClassSummary summary) async {
    try {
      final prefs = await _getPrefs();
      final map = {
        'class_id': summary.classId,
        'total_sessions': summary.totalSessions,
        'total_records': summary.totalRecords,
        'present': summary.present,
        'absent': summary.absent,
        'late': summary.late,
        'excused': summary.excused,
        'attendance_percentage': summary.attendancePercentage,
      };
      await prefs.setString('$_kKeySummaryPrefix$classId', jsonEncode(map));
    } catch (e) {
      AppLogger.w('OfflineStorage', 'Error caching summary for $classId: $e');
    }
  }

  Future<ClassSummary?> getCachedClassSummary(String classId) async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString('$_kKeySummaryPrefix$classId');
      if (raw == null || raw.isEmpty) return null;
      return ClassSummary.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // ─── Persistent Sync Queue ────────────────────────────────────────────────

  Future<List<AttendanceSyncQueueItem>> getPendingSyncQueue() async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_kKeySyncQueue);
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((x) => AttendanceSyncQueueItem.fromJson(Map<String, dynamic>.from(x)))
          .toList();
    } catch (e) {
      AppLogger.e('OfflineStorage', 'Error reading sync queue: $e');
      return [];
    }
  }

  Future<void> _savePendingSyncQueue(List<AttendanceSyncQueueItem> queue) async {
    final prefs = await _getPrefs();
    final jsonList = queue.map((q) => q.toJson()).toList();
    await prefs.setString(_kKeySyncQueue, jsonEncode(jsonList));
  }

  Future<void> enqueueSyncItem(AttendanceSyncQueueItem item) async {
    final queue = await getPendingSyncQueue();
    // Replace if existing queue item matches same class, date, period
    final index = queue.indexWhere(
      (q) => q.classId == item.classId && q.sessionDate == item.sessionDate && q.periodNumber == item.periodNumber,
    );
    if (index >= 0) {
      queue[index] = item;
      AppLogger.i('OfflineStorage', 'Updated existing pending sync queue item: ${item.id}');
    } else {
      queue.add(item);
      AppLogger.i('OfflineStorage', 'Enqueued new offline attendance sync item: ${item.id} (${item.marks.length} marks)');
    }
    await _savePendingSyncQueue(queue);
  }

  Future<void> updateSyncItem(AttendanceSyncQueueItem item) async {
    final queue = await getPendingSyncQueue();
    final index = queue.indexWhere((q) => q.id == item.id);
    if (index >= 0) {
      queue[index] = item;
      await _savePendingSyncQueue(queue);
    }
  }

  Future<void> removeSyncItem(String id) async {
    final queue = await getPendingSyncQueue();
    final updated = queue.where((q) => q.id != id).toList();
    await _savePendingSyncQueue(updated);
    AppLogger.i('OfflineStorage', 'Removed sync queue item: $id');
  }

  Future<void> clearPendingQueue() async {
    final prefs = await _getPrefs();
    await prefs.remove(_kKeySyncQueue);
    AppLogger.i('OfflineStorage', 'Cleared all pending sync queue items');
  }

  Future<int> getPendingQueueCount() async {
    final queue = await getPendingSyncQueue();
    return queue.length;
  }
}

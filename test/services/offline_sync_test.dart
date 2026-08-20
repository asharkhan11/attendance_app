import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_app/models/app_models.dart';
import 'package:attendance_app/services/offline_storage_service.dart';
import 'package:attendance_app/services/attendance_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Storage and Sync Queue Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('AttendanceSyncQueueItem serializes and deserializes properly', () {
      final item = AttendanceSyncQueueItem(
        id: 'class123_2026-08-20_1',
        classId: 'class123',
        className: 'Grade 10-A',
        sessionDate: '2026-08-20',
        periodNumber: 1,
        marks: [
          {'student_id': 'stu-1', 'status': 'present', 'remarks': 'On time'},
          {'student_id': 'stu-2', 'status': 'absent', 'remarks': 'Sick'},
        ],
        shouldClose: true,
        createdAt: '2026-08-20T10:00:00.000Z',
      );

      final json = item.toJson();
      expect(json['id'], 'class123_2026-08-20_1');
      expect(json['class_id'], 'class123');
      expect(json['class_name'], 'Grade 10-A');
      expect(json['session_date'], '2026-08-20');
      expect(json['period_number'], 1);
      expect((json['marks'] as List).length, 2);
      expect(json['should_close'], true);

      final fromJson = AttendanceSyncQueueItem.fromJson(json);
      expect(fromJson.id, item.id);
      expect(fromJson.marks.length, 2);
      expect(fromJson.marks[0]['student_id'], 'stu-1');
      expect(fromJson.marks[1]['status'], 'absent');
      expect(fromJson.shouldClose, true);
    });

    test('OfflineStorageService caches and retrieves assigned classes', () async {
      final storage = OfflineStorageService();
      final classes = [
        SchoolClass(
          id: 'c1',
          schoolId: 's1',
          academicYearId: 'ay1',
          gradeLevel: 10,
          section: 'A',
          classTeacherId: 't1',
          classTeacherName: 'Teacher A',
        ),
      ];

      await storage.cacheAssignedClasses(classes);
      final cached = await storage.getCachedAssignedClasses();

      expect(cached.length, 1);
      expect(cached.first.id, 'c1');
      expect(cached.first.displayName, 'Grade 10-A');
    });

    test('OfflineStorageService caches and retrieves class student roster', () async {
      final storage = OfflineStorageService();
      final students = [
        Student(
          id: 'stu-1',
          classId: 'c1',
          admissionNumber: 'ADM001',
          rollNumber: '1',
          fullName: 'Alice Johnson',
        ),
        Student(
          id: 'stu-2',
          classId: 'c1',
          admissionNumber: 'ADM002',
          rollNumber: '2',
          fullName: 'Bob Smith',
        ),
      ];

      await storage.cacheClassRoster('c1', students);
      final cached = await storage.getCachedClassRoster('c1');

      expect(cached.length, 2);
      expect(cached[0].fullName, 'Alice Johnson');
      expect(cached[1].rollNumber, '2');
    });

    test('OfflineStorageService enqueues, updates, and removes sync items', () async {
      final storage = OfflineStorageService();
      expect(await storage.getPendingQueueCount(), 0);

      final item1 = AttendanceSyncQueueItem(
        id: 'item-1',
        classId: 'c1',
        className: 'Grade 10-A',
        sessionDate: '2026-08-20',
        periodNumber: 1,
        marks: [{'student_id': 'stu-1', 'status': 'present'}],
        createdAt: DateTime.now().toIso8601String(),
      );

      await storage.enqueueSyncItem(item1);
      expect(await storage.getPendingQueueCount(), 1);

      // Updating item
      item1.retryCount = 2;
      item1.lastError = 'Network timeout';
      await storage.updateSyncItem(item1);

      final queue = await storage.getPendingSyncQueue();
      expect(queue.first.retryCount, 2);
      expect(queue.first.lastError, 'Network timeout');

      // Removing item
      await storage.removeSyncItem('item-1');
      expect(await storage.getPendingQueueCount(), 0);
    });

    test('SyncStatusState copyWith works correctly', () {
      const state = SyncStatusState(
        isSyncing: false,
        pendingCount: 2,
        isOnline: true,
      );

      final updated = state.copyWith(isSyncing: true, pendingCount: 3);
      expect(updated.isSyncing, true);
      expect(updated.pendingCount, 3);
      expect(updated.isOnline, true);
    });
  });
}

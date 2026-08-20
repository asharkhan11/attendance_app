import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'connectivity_service.dart';
import 'offline_storage_service.dart';
import '../utils/app_logger.dart';

class SyncStatusState {
  final bool isSyncing;
  final int pendingCount;
  final DateTime? lastSyncTime;
  final String? lastError;
  final bool isOnline;

  const SyncStatusState({
    this.isSyncing = false,
    this.pendingCount = 0,
    this.lastSyncTime,
    this.lastError,
    this.isOnline = true,
  });

  SyncStatusState copyWith({
    bool? isSyncing,
    int? pendingCount,
    DateTime? lastSyncTime,
    String? lastError,
    bool? isOnline,
    bool clearError = false,
  }) {
    return SyncStatusState(
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastError: clearError ? null : (lastError ?? this.lastError),
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

/// Robust background & foreground sync coordinator for offline attendance records.
class AttendanceSyncService {
  static final AttendanceSyncService _instance = AttendanceSyncService._internal();
  factory AttendanceSyncService() => _instance;
  AttendanceSyncService._internal();

  final ApiService _apiService = ApiService();
  final OfflineStorageService _storage = OfflineStorageService();
  final ConnectivityService _connectivity = ConnectivityService();

  final ValueNotifier<SyncStatusState> syncStateNotifier =
      ValueNotifier<SyncStatusState>(const SyncStatusState());

  SyncStatusState get state => syncStateNotifier.value;

  bool _initialized = false;
  StreamSubscription<bool>? _connectivitySub;

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    _connectivity.initialize();

    // Initial state check
    refreshPendingCount();

    // React automatically to online network transition
    _connectivitySub = _connectivity.isOnlineStream.listen((online) {
      syncStateNotifier.value = syncStateNotifier.value.copyWith(isOnline: online);
      if (online) {
        AppLogger.i('AttendanceSyncService', 'Online detected! Triggering auto-sync of pending queue...');
        syncPendingQueue();
      }
    });

    // Check once at startup if already online
    if (_connectivity.isOnline) {
      Future.delayed(const Duration(seconds: 2), () => syncPendingQueue());
    }
  }

  Future<void> refreshPendingCount() async {
    final count = await _storage.getPendingQueueCount();
    syncStateNotifier.value = syncStateNotifier.value.copyWith(
      pendingCount: count,
      isOnline: _connectivity.isOnline,
    );
  }

  /// Manually or automatically synchronize all pending offline attendance batches.
  Future<bool> syncPendingQueue({bool force = false}) async {
    if (state.isSyncing && !force) {
      AppLogger.d('AttendanceSyncService', 'Sync already in progress, skipping duplicate call');
      return false;
    }

    final isOnline = await _connectivity.checkConnectivity();
    if (!isOnline && !force) {
      await refreshPendingCount();
      AppLogger.d('AttendanceSyncService', 'Cannot sync while offline');
      return false;
    }

    final queue = await _storage.getPendingSyncQueue();
    if (queue.isEmpty) {
      syncStateNotifier.value = syncStateNotifier.value.copyWith(
        isSyncing: false,
        pendingCount: 0,
        clearError: true,
        isOnline: isOnline,
      );
      return true;
    }

    syncStateNotifier.value = syncStateNotifier.value.copyWith(
      isSyncing: true,
      pendingCount: queue.length,
      clearError: true,
      isOnline: isOnline,
    );

    AppLogger.i('AttendanceSyncService', 'Beginning sync of ${queue.length} pending attendance batch(es)...');

    int successCount = 0;
    String? syncError;

    for (final item in queue) {
      try {
        AppLogger.i(
          'AttendanceSyncService',
          'Syncing session batch for Class ${item.className} on ${item.sessionDate} (P${item.periodNumber})...',
        );

        // 1. Get or create the backend session idempotently
        final sessionRes = await _apiService.createAttendanceSession({
          'class_id': item.classId,
          'session_date': item.sessionDate,
          'period_number': item.periodNumber,
        });

        if (sessionRes == null) {
          throw Exception('Backend returned empty session response');
        }

        final sessionData = sessionRes is Map && sessionRes['data'] != null
            ? sessionRes['data']
            : sessionRes;
        final sessionId = sessionData['id']?.toString();

        if (sessionId == null || sessionId.isEmpty) {
          throw Exception('Invalid session ID returned from server');
        }

        // 2. Submit student marks
        if (item.marks.isNotEmpty) {
          await _apiService.markAttendance(sessionId, item.marks);
          AppLogger.i(
            'AttendanceSyncService',
            'Successfully submitted ${item.marks.length} marks for session $sessionId',
          );
        }

        // 3. Close session if requested offline
        if (item.shouldClose) {
          try {
            await _apiService.closeAttendanceSession(sessionId);
            AppLogger.i('AttendanceSyncService', 'Session $sessionId closed on server');
          } catch (e) {
            AppLogger.w('AttendanceSyncService', 'Session close note: $e');
          }
        }

        // 4. Update local cache with fresh session roster
        try {
          final freshSessionData = await _apiService.getAttendanceSession(sessionId);
          if (freshSessionData != null && freshSessionData is Map) {
            await _storage.cacheSessionRoster(
              sessionId,
              Map<String, dynamic>.from(freshSessionData),
            );
          }
        } catch (_) {}

        // 5. Remove successfully synced item from persistent queue
        await _storage.removeSyncItem(item.id);
        successCount++;
      } catch (e, stack) {
        AppLogger.e(
          'AttendanceSyncService',
          'Failed to sync batch ${item.id}',
          error: e,
          stackTrace: stack,
        );
        item.retryCount += 1;
        item.lastAttemptAt = DateTime.now().toIso8601String();
        item.lastError = e.toString();
        await _storage.updateSyncItem(item);
        syncError = 'Failed to sync ${item.className}: $e';
      }
    }

    final remaining = await _storage.getPendingQueueCount();
    syncStateNotifier.value = syncStateNotifier.value.copyWith(
      isSyncing: false,
      pendingCount: remaining,
      lastSyncTime: successCount > 0 ? DateTime.now() : state.lastSyncTime,
      lastError: syncError,
      isOnline: isOnline,
    );

    AppLogger.i(
      'AttendanceSyncService',
      'Sync run completed. $successCount batches succeeded, $remaining remaining.',
    );

    return successCount > 0;
  }

  void dispose() {
    _connectivitySub?.cancel();
    syncStateNotifier.dispose();
  }
}

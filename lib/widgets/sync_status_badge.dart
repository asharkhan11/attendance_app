import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/attendance_sync_service.dart';
import '../services/offline_storage_service.dart';
import '../design_system/attendance_theme.dart';

/// Interactive UI badge that displays live network and offline sync status.
class SyncStatusBadge extends StatelessWidget {
  final bool compact;
  final VoidCallback? onSyncCompleted;

  const SyncStatusBadge({
    super.key,
    this.compact = false,
    this.onSyncCompleted,
  });

  @override
  Widget build(BuildContext context) {
    // Purely online mode for web: no offline sync badge needed
    if (kIsWeb) return const SizedBox.shrink();

    final syncService = AttendanceSyncService();
    final attTheme = Theme.of(context).extension<AttendanceTheme>() ?? AttendanceTheme.light;

    return ValueListenableBuilder<SyncStatusState>(
      valueListenable: syncService.syncStateNotifier,
      builder: (context, state, child) {
        Color bgColor;
        Color textColor;
        IconData icon;
        String label;

        if (state.isSyncing) {
          bgColor = Colors.blue.shade50;
          textColor = Colors.blue.shade800;
          icon = Icons.sync;
          label = 'Syncing...';
        } else if (!state.isOnline) {
          if (state.pendingCount > 0) {
            bgColor = Colors.amber.shade100;
            textColor = Colors.amber.shade900;
            icon = Icons.cloud_queue_rounded;
            label = '${state.pendingCount} pending sync';
          } else {
            bgColor = Colors.grey.shade200;
            textColor = Colors.grey.shade800;
            icon = Icons.cloud_off_rounded;
            label = 'Offline Mode';
          }
        } else if (state.pendingCount > 0) {
          bgColor = Colors.amber.shade100;
          textColor = Colors.amber.shade900;
          icon = Icons.cloud_upload_outlined;
          label = '${state.pendingCount} to sync';
        } else if (state.lastError != null) {
          bgColor = Colors.red.shade50;
          textColor = Colors.red.shade800;
          icon = Icons.sync_problem_rounded;
          label = 'Sync error';
        } else {
          bgColor = attTheme.presentBg;
          textColor = attTheme.present;
          icon = Icons.cloud_done_rounded;
          label = 'Synced';
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showSyncDetailsModal(context, onSyncCompleted),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 12,
                vertical: compact ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: textColor.withAlpha(50)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.isSyncing)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(textColor),
                      ),
                    )
                  else
                    Icon(icon, size: 16, color: textColor),
                  if (!compact) ...[
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void _showSyncDetailsModal(
    BuildContext context, [
    VoidCallback? onSyncCompleted,
  ]) {
    final syncService = AttendanceSyncService();
    final storage = OfflineStorageService();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final state = syncService.state;

            return FutureBuilder<List<AttendanceSyncQueueItem>>(
              future: storage.getPendingSyncQueue(),
              builder: (context, snapshot) {
                final queue = snapshot.data ?? [];

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            state.isOnline
                                ? Icons.wifi_rounded
                                : Icons.wifi_off_rounded,
                            color: state.isOnline ? Colors.green : Colors.amber.shade800,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            state.isOnline ? 'Online & Ready' : 'Offline Mode Active',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (state.isSyncing)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.isOnline
                            ? 'All marked attendance will sync instantly with the school database.'
                            : 'Attendance marked offline is safely stored on this device and will automatically sync once connection is restored.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const Divider(height: 24),
                      Text(
                        'Pending Sync Queue (${queue.length})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (queue.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.green),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'All attendance records are completely synchronized with the server.',
                                  style: TextStyle(fontSize: 13, color: Colors.green),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: queue.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (ctx, idx) {
                              final item = queue[idx];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.assignment_turned_in,
                                        size: 18,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.className,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Date: ${item.sessionDate} • ${item.marks.length} Students marked',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          if (item.lastError != null)
                                            Text(
                                              'Retry ${item.retryCount}: ${item.lastError}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.red,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      tooltip: 'Discard offline batch',
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (dCtx) => AlertDialog(
                                            title: const Text('Discard Offline Batch?'),
                                            content: Text(
                                              'Are you sure you want to remove the pending attendance records for ${item.className} from the local offline queue?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(dCtx, false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(dCtx, true),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.red,
                                                ),
                                                child: const Text('Discard'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await storage.removeSyncItem(item.id);
                                          await syncService.refreshPendingCount();
                                          setModalState(() {});
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: state.isSyncing
                              ? null
                              : () async {
                                  setModalState(() {});
                                  final success = await syncService.syncPendingQueue(force: true);
                                  setModalState(() {});
                                  if (context.mounted) {
                                    if (success) {
                                      onSyncCompleted?.call();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Attendance synced successfully!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } else if (!state.isOnline) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Cannot sync while device is offline.'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: const Icon(Icons.sync_rounded),
                          label: Text(
                            state.isSyncing ? 'Syncing...' : 'Sync Now with Server',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

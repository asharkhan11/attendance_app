import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_logger.dart';

class DevLogViewerOverlay extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  const DevLogViewerOverlay({
    super.key,
    required this.child,
    this.navigatorKey,
  });

  @override
  State<DevLogViewerOverlay> createState() => _DevLogViewerOverlayState();
}

class _DevLogViewerOverlayState extends State<DevLogViewerOverlay> {
  final bool _showButton = kDebugMode;

  @override
  Widget build(BuildContext context) {
    if (!_showButton) return widget.child;

    return Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) => Stack(
            children: [
              widget.child,
              Positioned(
                bottom: 20,
                right: 20,
                child: SafeArea(
                  child: Material(
                    elevation: 8,
                    shape: const CircleBorder(),
                    color: Colors.indigo,
                    child: ValueListenableBuilder<List<LogEntry>>(
                      valueListenable: AppLogger.logsNotifier,
                      builder: (context, logs, child) {
                        final hasErrors = logs.any((l) => l.level == LogLevel.error);
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.bug_report, color: Colors.white),
                              tooltip: 'Open Dev Logs (${logs.length})',
                              onPressed: () => _openLogSheet(context),
                            ),
                            if (hasErrors)
                              Positioned(
                                right: 4,
                                top: 4,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openLogSheet(BuildContext context) {
    final navContext = widget.navigatorKey?.currentContext ?? context;
    showModalBottomSheet(
      context: navContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DevLogSheet(),
    );
  }
}

class DevLogSheet extends StatefulWidget {
  const DevLogSheet({super.key});

  @override
  State<DevLogSheet> createState() => _DevLogSheetState();
}

class _DevLogSheetState extends State<DevLogSheet> {
  LogLevel? _selectedLevel;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LogEntry> _filterLogs(List<LogEntry> logs) {
    return logs.where((entry) {
      if (_selectedLevel != null && entry.level != _selectedLevel) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchTag = entry.tag.toLowerCase().contains(query);
        final matchMsg = entry.message.toLowerCase().contains(query);
        final matchErr = entry.error?.toString().toLowerCase().contains(query) ?? false;
        return matchTag || matchMsg || matchErr;
      }
      return true;
    }).toList();
  }

  Color _levelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.blue;
      case LogLevel.info:
        return Colors.green;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.network:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.85;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Drag handle & Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.terminal, color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Dev Frontend Logs',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
                      tooltip: 'Copy all logs',
                      onPressed: () => _copyAllLogs(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep, color: Colors.white70, size: 20),
                      tooltip: 'Clear logs',
                      onPressed: () {
                        AppLogger.clear();
                        setState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Search bar
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Filter logs by tag, message, error...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white38, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.all(8),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 8),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', null),
                      _buildFilterChip('DEBUG 🐛', LogLevel.debug),
                      _buildFilterChip('INFO ℹ️', LogLevel.info),
                      _buildFilterChip('WARN ⚠️', LogLevel.warning),
                      _buildFilterChip('ERROR ❌', LogLevel.error),
                      _buildFilterChip('NET 🌐', LogLevel.network),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Log entries list
          Expanded(
            child: ValueListenableBuilder<List<LogEntry>>(
              valueListenable: AppLogger.logsNotifier,
              builder: (context, logs, child) {
                final filtered = _filterLogs(logs);
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No log entries found.',
                      style: TextStyle(color: Colors.white38),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    return LogEntryTile(entry: entry, levelColor: _levelColor(entry.level));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, LogLevel? level) {
    final isSelected = _selectedLevel == level;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        selected: isSelected,
        selectedColor: Colors.greenAccent,
        backgroundColor: Colors.white12,
        onSelected: (_) => setState(() => _selectedLevel = level),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  void _copyAllLogs(BuildContext context) {
    final logs = AppLogger.logs;
    final buffer = StringBuffer();
    for (final l in logs) {
      buffer.writeln('${l.emoji} [${l.timestamp.toIso8601String()}] [${l.levelLabel}] [${l.tag}] ${l.message}');
      if (l.details != null) buffer.writeln('Details: ${jsonEncode(l.details)}');
      if (l.error != null) buffer.writeln('Error: ${l.error}');
      if (l.stackTrace != null) buffer.writeln('StackTrace: ${l.stackTrace}');
      buffer.writeln('---');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied all logs to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class LogEntryTile extends StatefulWidget {
  final LogEntry entry;
  final Color levelColor;

  const LogEntryTile({super.key, required this.entry, required this.levelColor});

  @override
  State<LogEntryTile> createState() => _LogEntryTileState();
}

class _LogEntryTileState extends State<LogEntryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final timeStr =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}.${entry.timestamp.millisecond.toString().padLeft(3, '0')}';
    final hasExtra = entry.details != null || entry.error != null || entry.stackTrace != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.levelColor.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: hasExtra ? () => setState(() => _expanded = !_expanded) : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.levelColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${entry.emoji} ${entry.levelLabel}',
                      style: TextStyle(
                        color: widget.levelColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '[$timeStr]',
                    style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entry.tag,
                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasExtra)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white38,
                      size: 18,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              SelectableText(
                entry.message,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
              ),
              if (_expanded && hasExtra) ...[
                const Divider(color: Colors.white10, height: 16),
                if (entry.details != null) ...[
                  const Text('Details:', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(entry.details),
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (entry.error != null) ...[
                  const Text('Error:', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  SelectableText(
                    entry.error.toString(),
                    style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 8),
                ],
                if (entry.stackTrace != null) ...[
                  const Text('StackTrace:', style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  SelectableText(
                    entry.stackTrace.toString(),
                    style: const TextStyle(color: Colors.white60, fontSize: 9, fontFamily: 'monospace'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─── Theme Mode Provider ─────────────────────────────────────────────────────

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'theme_mode';

  ThemeNotifier() : super(ThemeMode.light) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final saved = await _storage.read(key: _key);
    if (saved == 'dark') {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.light;
    }
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    state = next;
    await _storage.write(key: _key, value: next == ThemeMode.dark ? 'dark' : 'light');
  }

  bool get isDark => state == ThemeMode.dark;
}

// ─── Attendance Mode Provider ─────────────────────────────────────────────────
// Stores per-teacher preference: 'daily' or 'period_wise'
// 'daily'      → one session per day, no period selector shown
// 'period_wise' → period selector visible, multiple sessions per day allowed

final attendanceModeProvider =
    StateNotifierProvider<AttendanceModeNotifier, AttendanceMode>((ref) {
  return AttendanceModeNotifier();
});

enum AttendanceMode {
  daily,
  periodWise;

  String get label => switch (this) {
        AttendanceMode.daily => 'Daily',
        AttendanceMode.periodWise => 'Period-wise',
      };

  String get storedValue => switch (this) {
        AttendanceMode.daily => 'daily',
        AttendanceMode.periodWise => 'period_wise',
      };

  static AttendanceMode fromString(String? value) {
    if (value == 'period_wise') return AttendanceMode.periodWise;
    return AttendanceMode.daily; // default: daily
  }

  bool get isPeriodWise => this == AttendanceMode.periodWise;
  bool get isDaily => this == AttendanceMode.daily;
}

class AttendanceModeNotifier extends StateNotifier<AttendanceMode> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'attendance_mode';

  AttendanceModeNotifier() : super(AttendanceMode.daily) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _storage.read(key: _key);
    state = AttendanceMode.fromString(saved);
  }

  Future<void> setMode(AttendanceMode mode) async {
    state = mode;
    await _storage.write(key: _key, value: mode.storedValue);
  }

  Future<void> toggle() async {
    final next = state.isDaily ? AttendanceMode.periodWise : AttendanceMode.daily;
    await setMode(next);
  }
}

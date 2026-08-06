import 'package:flutter/services.dart' show rootBundle;
import '../utils/app_logger.dart';

/// Centralized configuration for Environment Variables and Backend API URLs.
class EnvConfig {
  static final Map<String, String> _envMap = {};
  static bool _isInitialized = false;

  /// Default Backend IP / API URL fallback
  static const String defaultApiUrl = 'https://api-attendance.mooble.win';

  /// Initialize environment variables from bundled `.env` asset if present.
  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      final content = await rootBundle.loadString('.env');
      _parseEnv(content);
      AppLogger.i('EnvConfig', 'Environment variables loaded from .env asset.');
    } catch (e) {
      AppLogger.d('EnvConfig', 'No .env asset file found or error reading: $e');
    } finally {
      _isInitialized = true;
    }
  }

  static void _parseEnv(String content) {
    final lines = content.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final parts = line.split('=');
      if (parts.length >= 2) {
        final key = parts[0].trim();
        final value = parts.sublist(1).join('=').trim();
        if (key.isNotEmpty) {
          _envMap[key] = value;
        }
      }
    }
  }

  /// Resolves the Backend API Base URL / IP address with the following priority:
  /// 1. `--dart-define=API_BASE_URL=...` or `--dart-define=BACKEND_IP=...`
  /// 2. `.env` file asset (`API_BASE_URL` or `BACKEND_IP`)
  /// 3. Default fallback: `https://api-attendance.mooble.win`
  static String get apiBaseUrl {
    const compileTimeUrl = String.fromEnvironment('API_BASE_URL');
    if (compileTimeUrl.isNotEmpty) {
      return _cleanUrl(compileTimeUrl);
    }

    const compileTimeIp = String.fromEnvironment('BACKEND_IP');
    if (compileTimeIp.isNotEmpty) {
      return _cleanUrl(compileTimeIp);
    }

    if (_envMap.containsKey('API_BASE_URL') &&
        _envMap['API_BASE_URL']!.isNotEmpty) {
      return _cleanUrl(_envMap['API_BASE_URL']!);
    }

    if (_envMap.containsKey('BACKEND_IP') &&
        _envMap['BACKEND_IP']!.isNotEmpty) {
      return _cleanUrl(_envMap['BACKEND_IP']!);
    }

    return defaultApiUrl;
  }

  static String _cleanUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}

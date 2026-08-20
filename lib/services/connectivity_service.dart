import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';
import '../utils/app_logger.dart';

/// Service responsible for tracking device network connectivity and verified internet reachability.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  final StreamController<bool> _onlineStreamController = StreamController<bool>.broadcast();

  Stream<bool> get isOnlineStream => _onlineStreamController.stream;
  bool get isOnline => isOnlineNotifier.value;

  bool _initialized = false;
  Timer? _heartbeatTimer;

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    // Initial check
    checkConnectivity();

    // Listen to network interface changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _handleConnectivityChange(results);
    });

    // Periodic heartbeat to detect captive portals or backend reachability (every 30s)
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      checkConnectivity();
    });
  }

  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final hasInterface = results.any((r) => r != ConnectivityResult.none);

      if (!hasInterface) {
        _setOnlineStatus(false);
        return false;
      }

      // If interface is active, verify real backend or DNS reachability
      final reachable = await _verifyInternetReachability();
      _setOnlineStatus(reachable);
      return reachable;
    } catch (e) {
      AppLogger.w('ConnectivityService', 'Connectivity check error: $e');
      _setOnlineStatus(false);
      return false;
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) async {
    final hasInterface = results.any((r) => r != ConnectivityResult.none);
    if (!hasInterface) {
      _setOnlineStatus(false);
      return;
    }

    final reachable = await _verifyInternetReachability();
    _setOnlineStatus(reachable);
  }

  Future<bool> _verifyInternetReachability() async {
    try {
      // 1. Try hitting backend healthz or base URL
      final healthUri = Uri.parse('${EnvConfig.apiBaseUrl}/healthz');
      final response = await http.get(healthUri).timeout(const Duration(seconds: 3));
      if (response.statusCode >= 200 && response.statusCode < 500) {
        return true;
      }
    } catch (_) {
      // Fallback check against a reliable public endpoint
      try {
        final fallbackUri = Uri.parse('https://clients3.google.com/generate_204');
        final fallbackRes = await http.get(fallbackUri).timeout(const Duration(seconds: 3));
        if (fallbackRes.statusCode == 204 || (fallbackRes.statusCode >= 200 && fallbackRes.statusCode < 400)) {
          return true;
        }
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  void _setOnlineStatus(bool online) {
    if (isOnlineNotifier.value != online) {
      AppLogger.i(
        'ConnectivityService',
        'Connectivity state changed: ${online ? "ONLINE 🟢" : "OFFLINE 🔴"}',
      );
      isOnlineNotifier.value = online;
      _onlineStreamController.add(online);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _heartbeatTimer?.cancel();
    _onlineStreamController.close();
    isOnlineNotifier.dispose();
  }
}

import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../services/offline_storage_service.dart';
import '../utils/app_logger.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final OfflineStorageService _storage = OfflineStorageService();

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  Future<Map<String, String>> getSavedCredentials() async {
    final schoolCode = await _apiService.getSavedSchoolCode();
    final email = await _apiService.getSavedEmail();
    return {
      'schoolCode': schoolCode ?? '',
      'email': email ?? '',
    };
  }

  Future<bool> login(
    String schoolCode,
    String email,
    String password, {
    bool rememberCredentials = true,
  }) async {
    AppLogger.i('AuthProvider', 'Initiating login for $email (School: $schoolCode)');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.login(
        schoolCode,
        email,
        password,
        rememberCredentials: rememberCredentials,
      );
      if (res != null && res['user'] != null) {
        _currentUser = User.fromJson(res['user']);
        await _storage.cacheUserProfile(_currentUser!);
        AppLogger.i('AuthProvider', 'Login successful for user ${_currentUser?.email} (${_currentUser?.role})');
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Server response missing user profile data. Please try again.';
        AppLogger.w('AuthProvider', 'Login failed: Server response missing user object');
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 400) {
        if (e.code == 'TENANT_NOT_FOUND' || e.message.toLowerCase().contains('school')) {
          _errorMessage = 'Invalid School Code. Please verify your school code.';
        } else if (e.code == 'INVALID_CREDENTIALS') {
          _errorMessage = 'Incorrect Email or Password. Please try again.';
        } else {
          _errorMessage = 'Login failed: ${e.message}';
        }
      } else if (e.statusCode == 404) {
        _errorMessage = 'School code not found or login service unavailable.';
      } else if (e.statusCode >= 500) {
        _errorMessage = 'Server temporary error (${e.statusCode}). Please try again later.';
      } else {
        _errorMessage = e.message;
      }
      AppLogger.w('AuthProvider', 'Login failed with ApiException: ${e.code} (${e.statusCode}) - ${e.message}');
    } catch (e, stack) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socket') || errStr.contains('connection') || errStr.contains('clientexception')) {
        _errorMessage = 'Unable to connect to server. Please check your internet connection.';
      } else {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      AppLogger.e('AuthProvider', 'Login exception occurred', error: e, stackTrace: stack);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> loadProfile() async {
    AppLogger.d('AuthProvider', 'Loading user profile from storage/token...');
    _isLoading = true;
    notifyListeners();

    // 1. Immediately hydrate cached user profile if present for instantaneous offline launch
    final cachedUser = await _storage.getCachedUserProfile();
    if (cachedUser != null) {
      _currentUser = cachedUser;
      AppLogger.i('AuthProvider', 'Loaded cached user profile for ${_currentUser?.email} (${_currentUser?.role})');
      notifyListeners();
    }

    final token = await _apiService.getToken();
    if (token == null) {
      if (_currentUser == null) {
        AppLogger.d('AuthProvider', 'No saved token found');
      }
      _isLoading = false;
      notifyListeners();
      return;
    }

    // 2. Refresh profile from backend if online
    try {
      final res = await _apiService.me();
      if (res != null) {
        _currentUser = User.fromJson(res);
        await _storage.cacheUserProfile(_currentUser!);
        AppLogger.i('AuthProvider', 'User profile refreshed from server: ${_currentUser?.email} (${_currentUser?.role})');
        notifyListeners();
      }
    } on ApiException catch (e) {
      // Only logout if token is explicitly rejected as unauthorized/forbidden
      if (e.statusCode == 401 || e.statusCode == 403) {
        AppLogger.w('AuthProvider', 'Token expired or unauthorized (${e.statusCode}), logging out.');
        await logout();
      } else {
        AppLogger.w('AuthProvider', 'Non-fatal API error fetching profile (${e.statusCode}): ${e.message}. Retaining cached user.');
      }
    } catch (e, stack) {
      // Network/Socket/Timeout error: DO NOT logout. Retain offline cached session.
      AppLogger.w('AuthProvider', 'Could not refresh profile over network (offline mode). Retaining cached session.', error: e, stackTrace: stack);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    AppLogger.i('AuthProvider', 'User logging out');
    try {
      final refreshToken = await _apiService.getRefreshToken();
      if (refreshToken != null) {
        await _apiService.logout(refreshToken);
      }
    } catch (e) {
      AppLogger.w('AuthProvider', 'Error during remote logout call', error: e);
    }
    await _apiService.clearTokens();
    await _storage.clearUserProfile();
    _currentUser = null;
    notifyListeners();
    AppLogger.i('AuthProvider', 'User logged out and session cleared');
  }
}


import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../utils/app_logger.dart';

class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;
  final List<dynamic> details;

  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details = const [],
  });

  @override
  String toString() => message;
}

class ApiPage<T> {
  final List<T> data;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  const ApiPage({
    required this.data,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });
}

class DownloadedFile {
  final Uint8List bytes;
  final String? contentType;
  final String? fileName;

  const DownloadedFile(this.bytes, {this.contentType, this.fileName});
}

class ApiService {
  // Web/desktop: localhost. Android emulator: the host machine's loopback.
  static String get baseUrl {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredUrl.isNotEmpty) {
      return configuredUrl.endsWith('/')
          ? configuredUrl.substring(0, configuredUrl.length - 1)
          : configuredUrl;
    }
    if (kIsWeb) return 'http://localhost:8080';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  final FlutterSecureStorage _storage;

  ApiService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> getToken() => _storage.read(key: 'access_token');
  Future<String?> getRefreshToken() => _storage.read(key: 'refresh_token');

  Future<String?> getSavedSchoolCode() => _storage.read(key: 'saved_school_code');
  Future<String?> getSavedEmail() => _storage.read(key: 'saved_email');

  Future<String> getAttendanceMode() async {
    final mode = await _storage.read(key: 'attendance_mode');
    return mode ?? 'period_wise';
  }

  Future<void> saveAttendanceMode(String mode) async {
    AppLogger.i('ApiService', 'Saving attendance mode setting: $mode');
    await _storage.write(key: 'attendance_mode', value: mode);
  }

  Future<void> saveRememberedCredentials(String schoolCode, String email) async {
    AppLogger.i('ApiService', 'Saving remembered credentials for $email ($schoolCode)');
    await _storage.write(key: 'saved_school_code', value: schoolCode);
    await _storage.write(key: 'saved_email', value: email);
  }

  Future<void> clearRememberedCredentials() async {
    await _storage.delete(key: 'saved_school_code');
    await _storage.delete(key: 'saved_email');
  }

  Future<void> saveTokens(String access, String refresh) async {
    AppLogger.i(
      'ApiService',
      'Saved new access and refresh tokens to secure storage',
    );
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<void> clearTokens() async {
    AppLogger.i('ApiService', 'Cleared auth tokens from secure storage');
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
  }

  Map<String, String> _headers(String? token, {bool json = true}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _decodeResponse(http.Response response) {
    if (response.statusCode == 204 || response.body.trim().isEmpty) return null;

    dynamic body;
    try {
      body = jsonDecode(response.body);
    } on FormatException catch (e, stack) {
      AppLogger.e(
        'ApiService',
        'Invalid JSON response format from ${response.request?.url}',
        error: e,
        stackTrace: stack,
        details: {'statusCode': response.statusCode, 'body': response.body},
      );
      throw ApiException(
        statusCode: response.statusCode,
        code: response.statusCode == 404 ? 'NOT_FOUND' : 'INVALID_RESPONSE',
        message: response.statusCode >= 400
            ? 'HTTP ${response.statusCode}: ${response.body.trim()}'
            : 'The server returned an invalid JSON response.',
      );
    }

    return body;
  }

  dynamic _processResponse(http.Response response) {
    final body = _decodeResponse(response);
    if (body == null) return null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is Map) return body['data'];
      AppLogger.e(
        'ApiService',
        'Response missing data envelope',
        details: {'body': body},
      );
      throw ApiException(
        statusCode: response.statusCode,
        code: 'INVALID_RESPONSE',
        message: 'The server response is missing the standard data envelope.',
      );
    }

    final error = body is Map ? body['error'] : null;
    final apiException = ApiException(
      statusCode: response.statusCode,
      code: error is Map
          ? (error['code']?.toString() ?? 'REQUEST_FAILED')
          : 'REQUEST_FAILED',
      message: error is Map
          ? (error['message']?.toString() ?? 'Request failed.')
          : 'Request failed.',
      details: error is Map && error['details'] is List
          ? error['details'] as List
          : const [],
    );
    AppLogger.w(
      'ApiService',
      'API Error: ${apiException.code} - ${apiException.message}',
      details: {'statusCode': response.statusCode, 'error': error},
    );
    throw apiException;
  }

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request, {
    bool authenticated = true,
    bool allowRefresh = true,
  }) async {
    final token = authenticated ? await getToken() : null;
    final stopwatch = Stopwatch()..start();

    http.Response response;
    try {
      response = await request(_headers(token));
    } catch (e, stack) {
      AppLogger.e(
        'ApiService',
        'Network request execution failed',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
    stopwatch.stop();

    final reqMethod = response.request?.method ?? 'HTTP';
    final reqPath = response.request?.url.path ?? '';
    final details = <String, dynamic>{
      'statusCode': response.statusCode,
      'durationMs': stopwatch.elapsedMilliseconds,
      'url': response.request?.url.toString(),
    };

    if (response.statusCode >= 200 && response.statusCode < 300) {
      AppLogger.net(
        'ApiService',
        '$reqMethod $reqPath (${response.statusCode}) in ${stopwatch.elapsedMilliseconds}ms',
        details: details,
      );
    } else {
      details['bodySummary'] = response.body.length > 300
          ? '${response.body.substring(0, 300)}...'
          : response.body;
      AppLogger.w(
        'ApiService',
        '$reqMethod $reqPath failed with status ${response.statusCode} in ${stopwatch.elapsedMilliseconds}ms',
        details: details,
      );
    }

    if (authenticated &&
        allowRefresh &&
        response.statusCode == 401 &&
        await _refreshAccessToken()) {
      AppLogger.i('ApiService', 'Retrying request after access token refresh');
      return _send(request, authenticated: authenticated, allowRefresh: false);
    }
    return response;
  }

  Future<bool> _refreshAccessToken() async {
    AppLogger.i('ApiService', 'Attempting access token refresh...');
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      AppLogger.w('ApiService', 'Refresh token not found in storage');
      return false;
    }

    try {
      final response = await http.post(
        _uri('/api/v1/auth/refresh'),
        headers: _headers(null),
        body: jsonEncode({'refresh_token': refreshToken}),
      );
      final data = _processResponse(response);
      if (data is Map &&
          data['access_token'] != null &&
          data['refresh_token'] != null) {
        await saveTokens(
          data['access_token'].toString(),
          data['refresh_token'].toString(),
        );
        AppLogger.i('ApiService', 'Access token successfully refreshed');
        return true;
      }
    } catch (e) {
      AppLogger.w('ApiService', 'Token refresh attempt failed', error: e);
    }
    return false;
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? queryParameters,
    bool authenticated = true,
  }) async {
    final response = await _send(
      (headers) => http.get(_uri(path, queryParameters), headers: headers),
      authenticated: authenticated,
    );
    return _processResponse(response);
  }

  Future<dynamic> post(String path, [Object? data]) => _post(path, data);

  Future<dynamic> _post(
    String path,
    Object? data, {
    bool authenticated = true,
  }) async {
    final response = await _send(
      (headers) => http.post(
        _uri(path),
        headers: headers,
        body: data == null ? null : jsonEncode(data),
      ),
      authenticated: authenticated,
    );
    return _processResponse(response);
  }

  Future<dynamic> put(String path, Object data) async {
    final response = await _send(
      (headers) =>
          http.put(_uri(path), headers: headers, body: jsonEncode(data)),
    );
    return _processResponse(response);
  }

  Future<dynamic> patch(String path, [Object? data]) async {
    final response = await _send(
      (headers) => http.patch(
        _uri(path),
        headers: headers,
        body: data == null ? null : jsonEncode(data),
      ),
    );
    return _processResponse(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await _send(
      (headers) => http.delete(_uri(path), headers: headers),
    );
    return _processResponse(response);
  }

  Future<ApiPage<dynamic>> getPage(
    String path, {
    int page = 1,
    int pageSize = 20,
    Map<String, String>? filters,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      ...?filters,
    };
    final response = await _send(
      (headers) => http.get(_uri(path, query), headers: headers),
    );
    _processResponse(response);
    final body = _decodeResponse(response);
    if (body is! Map) {
      throw const ApiException(
        statusCode: 200,
        code: 'INVALID_RESPONSE',
        message: 'The server response is missing the standard data envelope.',
      );
    }
    final meta = body['meta'] is Map
        ? body['meta'] as Map
        : const <dynamic, dynamic>{};
    return ApiPage<dynamic>(
      data: List<dynamic>.from(body['data'] as List? ?? const []),
      page: (meta['page'] as num?)?.toInt() ?? page,
      pageSize: (meta['page_size'] as num?)?.toInt() ?? pageSize,
      total: (meta['total'] as num?)?.toInt() ?? 0,
      totalPages: (meta['total_pages'] as num?)?.toInt() ?? 0,
    );
  }

  Future<dynamic> login(
    String schoolCode,
    String email,
    String password, {
    bool rememberCredentials = true,
  }) async {
    final data = await _post('/api/v1/auth/login', {
      'school_code': schoolCode,
      'email': email,
      'password': password,
    }, authenticated: false);
    if (data is Map &&
        data['access_token'] != null &&
        data['refresh_token'] != null) {
      await saveTokens(
        data['access_token'].toString(),
        data['refresh_token'].toString(),
      );
      if (rememberCredentials) {
        await saveRememberedCredentials(schoolCode, email);
      }
    }
    return data;
  }

  Future<void> logout(String refreshToken) async =>
      post('/api/v1/auth/logout', {'refresh_token': refreshToken});
  Future<dynamic> me() => get('/api/v1/me');

  Future<dynamic> listAcademicYears() => get('/api/v1/academic-years');
  Future<dynamic> createAcademicYear(Object data) =>
      post('/api/v1/academic-years', data);
  Future<dynamic> setAcademicYearCurrent(String id) =>
      patch('/api/v1/academic-years/$id/set-current');
  Future<dynamic> archiveAcademicYear(String id) =>
      patch('/api/v1/academic-years/$id/archive');
  Future<dynamic> unarchiveAcademicYear(String id) =>
      patch('/api/v1/academic-years/$id/unarchive');
  Future<dynamic> promoteStudents(Object data) =>
      post('/api/v1/academic-years/promote-students', data);
  Future<dynamic> copyClasses(Object data) =>
      post('/api/v1/academic-years/copy-classes', data);
  Future<dynamic> copyTeachers(Object data) =>
      post('/api/v1/academic-years/copy-teachers', data);

  Future<ApiPage<dynamic>> listClasses({
    String? academicYearId,
    int page = 1,
    int pageSize = 100,
  }) {
    final filters = <String, String>{};
    if (academicYearId != null && academicYearId.isNotEmpty) {
      filters['academic_year_id'] = academicYearId;
    }
    return getPage(
      '/api/v1/classes',
      page: page,
      pageSize: pageSize,
      filters: filters,
    );
  }

  Future<dynamic> createClass(Object data) => post('/api/v1/classes', data);
  Future<dynamic> deleteClass(String id) => delete('/api/v1/classes/$id');
  Future<dynamic> getMyClass() => get('/api/v1/classes/my-class');
  Future<dynamic> assignClassTeacher(String classId, String? teacherId) =>
      put('/api/v1/classes/$classId/teacher', {'class_teacher_id': teacherId});

  Future<ApiPage<dynamic>> listTeachers({int page = 1, int pageSize = 100}) =>
      getPage('/api/v1/teachers', page: page, pageSize: pageSize);
  Future<dynamic> createTeacher(Object data) => post('/api/v1/teachers', data);
  Future<dynamic> updateTeacher(String id, Object data) =>
      put('/api/v1/teachers/$id', data);
  Future<dynamic> deactivateTeacher(String id) async {
    try {
      return await patch('/api/v1/teachers/$id/deactivate');
    } catch (_) {
      return await put('/api/v1/teachers/$id', {'is_active': false});
    }
  }

  Future<dynamic> activateTeacher(String id) async {
    try {
      return await patch('/api/v1/teachers/$id/activate');
    } catch (_) {
      return await put('/api/v1/teachers/$id', {'is_active': true});
    }
  }

  Future<dynamic> deleteTeacher(String id) =>
      delete('/api/v1/teachers/$id');
  Future<dynamic> resetTeacherPassword(String id, String newPassword) => post(
    '/api/v1/teachers/$id/reset-password',
    {'new_password': newPassword},
  );

  Future<ApiPage<dynamic>> listStudents({
    String? classId,
    String? academicYearId,
    String? search,
    int page = 1,
    int pageSize = 50,
  }) {
    final filters = <String, String>{};
    if (classId != null && classId.isNotEmpty) filters['class_id'] = classId;
    if (academicYearId != null && academicYearId.isNotEmpty) {
      filters['academic_year_id'] = academicYearId;
    }
    if (search != null && search.isNotEmpty) filters['search'] = search;
    return getPage(
      '/api/v1/students',
      page: page,
      pageSize: pageSize,
      filters: filters,
    );
  }

  Future<dynamic> createStudent(Object data) => post('/api/v1/students', data);
  Future<dynamic> getNextStudentInfo(String classId) =>
      get('/api/v1/students/next-info', queryParameters: {'class_id': classId});
  Future<dynamic> updateStudent(String id, Object data) =>
      put('/api/v1/students/$id', data);
  Future<dynamic> deleteStudent(String id) => delete('/api/v1/students/$id');

  Future<dynamic> bulkImportStudents(Uint8List bytes, String filename) async {
    final token = await getToken();
    final request =
        http.MultipartRequest('POST', _uri('/api/v1/students/bulk-import'))
          ..headers.addAll(_headers(token, json: false))
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename),
          );
    var streamed = await request.send();
    if (streamed.statusCode == 401 && await _refreshAccessToken()) {
      final retry =
          http.MultipartRequest('POST', _uri('/api/v1/students/bulk-import'))
            ..headers.addAll(_headers(await getToken(), json: false))
            ..files.add(
              http.MultipartFile.fromBytes('file', bytes, filename: filename),
            );
      streamed = await retry.send();
    }
    return _processResponse(await http.Response.fromStream(streamed));
  }

  Future<dynamic> bulkImportTeachers(Uint8List bytes, String filename) async {
    final token = await getToken();
    final request =
        http.MultipartRequest('POST', _uri('/api/v1/teachers/bulk-import'))
          ..headers.addAll(_headers(token, json: false))
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename),
          );
    var streamed = await request.send();
    if (streamed.statusCode == 401 && await _refreshAccessToken()) {
      final retry =
          http.MultipartRequest('POST', _uri('/api/v1/teachers/bulk-import'))
            ..headers.addAll(_headers(await getToken(), json: false))
            ..files.add(
              http.MultipartFile.fromBytes('file', bytes, filename: filename),
            );
      streamed = await retry.send();
    }
    return _processResponse(await http.Response.fromStream(streamed));
  }

  Future<ApiPage<dynamic>> getClassRoster(
    String classId, {
    int page = 1,
    int pageSize = 100,
  }) => getPage(
    '/api/v1/classes/$classId/students',
    page: page,
    pageSize: pageSize,
  );
  Future<dynamic> createAttendanceSession(Object data) =>
      post('/api/v1/attendance/sessions', data);
  Future<ApiPage<dynamic>> listSessions({
    String? classId,
    String? from,
    String? to,
    int page = 1,
    int pageSize = 100,
  }) =>
      getPage(
        '/api/v1/attendance/sessions',
        page: page,
        pageSize: pageSize,
        filters: {
          if (classId != null && classId.isNotEmpty) 'class_id': classId,
          if (from != null && from.isNotEmpty) 'from': from,
          if (to != null && to.isNotEmpty) 'to': to,
        },
      );
  Future<dynamic> getAttendanceSession(String id) =>
      get('/api/v1/attendance/sessions/$id');
  Future<dynamic> markAttendance(String sessionId, List<Object> marks) =>
      post('/api/v1/attendance/sessions/$sessionId/mark', {'marks': marks});
  Future<dynamic> updateAttendanceMark(
    String sessionId,
    String studentId,
    Object data,
  ) => patch('/api/v1/attendance/sessions/$sessionId/mark/$studentId', data);
  Future<dynamic> closeAttendanceSession(String id) =>
      post('/api/v1/attendance/sessions/$id/close', {});
  Future<dynamic> reopenAttendanceSession(String id) =>
      post('/api/v1/attendance/sessions/$id/reopen', {});

  Future<dynamic> updateMyProfile({
    required String fullName,
    String? phone,
  }) =>
      put('/api/v1/users/me', {
        'full_name': fullName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      });

  Future<dynamic> changeMyPassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      post('/api/v1/users/me/change-password', {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
  Future<dynamic> getStudentAttendanceHistory(String studentId, {String? from, String? to}) =>
      get('/api/v1/students/$studentId/attendance', queryParameters: {
        'from': ?from,
        'to': ?to,
      });

  Future<dynamic> getClassSummary(String classId, {String? from, String? to}) {
    final now = DateTime.now();
    final defaultFrom =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-01";
    final defaultTo =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final query = <String, String>{
      'from': from ?? defaultFrom,
      'to': to ?? defaultTo,
    };
    return get(
      '/api/v1/analytics/class/$classId/summary',
      queryParameters: query,
    );
  }

  Future<dynamic> getClassDefaulters(
    String classId, {
    num threshold = 75,
    String? from,
    String? to,
  }) {
    final now = DateTime.now();
    final defaultFrom =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-01";
    final defaultTo =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final query = <String, String>{
      'threshold': '$threshold',
      'from': from ?? defaultFrom,
      'to': to ?? defaultTo,
    };
    return get(
      '/api/v1/analytics/class/$classId/defaulters',
      queryParameters: query,
    );
  }

  Future<DownloadedFile> downloadReport(
    String path, {
    required String format,
  }) async {
    final response = await _send(
      (headers) => http.get(_uri(path, {'format': format}), headers: headers),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _processResponse(response);
    }
    final disposition = response.headers['content-disposition'];
    final match = RegExp('filename="?([^";]+)').firstMatch(disposition ?? '');
    return DownloadedFile(
      response.bodyBytes,
      contentType: response.headers['content-type'],
      fileName: match?.group(1),
    );
  }

  Future<DownloadedFile> exportClassReport(
    String classId, {
    String format = 'pdf',
  }) => downloadReport('/api/v1/reports/class/$classId/export', format: format);
  Future<DownloadedFile> exportStudentReport(
    String studentId, {
    String format = 'pdf',
  }) => downloadReport(
    '/api/v1/reports/student/$studentId/export',
    format: format,
  );

  Future<dynamic> getSchoolOverview({
    String? academicYearId,
    String? classId,
    String? from,
    String? to,
    num threshold = 75,
  }) {
    final query = <String, String>{
      'academic_year_id': ?academicYearId,
      'class_id': ?classId,
      'from': ?from,
      'to': ?to,
      'threshold': '$threshold',
    };
    return get('/api/v1/analytics/school/overview', queryParameters: query);
  }

  Future<dynamic> getSchoolDefaulters({
    String? classId,
    String? from,
    String? to,
    num threshold = 75,
  }) {
    final query = <String, String>{
      'class_id': ?classId,
      'from': ?from,
      'to': ?to,
      'threshold': '$threshold',
    };
    return get('/api/v1/analytics/school/defaulters', queryParameters: query);
  }

  Future<dynamic> getSchoolTrend({
    String? from,
    String? to,
    String granularity = 'week',
  }) {
    final query = <String, String>{
      'from': ?from,
      'to': ?to,
      'granularity': granularity,
    };
    return get('/api/v1/analytics/school/trend', queryParameters: query);
  }

  Future<dynamic> getClassTrend(
    String classId, {
    String? from,
    String? to,
    String granularity = 'week',
  }) {
    final query = <String, String>{
      'from': ?from,
      'to': ?to,
      'granularity': granularity,
    };
    return get('/api/v1/analytics/class/$classId/trend', queryParameters: query);
  }

  Future<dynamic> getMonthlyMatrix(String classId, {int? year, int? month}) {
    final query = <String, String>{
      'year': ?(year != null ? '$year' : null),
      'month': ?(month != null ? '$month' : null),
    };
    return get('/api/v1/reports/monthly-matrix/$classId', queryParameters: query);
  }

  Future<DownloadedFile> exportMonthlyMatrix(String classId, {int? year, int? month}) async {
    final query = <String, String>{
      'year': ?(year != null ? '$year' : null),
      'month': ?(month != null ? '$month' : null),
      'format': 'csv',
    };
    final response = await _send((headers) => http.get(_uri('/api/v1/reports/monthly-matrix/$classId/export', query), headers: headers));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _processResponse(response);
    }
    return DownloadedFile(response.bodyBytes, contentType: response.headers['content-type'], fileName: 'monthly_matrix_${year}_$month.csv');
  }

  Future<DownloadedFile> exportDefaultersReport({String? classId, String? from, String? to, num threshold = 75}) async {
    final query = <String, String>{
      'class_id': ?classId,
      'from': ?from,
      'to': ?to,
      'threshold': '$threshold',
      'format': 'csv',
    };
    final response = await _send((headers) => http.get(_uri('/api/v1/reports/defaulters/export', query), headers: headers));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _processResponse(response);
    }
    return DownloadedFile(response.bodyBytes, contentType: response.headers['content-type'], fileName: 'defaulters_report.csv');
  }

  Future<dynamic> getAuditLogs({String? from, String? to}) {
    final query = <String, String>{
      'from': ?from,
      'to': ?to,
    };
    return get('/api/v1/reports/audit-log', queryParameters: query);
  }

  Future<DownloadedFile> exportAuditLogs({String? from, String? to}) async {
    final query = <String, String>{
      'from': ?from,
      'to': ?to,
    };
    final response = await _send((headers) => http.get(_uri('/api/v1/reports/audit-log/export', query), headers: headers));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _processResponse(response);
    }
    return DownloadedFile(response.bodyBytes, contentType: response.headers['content-type'], fileName: 'audit_logs.csv');
  }

  Future<DownloadedFile> downloadStudentTemplate() async {
    final response = await _send((headers) => http.get(_uri('/api/v1/templates/students.csv', {}), headers: headers));
    return DownloadedFile(response.bodyBytes, contentType: 'text/csv', fileName: 'students_template.csv');
  }

  Future<DownloadedFile> downloadTeacherTemplate() async {
    final response = await _send((headers) => http.get(_uri('/api/v1/templates/teachers.csv', {}), headers: headers));
    return DownloadedFile(response.bodyBytes, contentType: 'text/csv', fileName: 'teachers_template.csv');
  }

  // ─── School Days & Holidays ──────────────────────────────────────────────────
  Future<dynamic> getWeeklySchedule() {
    return get('/api/v1/school-days/weekly');
  }

  Future<dynamic> updateWeeklySchedule(List<Map<String, dynamic>> schedules) {
    return put('/api/v1/school-days/weekly', {'schedules': schedules});
  }

  Future<dynamic> getSchoolHolidays({String? from, String? to}) {
    final query = <String, String>{
      'from': ?from,
      'to': ?to,
    };
    return get('/api/v1/school-days/holidays', queryParameters: query);
  }

  Future<dynamic> addSchoolHoliday({
    required String holidayDate,
    required String title,
    String? description,
    bool isHoliday = true,
  }) {
    return post('/api/v1/school-days/holidays', {
      'holiday_date': holidayDate,
      'title': title,
      'description': description,
      'is_holiday': isHoliday,
    });
  }

  Future<dynamic> deleteSchoolHoliday(String holidayId) {
    return delete('/api/v1/school-days/holidays/$holidayId');
  }
}



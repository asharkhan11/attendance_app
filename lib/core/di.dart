import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/teacher/data/datasources/teacher_datasource.dart';
import '../features/teacher/data/repositories/teacher_repository_impl.dart';
import '../features/teacher/domain/repositories/teacher_repository.dart';
import '../services/api_service.dart';

/// Singleton ApiService provider
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

/// Teacher Datasource provider
final teacherDatasourceProvider = Provider<TeacherDatasource>((ref) {
  return TeacherDatasource(ref.watch(apiServiceProvider));
});

/// Teacher Repository provider
final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  return TeacherRepositoryImpl(ref.watch(teacherDatasourceProvider));
});

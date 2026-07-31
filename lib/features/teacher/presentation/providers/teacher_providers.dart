import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di.dart';
import '../../../../models/app_models.dart';
import '../../domain/repositories/teacher_repository.dart';
import 'teacher_state.dart';

final teacherDashboardProvider = StateNotifierProvider.autoDispose<
    TeacherDashboardNotifier, AsyncValue<TeacherDashboardState>>((ref) {
  return TeacherDashboardNotifier(ref.watch(teacherRepositoryProvider));
});

class TeacherDashboardNotifier
    extends StateNotifier<AsyncValue<TeacherDashboardState>> {
  final TeacherRepository _repository;

  TeacherDashboardNotifier(this._repository)
      : super(AsyncValue.data(TeacherDashboardState(
          selectedDate: DateTime.now(),
        )));

  Future<void> loadDashboard(SchoolClass schoolClass, DateTime date) async {
    state = const AsyncValue.loading();
    final result = await _repository.getDashboard(
      classId: schoolClass.id,
      month: date,
    );

    result.when(
      success: (data) {
        state = AsyncValue.data(TeacherDashboardState(
          selectedClass: schoolClass,
          selectedDate: date,
          data: data,
        ));
      },
      failure: (error) {
        state = AsyncValue.error(error.message, StackTrace.current);
      },
    );
  }

  void selectClass(SchoolClass schoolClass) {
    final current = state.valueOrNull;
    if (current != null) {
      loadDashboard(schoolClass, current.selectedDate);
    }
  }

  void selectDate(DateTime date) {
    final current = state.valueOrNull;
    if (current != null && current.selectedClass != null) {
      loadDashboard(current.selectedClass!, date);
    }
  }
}

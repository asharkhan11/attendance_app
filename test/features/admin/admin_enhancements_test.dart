import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/app_models.dart';
import 'package:attendance_app/features/admin/presentation/widgets/admin_navigation.dart';

void main() {
  group('Admin Navigation & Tab Destinations Tests', () {
    test('AdminNavigation has 9 destinations with expected labels and order', () {
      final dests = AdminNavigation.navDestinations;
      expect(dests.length, 9);
      expect(dests[0].label, 'Overview');
      expect(dests[1].label, 'Academic Session');
      expect(dests[2].label, 'Attendance Session');
      expect(dests[3].label, 'Analytics');
      expect(dests[4].label, 'Classes');
      expect(dests[5].label, 'Students');
      expect(dests[6].label, 'Teachers');
      expect(dests[7].label, 'Reports');
      expect(dests[8].label, 'School Days');
    });
  });

  group('AttendanceSession Model Tests', () {
    test('Parses AttendanceSession json with is_finalized and finalized_at', () {
      final json = {
        'id': 'sess-123',
        'class_id': 'cls-456',
        'teacher_id': 'teach-789',
        'session_date': '2026-08-19T00:00:00Z',
        'period_number': 2,
        'status': 'closed',
        'is_finalized': true,
        'finalized_at': '2026-08-19T10:30:00Z',
      };

      final session = AttendanceSession.fromJson(json);
      expect(session.id, 'sess-123');
      expect(session.classId, 'cls-456');
      expect(session.teacherId, 'teach-789');
      expect(session.sessionDate, '2026-08-19T00:00:00Z');
      expect(session.periodNumber, 2);
      expect(session.status, 'closed');
      expect(session.isFinalized, isTrue);
      expect(session.finalizedAt, '2026-08-19T10:30:00Z');
    });

    test('Parses open AttendanceSession with default fallback values', () {
      final json = {
        'id': 'sess-999',
        'class_id': 'cls-111',
        'teacher_id': 'teach-222',
        'session_date': '2026-08-20',
        'period_number': 1,
        'status': 'open',
      };

      final session = AttendanceSession.fromJson(json);
      expect(session.id, 'sess-999');
      expect(session.status, 'open');
      expect(session.isFinalized, isFalse);
      expect(session.finalizedAt, isNull);
    });
  });

  group('SchoolClass and Student CSV Alignment Tests', () {
    test('SchoolClass model has id available for display and copy', () {
      final json = {
        'id': 'c-101-uuid',
        'school_id': 's-1',
        'academic_year_id': 'y-1',
        'grade_level': 10,
        'section': 'A',
      };
      final sc = SchoolClass.fromJson(json);
      expect(sc.id, 'c-101-uuid');
      expect(sc.gradeLevel, 10);
      expect(sc.section, 'A');
    });

    test('Student model matches export columns structure', () {
      final json = {
        'id': 'st-1',
        'school_id': 'sch-1',
        'class_id': 'cls-1',
        'admission_number': 'ADM001',
        'roll_number': '12',
        'full_name': 'Rohan Sharma',
        'gender': 'male',
        'dob': '2010-05-15',
        'guardian_name': 'Rajesh Sharma',
        'guardian_phone': '9876543210',
      };
      final student = Student.fromJson(json);
      expect(student.classId, 'cls-1');
      expect(student.admissionNumber, 'ADM001');
      expect(student.rollNumber, '12');
      expect(student.fullName, 'Rohan Sharma');
      expect(student.gender, 'male');
      expect(student.dob, '2010-05-15');
      expect(student.guardianName, 'Rajesh Sharma');
      expect(student.guardianPhone, '9876543210');
    });
  });
}

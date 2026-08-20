class User {
  final String id;
  final String schoolId;
  final String role;
  final String fullName;
  final String email;
  final String? phone;
  final bool isActive;

  User({
    required this.id,
    required this.schoolId,
    required this.role,
    required this.fullName,
    required this.email,
    this.phone,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      schoolId: json['school_id'] ?? '',
      role: json['role'] ?? '',
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      isActive: json['is_active'] ?? true,
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isTeacher => role == 'teacher';
}

class AcademicYear {
  final String id;
  final String schoolId;
  final String name;
  final String startDate;
  final String endDate;
  final bool isCurrent;
  final bool isArchived;

  AcademicYear({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    required this.isArchived,
  });

  factory AcademicYear.fromJson(Map<String, dynamic> json) {
    String startDate = json['start_date'] as String? ?? '';
    String endDate = json['end_date'] as String? ?? '';
    if (startDate.contains('T')) startDate = startDate.split('T')[0];
    if (endDate.contains('T')) endDate = endDate.split('T')[0];
    return AcademicYear(
      id: json['id'] as String,
      schoolId: json['school_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      startDate: startDate,
      endDate: endDate,
      isCurrent: json['is_current'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'school_id': schoolId,
        'name': name,
        'start_date': startDate,
        'end_date': endDate,
        'is_current': isCurrent,
        'is_archived': isArchived,
      };
}

class SchoolClass {
  final String id;
  final String schoolId;
  final String academicYearId;
  final int gradeLevel;
  final String section;
  final String? classTeacherId;
  final String? classTeacherName;
  final String? classTeacherEmail;

  SchoolClass({
    required this.id,
    required this.schoolId,
    required this.academicYearId,
    required this.gradeLevel,
    required this.section,
    this.classTeacherId,
    this.classTeacherName,
    this.classTeacherEmail,
  });

  String get displayName => gradeLevel > 0 && section.isNotEmpty
      ? 'Grade $gradeLevel-$section'
      : 'Class $id';

  factory SchoolClass.fromJson(Map<String, dynamic> json) {
    return SchoolClass(
      id: json['id'] ?? '',
      schoolId: json['school_id'] ?? '',
      academicYearId: json['academic_year_id'] ?? '',
      gradeLevel: (json['grade_level'] as num?)?.toInt() ?? 0,
      section: json['section'] ?? '',
      classTeacherId: json['class_teacher_id'],
      classTeacherName: json['class_teacher_name'],
      classTeacherEmail: json['class_teacher_email'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'grade_level': gradeLevel,
        'section': section,
        'class_teacher_id': classTeacherId,
        'class_teacher_name': classTeacherName,
        'class_teacher_email': classTeacherEmail,
      };
}

class Student {
  final String id;
  final String? schoolId;
  final String classId;
  final String admissionNumber;
  final String rollNumber;
  final String fullName;
  final String? gender;
  final String? dob;
  final String? guardianName;
  final String? guardianPhone;
  final bool isActive;
  final String? createdAt;

  Student({
    required this.id,
    required this.classId,
    required this.admissionNumber,
    required this.rollNumber,
    required this.fullName,
    this.schoolId,
    this.gender,
    this.dob,
    this.guardianName,
    this.guardianPhone,
    this.isActive = true,
    this.createdAt,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    String? dob = json['dob'] as String?;
    if (dob != null && dob.isNotEmpty && dob.contains('T')) {
      dob = dob.split('T')[0];
    }
    return Student(
      id: json['id'] ?? '',
      schoolId: json['school_id'],
      classId: json['class_id'] ?? '',
      admissionNumber: json['admission_number']?.toString() ?? '',
      rollNumber: json['roll_number']?.toString() ?? '',
      fullName: json['full_name'] ?? '',
      gender: json['gender'],
      dob: dob,
      guardianName: json['guardian_name'],
      guardianPhone: json['guardian_phone'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'school_id': schoolId,
        'class_id': classId,
        'admission_number': admissionNumber,
        'roll_number': rollNumber,
        'full_name': fullName,
        'gender': gender,
        'dob': dob,
        'guardian_name': guardianName,
        'guardian_phone': guardianPhone,
        'is_active': isActive,
        'created_at': createdAt,
      };
}

class AttendanceSession {
  final String id;
  final String classId;
  final String teacherId;
  final String sessionDate;
  final int periodNumber;
  final String status;
  final bool isFinalized;
  final String? finalizedAt;

  AttendanceSession({
    required this.id,
    required this.classId,
    required this.teacherId,
    required this.sessionDate,
    required this.periodNumber,
    required this.status,
    this.isFinalized = false,
    this.finalizedAt,
  });

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    return AttendanceSession(
      id: json['id'] ?? '',
      classId: json['class_id'] ?? '',
      teacherId: json['teacher_id'] ?? '',
      sessionDate: json['session_date'] ?? '',
      periodNumber: (json['period_number'] as num?)?.toInt() ?? 1,
      status: json['status'] ?? 'open',
      isFinalized: json['is_finalized'] == true,
      finalizedAt: json['finalized_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'class_id': classId,
        'teacher_id': teacherId,
        'session_date': sessionDate,
        'period_number': periodNumber,
        'status': status,
        'is_finalized': isFinalized,
        'finalized_at': finalizedAt,
      };
}

class RosterEntry {
  final String studentId;
  final String fullName;
  final String rollNumber;
  String status;
  String? remarks;

  RosterEntry({
    required this.studentId,
    required this.fullName,
    required this.rollNumber,
    this.status = 'present',
    this.remarks,
  });

  factory RosterEntry.fromJson(Map<String, dynamic> json) {
    return RosterEntry(
      studentId: json['student_id'] ?? '',
      fullName: json['full_name'] ?? '',
      rollNumber: json['roll_number'] ?? '',
      status: json['status'] ?? 'present',
      remarks: json['remarks'],
    );
  }

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'full_name': fullName,
        'roll_number': rollNumber,
        'status': status,
        'remarks': remarks,
      };
}

class ClassSummary {
  final String classId;
  final int totalSessions;
  final int totalRecords;
  final int present;
  final int absent;
  final int late;
  final int excused;
  final double attendancePercentage;

  ClassSummary({
    required this.classId,
    required this.totalSessions,
    required this.totalRecords,
    required this.present,
    required this.absent,
    required this.late,
    required this.excused,
    required this.attendancePercentage,
  });

  factory ClassSummary.fromJson(Map<String, dynamic> json) {
    return ClassSummary(
      classId: json['class_id'] ?? '',
      totalSessions: json['total_sessions'] ?? 0,
      totalRecords: json['total_records'] ?? 0,
      present: json['present'] ?? 0,
      absent: json['absent'] ?? 0,
      late: json['late'] ?? 0,
      excused: json['excused'] ?? 0,
      attendancePercentage: (json['attendance_percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Defaulter {
  final String studentId;
  final String fullName;
  final String rollNumber;
  final int totalSessions;
  final int present;
  final int absent;
  final double attendancePercentage;

  Defaulter({
    required this.studentId,
    required this.fullName,
    required this.rollNumber,
    required this.totalSessions,
    required this.present,
    required this.absent,
    required this.attendancePercentage,
  });

  factory Defaulter.fromJson(Map<String, dynamic> json) {
    return Defaulter(
      studentId: json['student_id'] ?? '',
      fullName: json['full_name'] ?? '',
      rollNumber: json['roll_number']?.toString() ?? '',
      totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
      present: (json['present'] as num?)?.toInt() ?? 0,
      absent: (json['absent'] as num?)?.toInt() ?? 0,
      attendancePercentage: (json['attendance_percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class WeeklyDaySchedule {
  final String? id;
  final String? schoolId;
  final int dayOfWeek; // 0 = Sunday, 1 = Monday, ..., 6 = Saturday
  final String dayName;
  final bool isWorkingDay;

  WeeklyDaySchedule({
    this.id,
    this.schoolId,
    required this.dayOfWeek,
    required this.dayName,
    required this.isWorkingDay,
  });

  factory WeeklyDaySchedule.fromJson(Map<String, dynamic> json) {
    return WeeklyDaySchedule(
      id: json['id'] as String?,
      schoolId: json['school_id'] as String?,
      dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 0,
      dayName: json['day_name'] ?? '',
      isWorkingDay: json['is_working_day'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'day_of_week': dayOfWeek,
        'is_working_day': isWorkingDay,
      };

  WeeklyDaySchedule copyWith({bool? isWorkingDay}) {
    return WeeklyDaySchedule(
      id: id,
      schoolId: schoolId,
      dayOfWeek: dayOfWeek,
      dayName: dayName,
      isWorkingDay: isWorkingDay ?? this.isWorkingDay,
    );
  }
}

class SchoolHoliday {
  final String id;
  final String schoolId;
  final String holidayDate; // YYYY-MM-DD
  final String title;
  final String? description;
  final bool isHoliday;

  SchoolHoliday({
    required this.id,
    required this.schoolId,
    required this.holidayDate,
    required this.title,
    this.description,
    required this.isHoliday,
  });

  factory SchoolHoliday.fromJson(Map<String, dynamic> json) {
    return SchoolHoliday(
      id: json['id'] ?? '',
      schoolId: json['school_id'] ?? '',
      holidayDate: (json['holiday_date'] as String? ?? '').split('T')[0],
      title: json['title'] ?? '',
      description: json['description'],
      isHoliday: json['is_holiday'] ?? true,
    );
  }
}


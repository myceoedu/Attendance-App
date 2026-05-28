import 'package:flutter/foundation.dart';

enum MonthlyAttendanceReviewState { clean, noAttendance }

class MonthlyAttendanceSummary {
  final String employeeId;
  final String employeeName;
  final String username;
  final String email;
  final int totalAttendanceRecords;
  final int completedAttendanceDays;
  final int openAttendanceDays;
  final int approvedLeaveDays;
  final DateTime? lastAttendanceDate;

  const MonthlyAttendanceSummary({
    required this.employeeId,
    required this.employeeName,
    required this.username,
    required this.email,
    required this.totalAttendanceRecords,
    required this.completedAttendanceDays,
    required this.openAttendanceDays,
    required this.approvedLeaveDays,
    required this.lastAttendanceDate,
  });

  String get displayName {
    if (employeeName.trim().isNotEmpty) return employeeName.trim();
    if (username.trim().isNotEmpty) return username.trim();
    if (email.trim().isNotEmpty) return email.trim();
    return 'Employee';
  }

  bool get hasNoAttendance =>
      reviewState == MonthlyAttendanceReviewState.noAttendance;
  bool get isClean => reviewState == MonthlyAttendanceReviewState.clean;

  MonthlyAttendanceReviewState get reviewState {
    if (completedAttendanceDays == 0) {
      return MonthlyAttendanceReviewState.noAttendance;
    }
    return MonthlyAttendanceReviewState.clean;
  }

  String get reviewStateLabel {
    switch (reviewState) {
      case MonthlyAttendanceReviewState.clean:
        return 'Clean';
      case MonthlyAttendanceReviewState.noAttendance:
        return 'No Attendance';
    }
  }

  String? get reviewMessage {
    if (completedAttendanceDays == 0) {
      return 'No completed attendance recorded for this month';
    }
    return null;
  }

  MonthlyAttendanceSummary copyWith({
    String? employeeId,
    String? employeeName,
    String? username,
    String? email,
    int? totalAttendanceRecords,
    int? completedAttendanceDays,
    int? openAttendanceDays,
    int? approvedLeaveDays,
    ValueGetter<DateTime?>? lastAttendanceDate,
  }) {
    return MonthlyAttendanceSummary(
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      username: username ?? this.username,
      email: email ?? this.email,
      totalAttendanceRecords:
          totalAttendanceRecords ?? this.totalAttendanceRecords,
      completedAttendanceDays:
          completedAttendanceDays ?? this.completedAttendanceDays,
      openAttendanceDays: openAttendanceDays ?? this.openAttendanceDays,
      approvedLeaveDays: approvedLeaveDays ?? this.approvedLeaveDays,
      lastAttendanceDate: lastAttendanceDate != null
          ? lastAttendanceDate()
          : this.lastAttendanceDate,
    );
  }
}

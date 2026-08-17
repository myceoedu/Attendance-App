import 'package:flutter/foundation.dart';

import '../utils/monthly_attendance_rollup.dart';

enum MonthlyAttendanceReviewState { clean, hasMia, noAttendance }

/// One employee row for admin Monthly Attendance (month rollup).
class MonthlyAttendanceSummary {
  final String employeeId;
  final String employeeName;
  final String username;
  final String email;

  /// Staffing column — department name.
  final String department;

  /// First clock-in date in the selected month (Reporting On).
  final DateTime? reportingOn;

  /// Weekday completed attendance credit (full=1, half=0.5).
  final double attendDays;

  /// Approved non-sick leave on weekdays (half annual = 0.5).
  final double leaveDays;

  /// Approved sick (MC) leave on weekdays.
  final double mcDays;

  /// max(0, totalWorkingDays − attend − leave − mc).
  final double miaDays;

  /// Distinct Saturdays with completed attendance (optional / not expected).
  final int saturdayAttendCount;

  /// Mon–Fri days expected in the month window.
  final int totalWorkingDays;

  /// Open (still clocked-in) sessions in the month.
  final int openAttendanceDays;

  /// Admin-editable notes for this employee/month (blank by default).
  final String notes;

  final DateTime? lastAttendanceDate;

  /// Distinct calendar days with any completed session (incl. Sat). For sorting.
  final int completedAttendanceDays;

  const MonthlyAttendanceSummary({
    required this.employeeId,
    required this.employeeName,
    required this.username,
    required this.email,
    required this.department,
    required this.reportingOn,
    required this.attendDays,
    required this.leaveDays,
    required this.mcDays,
    required this.miaDays,
    required this.saturdayAttendCount,
    required this.totalWorkingDays,
    required this.openAttendanceDays,
    required this.notes,
    required this.lastAttendanceDate,
    required this.completedAttendanceDays,
  });

  String get displayName {
    if (employeeName.trim().isNotEmpty) return employeeName.trim();
    if (username.trim().isNotEmpty) return username.trim();
    if (email.trim().isNotEmpty) return email.trim();
    return 'Employee';
  }

  String get staffingLabel =>
      department.trim().isEmpty ? '—' : department.trim();

  String get attendDaysLabel => MonthlyAttendanceRollup.formatDays(attendDays);
  String get leaveDaysLabel => MonthlyAttendanceRollup.formatDays(leaveDays);
  String get mcDaysLabel => MonthlyAttendanceRollup.formatDays(mcDays);
  String get miaDaysLabel => MonthlyAttendanceRollup.formatDays(miaDays);

  bool get hasNoAttendance =>
      reviewState == MonthlyAttendanceReviewState.noAttendance;
  bool get isClean => reviewState == MonthlyAttendanceReviewState.clean;
  bool get hasMia => reviewState == MonthlyAttendanceReviewState.hasMia;

  bool get saturdayOverLimit =>
      saturdayAttendCount > MonthlyAttendanceRollup.saturdaySoftCap;

  MonthlyAttendanceReviewState get reviewState {
    if (attendDays <= 0 && saturdayAttendCount == 0) {
      return MonthlyAttendanceReviewState.noAttendance;
    }
    if (miaDays > 0 || openAttendanceDays > 0) {
      return MonthlyAttendanceReviewState.hasMia;
    }
    return MonthlyAttendanceReviewState.clean;
  }

  String get reviewStateLabel {
    switch (reviewState) {
      case MonthlyAttendanceReviewState.clean:
        return 'Clean';
      case MonthlyAttendanceReviewState.hasMia:
        return 'Has MIA';
      case MonthlyAttendanceReviewState.noAttendance:
        return 'No Attendance';
    }
  }

  /// CSV / table cell helpers.
  static const csvHeaders = <String>[
    'Staffing',
    'Name',
    'Reporting On',
    'Attend Days',
    'Leave',
    'MC',
    'MIA',
    'Attend Sat',
    'Total Working Days',
    'Notes',
  ];

  List<String> toCsvCells({required String Function(DateTime date) formatDate}) {
    return [
      staffingLabel == '—' ? '' : staffingLabel,
      displayName,
      reportingOn == null ? '' : formatDate(reportingOn!),
      attendDaysLabel,
      leaveDaysLabel,
      mcDaysLabel,
      miaDaysLabel,
      '$saturdayAttendCount',
      '$totalWorkingDays',
      notes,
    ];
  }

  MonthlyAttendanceSummary copyWith({
    String? employeeId,
    String? employeeName,
    String? username,
    String? email,
    String? department,
    ValueGetter<DateTime?>? reportingOn,
    double? attendDays,
    double? leaveDays,
    double? mcDays,
    double? miaDays,
    int? saturdayAttendCount,
    int? totalWorkingDays,
    int? openAttendanceDays,
    String? notes,
    ValueGetter<DateTime?>? lastAttendanceDate,
    int? completedAttendanceDays,
  }) {
    return MonthlyAttendanceSummary(
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      username: username ?? this.username,
      email: email ?? this.email,
      department: department ?? this.department,
      reportingOn: reportingOn != null ? reportingOn() : this.reportingOn,
      attendDays: attendDays ?? this.attendDays,
      leaveDays: leaveDays ?? this.leaveDays,
      mcDays: mcDays ?? this.mcDays,
      miaDays: miaDays ?? this.miaDays,
      saturdayAttendCount: saturdayAttendCount ?? this.saturdayAttendCount,
      totalWorkingDays: totalWorkingDays ?? this.totalWorkingDays,
      openAttendanceDays: openAttendanceDays ?? this.openAttendanceDays,
      notes: notes ?? this.notes,
      lastAttendanceDate: lastAttendanceDate != null
          ? lastAttendanceDate()
          : this.lastAttendanceDate,
      completedAttendanceDays:
          completedAttendanceDays ?? this.completedAttendanceDays,
    );
  }
}

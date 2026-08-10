import 'attendance.dart';
import 'leave_request.dart';

enum EmployeeCalendarDayState { none, completed, inProgress, leave }

/// One day on the attendance calendar.
class EmployeeCalendarDay {
  final DateTime date;
  final List<Attendance> attendanceRecords;
  final LeaveRequest? approvedLeave;
  final bool isToday;

  final bool hasCompletedAttendance;
  final bool hasOpenAttendance;

  /// Best attendance row for this day (completed first, then latest).
  final Attendance? primaryAttendance;

  const EmployeeCalendarDay._({
    required this.date,
    required this.attendanceRecords,
    required this.approvedLeave,
    required this.isToday,
    required this.hasCompletedAttendance,
    required this.hasOpenAttendance,
    required this.primaryAttendance,
  });

  factory EmployeeCalendarDay({
    required DateTime date,
    required List<Attendance> attendanceRecords,
    required LeaveRequest? approvedLeave,
    required bool isToday,
  }) {
    var hasCompleted = false;
    var hasOpen = false;
    Attendance? primary;

    for (final record in attendanceRecords) {
      if (record.status == 'completed') {
        hasCompleted = true;
      } else if (record.status == 'in_progress') {
        hasOpen = true;
      }
      if (primary == null || _preferOver(record, primary)) {
        primary = record;
      }
    }

    return EmployeeCalendarDay._(
      date: date,
      attendanceRecords: attendanceRecords,
      approvedLeave: approvedLeave,
      isToday: isToday,
      hasCompletedAttendance: hasCompleted,
      hasOpenAttendance: hasOpen,
      primaryAttendance: primary,
    );
  }

  static bool _preferOver(Attendance candidate, Attendance current) {
    if (candidate.status == current.status) {
      final candidateTime =
          candidate.clockOutTime ?? candidate.clockInTime ?? candidate.date;
      final currentTime =
          current.clockOutTime ?? current.clockInTime ?? current.date;
      return candidateTime.isAfter(currentTime);
    }
    return candidate.status == 'completed';
  }

  bool get hasAttendance => attendanceRecords.isNotEmpty;
  bool get hasApprovedLeave => approvedLeave != null;

  /// Leave overrides attendance in the grid and summary counts.
  bool get isCountedAsPresentDay => hasCompletedAttendance && !hasApprovedLeave;
  bool get isCountedAsOpenDay => hasOpenAttendance && !hasApprovedLeave;

  EmployeeCalendarDayState get state {
    if (hasApprovedLeave) return EmployeeCalendarDayState.leave;
    if (hasOpenAttendance) return EmployeeCalendarDayState.inProgress;
    if (hasCompletedAttendance) return EmployeeCalendarDayState.completed;
    return EmployeeCalendarDayState.none;
  }

  String get stateLabel {
    switch (state) {
      case EmployeeCalendarDayState.completed:
        return 'Attended';
      case EmployeeCalendarDayState.inProgress:
        return 'In Progress';
      case EmployeeCalendarDayState.leave:
        return approvedLeave?.leaveTypeDisplay ?? 'Approved Leave';
      case EmployeeCalendarDayState.none:
        return 'No record';
    }
  }
}

class EmployeeMonthlyCalendarData {
  final DateTime month;
  final List<EmployeeCalendarDay> days;

  EmployeeMonthlyCalendarData({required this.month, required this.days});

  /// O(1) lookup by calendar date.
  late final Map<int, EmployeeCalendarDay> _byDate = {
    for (final day in days)
      _key(day.date.year, day.date.month, day.date.day): day,
  };

  static int _key(int year, int month, int day) =>
      year * 10000 + month * 100 + day;

  late final int presentDayCount = days
      .where((day) => day.isCountedAsPresentDay)
      .length;

  late final int leaveDayCount = days
      .where((day) => day.hasApprovedLeave)
      .length;

  late final int openDayCount = days
      .where((day) => day.isCountedAsOpenDay)
      .length;

  /// Unique leave requests in this month.
  late final List<LeaveRequest> monthLeaves = () {
    final seen = <String>{};
    final result = <LeaveRequest>[];
    for (final day in days) {
      final leave = day.approvedLeave;
      if (leave != null && seen.add(leave.id)) {
        result.add(leave);
      }
    }
    return List<LeaveRequest>.unmodifiable(result);
  }();

  EmployeeCalendarDay? dayFor(DateTime date) =>
      _byDate[_key(date.year, date.month, date.day)];
}

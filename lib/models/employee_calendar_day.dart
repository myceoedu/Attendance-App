import 'attendance.dart';
import 'leave_request.dart';

enum EmployeeCalendarDayState { none, completed, inProgress, leave }

class EmployeeCalendarDay {
  final DateTime date;
  final List<Attendance> attendanceRecords;
  final LeaveRequest? approvedLeave;
  final bool isToday;

  const EmployeeCalendarDay({
    required this.date,
    required this.attendanceRecords,
    required this.approvedLeave,
    required this.isToday,
  });

  bool get hasAttendance => attendanceRecords.isNotEmpty;
  bool get hasApprovedLeave => approvedLeave != null;
  bool get hasCompletedAttendance =>
      attendanceRecords.any((record) => record.status == 'completed');
  bool get hasOpenAttendance =>
      attendanceRecords.any((record) => record.status == 'in_progress');

  /// Days with both attendance and approved leave: leave wins visually and in
  /// summary totals so Present + Leave matches the calendar grid.
  bool get isCountedAsPresentDay =>
      hasCompletedAttendance && !hasApprovedLeave;
  bool get isCountedAsOpenDay => hasOpenAttendance && !hasApprovedLeave;

  Attendance? get primaryAttendance {
    if (attendanceRecords.isEmpty) return null;
    final sorted = List<Attendance>.from(attendanceRecords)
      ..sort((a, b) {
        if (a.status == b.status) {
          final aTime = a.clockOutTime ?? a.clockInTime ?? a.date;
          final bTime = b.clockOutTime ?? b.clockInTime ?? b.date;
          return bTime.compareTo(aTime);
        }
        if (a.status == 'completed') return -1;
        if (b.status == 'completed') return 1;
        return 0;
      });
    return sorted.first;
  }

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

  const EmployeeMonthlyCalendarData({required this.month, required this.days});

  EmployeeCalendarDay? dayFor(DateTime date) {
    for (final day in days) {
      if (day.date.year == date.year &&
          day.date.month == date.month &&
          day.date.day == date.day) {
        return day;
      }
    }
    return null;
  }
}

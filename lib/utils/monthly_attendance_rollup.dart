import '../models/app_user.dart';
import '../models/attendance.dart';
import '../models/leave_request.dart';
import '../models/monthly_attendance_summary.dart';
import 'app_time.dart';
import 'attendance_work_rules.dart';
import 'leave_catalog.dart';

/// Pure month rollup for admin Monthly Attendance (table + CSV).
///
/// Rules:
/// - Total working days = Mon–Fri only (Sat optional / not expected).
/// - Attend days = weekday sessions (completed full/half, or open/forgot
///   clock-out inferred from clock-in time).
/// - Saturday sessions → [MonthlyAttendanceSummary.saturdayAttendCount] only.
/// - Leave vs MC split; half-day annual leave = 0.5.
/// - MIA = max(0, working − attend − leave − mc).
abstract final class MonthlyAttendanceRollup {
  static const int saturdaySoftCap = 2;

  /// Format day counts for UI/CSV (e.g. `18`, `18.5`).
  static String formatDays(double value) {
    final rounded = _roundTenths(value);
    if (rounded == rounded.roundToDouble()) {
      return rounded.round().toString();
    }
    return rounded.toStringAsFixed(1);
  }

  /// Mon–Fri days in [month] from [fromDate] through [throughDate] (inclusive).
  static int workingWeekdaysInRange({
    required DateTime month,
    required DateTime fromDate,
    required DateTime throughDate,
  }) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);

    var start = _dateOnly(fromDate);
    var end = _dateOnly(throughDate);
    if (start.isBefore(monthStart)) start = monthStart;
    if (end.isAfter(monthEnd)) end = monthEnd;
    if (end.isBefore(start)) return 0;

    var count = 0;
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      if (_isWeekday(d)) count++;
    }
    return count;
  }

  /// Credit for one attendance row (0 / 0.5 / 1).
  ///
  /// Completed: uses [AttendanceWorkRules.sessionKind].
  /// Open (`in_progress`, forgot clock-out): inferred from Malaysia clock-in —
  /// before 1:00 PM → full day (1), at/after 1:00 PM → half day PM (0.5).
  static double attendCreditForRecord(Attendance record) {
    if (record.status == 'completed') {
      switch (AttendanceWorkRules.sessionKind(record)) {
        case AttendanceSessionKind.fullDay:
          return 1;
        case AttendanceSessionKind.halfDayAm:
        case AttendanceSessionKind.halfDayPm:
          return 0.5;
        case AttendanceSessionKind.unknown:
          return 0;
      }
    }

    if (record.status == 'in_progress') {
      return openSessionAttendCredit(record);
    }

    return 0;
  }

  /// Forgot clock-out: still counts as attended from clock-in time.
  static double openSessionAttendCredit(Attendance record) {
    final clockIn = record.clockInTime;
    if (clockIn == null) return 0;
    final inM = _minutesOfDay(AppTime.toMalaysia(clockIn));
    // Started at/after lunch (1:00 PM) → afternoon half only.
    if (inM >= AttendanceWorkRules.morningEndMinutes) return 0.5;
    return 1;
  }

  /// Leave day credit for a single calendar day covered by [leave].
  static double leaveDayCredit(LeaveRequest leave) {
    if (LeaveCatalog.isHalfDayAnnual(leave.leaveType)) return 0.5;
    return 1;
  }

  static MonthlyAttendanceSummary summarizeEmployee({
    required AppUser employee,
    required DateTime month,
    required List<Attendance> records,
    required List<LeaveRequest> approvedLeaves,
    required DateTime today,
    String notes = '',
  }) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    final todayDate = _dateOnly(today);

    final employmentStart = employee.employmentStartDate == null
        ? null
        : _dateOnly(employee.employmentStartDate!);

    // Expected window: from employment start (or month start) through today
    // for the current month, else full month. Future weekdays never create MIA.
    var windowStart = monthStart;
    if (employmentStart != null && employmentStart.isAfter(windowStart)) {
      windowStart = employmentStart;
    }

    var windowEnd = monthEnd;
    if (todayDate.isBefore(windowEnd) &&
        todayDate.year == month.year &&
        todayDate.month == month.month) {
      windowEnd = todayDate;
    }
    // Past months: full month. Future months: empty window.
    if (monthStart.isAfter(todayDate)) {
      windowEnd = monthStart.subtract(const Duration(days: 1));
    }

    final totalWorkingDays = workingWeekdaysInRange(
      month: month,
      fromDate: windowStart,
      throughDate: windowEnd,
    );

    // Completed wins over open on the same weekday (real clock-out preferred).
    final weekdayCompletedByDate = <String, double>{};
    final weekdayOpenByDate = <String, double>{};
    final saturdayDates = <String>{};
    final openSessionDates = <String>{};
    DateTime? firstAttendanceDate;
    DateTime? lastAttendanceDate;

    for (final record in records) {
      final date = _dateOnly(record.date);
      if (date.year != month.year || date.month != month.month) continue;

      final isOpen = record.status == 'in_progress';
      final isCompleted = record.status == 'completed';
      if (!isOpen && !isCompleted) continue;

      if (firstAttendanceDate == null || date.isBefore(firstAttendanceDate)) {
        firstAttendanceDate = date;
      }
      if (lastAttendanceDate == null || date.isAfter(lastAttendanceDate)) {
        lastAttendanceDate = date;
      }

      final key = _key(date);
      if (isOpen) openSessionDates.add(key);

      final credit = attendCreditForRecord(record);
      if (credit <= 0) continue;

      if (date.weekday == DateTime.saturday) {
        saturdayDates.add(key);
        continue;
      }
      if (!_isWeekday(date)) continue;

      if (isCompleted) {
        final existing = weekdayCompletedByDate[key] ?? 0;
        if (credit > existing) weekdayCompletedByDate[key] = credit;
      } else {
        final existing = weekdayOpenByDate[key] ?? 0;
        if (credit > existing) weekdayOpenByDate[key] = credit;
      }
    }

    final weekdayAttendByDate = <String, double>{};
    for (final e in weekdayOpenByDate.entries) {
      weekdayAttendByDate[e.key] = e.value;
    }
    for (final e in weekdayCompletedByDate.entries) {
      weekdayAttendByDate[e.key] = e.value; // completed overrides open
    }

    final openAttendanceDays = openSessionDates.length;

    var attendDays = 0.0;
    var attendInWindow = 0.0;
    for (final entry in weekdayAttendByDate.entries) {
      attendDays += entry.value;
      final date = DateTime.parse(entry.key);
      if (!date.isBefore(windowStart) && !date.isAfter(windowEnd)) {
        attendInWindow += entry.value;
      }
    }
    attendDays = _roundTenths(attendDays);
    attendInWindow = _roundTenths(attendInWindow);

    // Leave / MC: weekday days in month from employment start (include future
    // days in the month for the Leave/MC columns). MIA uses the elapsed window.
    final leaveByDate = <String, double>{};
    final mcByDate = <String, double>{};
    for (final leave in approvedLeaves) {
      if (leave.userId != employee.id) continue;
      if (leave.status.toLowerCase() != 'approved') continue;

      final isMc = leave.leaveType == LeaveCatalog.sick;
      final credit = leaveDayCredit(leave);
      for (final day in _eachDayInclusive(leave.startDate, leave.endDate)) {
        if (day.year != month.year || day.month != month.month) continue;
        if (!_isWeekday(day)) continue;
        if (employmentStart != null && day.isBefore(employmentStart)) continue;

        final key = _key(day);
        final bucket = isMc ? mcByDate : leaveByDate;
        final existing = bucket[key] ?? 0;
        if (credit > existing) bucket[key] = credit;
      }
    }

    var leaveDays = 0.0;
    var mcDays = 0.0;
    var leaveInWindow = 0.0;
    var mcInWindow = 0.0;
    for (final entry in leaveByDate.entries) {
      leaveDays += entry.value;
      final date = DateTime.parse(entry.key);
      if (!date.isBefore(windowStart) && !date.isAfter(windowEnd)) {
        leaveInWindow += entry.value;
      }
    }
    for (final entry in mcByDate.entries) {
      mcDays += entry.value;
      final date = DateTime.parse(entry.key);
      if (!date.isBefore(windowStart) && !date.isAfter(windowEnd)) {
        mcInWindow += entry.value;
      }
    }
    leaveDays = _roundTenths(leaveDays);
    mcDays = _roundTenths(mcDays);
    leaveInWindow = _roundTenths(leaveInWindow);
    mcInWindow = _roundTenths(mcInWindow);

    final miaRaw =
        totalWorkingDays - attendInWindow - leaveInWindow - mcInWindow;
    final miaDays = _roundTenths(miaRaw < 0 ? 0 : miaRaw);

    final saturdayAttendCount = saturdayDates.length;

    return MonthlyAttendanceSummary(
      employeeId: employee.id,
      employeeName: employee.name,
      username: employee.username,
      email: employee.email,
      department: employee.department?.trim() ?? '',
      // First clock-in date in this month (Reporting On).
      reportingOn: firstAttendanceDate,
      attendDays: attendDays,
      leaveDays: leaveDays,
      mcDays: mcDays,
      miaDays: miaDays,
      saturdayAttendCount: saturdayAttendCount,
      totalWorkingDays: totalWorkingDays,
      openAttendanceDays: openAttendanceDays,
      notes: notes,
      lastAttendanceDate: lastAttendanceDate,
      completedAttendanceDays: weekdayAttendByDate.length + saturdayAttendCount,
    );
  }

  static int _minutesOfDay(DateTime local) => local.hour * 60 + local.minute;

  static bool _isWeekday(DateTime d) =>
      d.weekday >= DateTime.monday && d.weekday <= DateTime.friday;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Iterable<DateTime> _eachDayInclusive(
    DateTime start,
    DateTime end,
  ) sync* {
    var d = _dateOnly(start);
    final last = _dateOnly(end);
    if (last.isBefore(d)) return;
    while (!d.isAfter(last)) {
      yield d;
      d = d.add(const Duration(days: 1));
    }
  }

  static double _roundTenths(double value) =>
      (value * 10).roundToDouble() / 10;
}

import '../models/attendance.dart';
import 'app_time.dart';

/// Company workday session from clock in/out (Malaysia time).
///
/// Schedule: 9:00–18:00 with break 13:00–14:00.
/// - Morning half: leave by lunch (out at/before 13:00, or during break)
/// - Afternoon half: start at/after 14:00
/// - Full day: start before 14:00 and leave after 14:00
enum AttendanceSessionKind { fullDay, halfDayAm, halfDayPm, unknown }

/// Shared rules for worked duration and AM/PM half-day detection.
class AttendanceWorkRules {
  AttendanceWorkRules._();

  /// Morning session ends / lunch starts (1:00 PM).
  static const int morningEndMinutes = 13 * 60;

  /// Afternoon session starts / lunch ends (2:00 PM).
  static const int afternoonStartMinutes = 14 * 60;

  static int _minutesOfDay(DateTime local) => local.hour * 60 + local.minute;

  static Duration? workedDuration(Attendance record) {
    final clockIn = record.clockInTime;
    final clockOut = record.clockOutTime;
    if (clockIn == null || clockOut == null) return null;
    if (!clockOut.isAfter(clockIn)) return null;
    return clockOut.difference(clockIn);
  }

  /// Classifies a completed day using Malaysia local clock times.
  static AttendanceSessionKind sessionKind(Attendance record) {
    final clockIn = record.clockInTime;
    final clockOut = record.clockOutTime;
    if (clockIn == null || clockOut == null) {
      return AttendanceSessionKind.unknown;
    }
    if (!clockOut.isAfter(clockIn)) return AttendanceSessionKind.unknown;

    final inM = _minutesOfDay(AppTime.toMalaysia(clockIn));
    final outM = _minutesOfDay(AppTime.toMalaysia(clockOut));

    // Left by lunch end (1pm) or during the 1–2 break → morning half only.
    if (outM <= afternoonStartMinutes) {
      return AttendanceSessionKind.halfDayAm;
    }

    // Started at/after 2pm → afternoon half only.
    if (inM >= afternoonStartMinutes) {
      return AttendanceSessionKind.halfDayPm;
    }

    // Started during the 1–2 break, then stayed for afternoon → PM half.
    if (inM >= morningEndMinutes) {
      return AttendanceSessionKind.halfDayPm;
    }

    // In before 1pm and out after 2pm → covered morning and afternoon.
    return AttendanceSessionKind.fullDay;
  }

  static bool isHalfDayWorked(Attendance record) {
    final kind = sessionKind(record);
    return kind == AttendanceSessionKind.halfDayAm ||
        kind == AttendanceSessionKind.halfDayPm;
  }

  static String? sessionShortLabel(Attendance record) {
    switch (sessionKind(record)) {
      case AttendanceSessionKind.halfDayAm:
        return 'Half day AM';
      case AttendanceSessionKind.halfDayPm:
        return 'Half day PM';
      case AttendanceSessionKind.fullDay:
        return 'Full day';
      case AttendanceSessionKind.unknown:
        return null;
    }
  }

  static String formatWorked(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours <= 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  static String? workedLabel(Attendance record) {
    final duration = workedDuration(record);
    if (duration == null) return null;
    final base = formatWorked(duration);
    switch (sessionKind(record)) {
      case AttendanceSessionKind.halfDayAm:
        return '$base (half day AM · 9–1)';
      case AttendanceSessionKind.halfDayPm:
        return '$base (half day PM · 2–6)';
      case AttendanceSessionKind.fullDay:
        return base;
      case AttendanceSessionKind.unknown:
        return base;
    }
  }
}

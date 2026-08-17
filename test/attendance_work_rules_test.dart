import 'package:attendance_app/models/attendance.dart';
import 'package:attendance_app/models/employee_calendar_day.dart';
import 'package:attendance_app/utils/attendance_work_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Build times as Malaysia wall-clock stored as UTC-8 offset timestamps
/// (same shape as AppTime.toMalaysia / fromMalaysia pipeline in the app).
DateTime _myt(int year, int month, int day, int hour, [int minute = 0]) {
  // Malaysia is UTC+8. AppTime.toMalaysia does utc.add(+8h), so store as
  // UTC = MYT - 8h for round-trip correctness.
  return DateTime.utc(year, month, day, hour, minute)
      .subtract(const Duration(hours: 8));
}

Attendance _record({
  required DateTime clockIn,
  DateTime? clockOut,
  String status = 'completed',
}) {
  return Attendance(
    id: 't1',
    userId: 'u1',
    clockInTime: clockIn,
    clockOutTime: clockOut,
    date: DateTime(2026, 8, 17),
    status: status,
  );
}

void main() {
  group('AttendanceWorkRules company schedule', () {
    test('open session is unknown / not half day', () {
      final record = _record(
        clockIn: _myt(2026, 8, 17, 9),
        status: 'in_progress',
      );
      expect(record.sessionKind, AttendanceSessionKind.unknown);
      expect(record.isHalfDayWorked, isFalse);
    });

    test('9:00–13:00 is half day AM', () {
      final record = _record(
        clockIn: _myt(2026, 8, 17, 9),
        clockOut: _myt(2026, 8, 17, 13),
      );
      expect(record.sessionKind, AttendanceSessionKind.halfDayAm);
      expect(record.isHalfDayWorked, isTrue);
      expect(record.sessionShortLabel, 'Half day AM');
      expect(record.workedLabel, contains('half day AM'));
    });

    test('9:00–13:30 (left during break) is half day AM', () {
      final record = _record(
        clockIn: _myt(2026, 8, 17, 9),
        clockOut: _myt(2026, 8, 17, 13, 30),
      );
      expect(record.sessionKind, AttendanceSessionKind.halfDayAm);
    });

    test('14:00–18:00 is half day PM', () {
      final record = _record(
        clockIn: _myt(2026, 8, 17, 14),
        clockOut: _myt(2026, 8, 17, 18),
      );
      expect(record.sessionKind, AttendanceSessionKind.halfDayPm);
      expect(record.sessionShortLabel, 'Half day PM');
    });

    test('13:30–18:00 (in during break) is half day PM', () {
      final record = _record(
        clockIn: _myt(2026, 8, 17, 13, 30),
        clockOut: _myt(2026, 8, 17, 18),
      );
      expect(record.sessionKind, AttendanceSessionKind.halfDayPm);
    });

    test('9:00–18:00 is full day', () {
      final record = _record(
        clockIn: _myt(2026, 8, 17, 9),
        clockOut: _myt(2026, 8, 17, 18),
      );
      expect(record.sessionKind, AttendanceSessionKind.fullDay);
      expect(record.isHalfDayWorked, isFalse);
      expect(record.workedLabel, '9h');
    });

    test('10:00–17:00 spanning lunch is full day', () {
      final record = _record(
        clockIn: _myt(2026, 8, 17, 10),
        clockOut: _myt(2026, 8, 17, 17),
      );
      expect(record.sessionKind, AttendanceSessionKind.fullDay);
    });

    test('9:00–15:00 (morning + part afternoon) is full day', () {
      final record = _record(
        clockIn: _myt(2026, 8, 17, 9),
        clockOut: _myt(2026, 8, 17, 15),
      );
      expect(record.sessionKind, AttendanceSessionKind.fullDay);
    });

    test('invalid out-before-in is unknown', () {
      final record = _record(
        clockIn: _myt(2026, 8, 17, 12),
        clockOut: _myt(2026, 8, 17, 9),
      );
      expect(record.sessionKind, AttendanceSessionKind.unknown);
      expect(record.isHalfDayWorked, isFalse);
    });
  });

  group('EmployeeCalendarDay half-day labels', () {
    test('AM half day label and month counts', () {
      final halfAm = EmployeeCalendarDay(
        date: DateTime(2026, 8, 4),
        attendanceRecords: [
          _record(
            clockIn: _myt(2026, 8, 4, 9),
            clockOut: _myt(2026, 8, 4, 13),
          ),
        ],
        approvedLeave: null,
        isToday: false,
      );
      final full = EmployeeCalendarDay(
        date: DateTime(2026, 8, 5),
        attendanceRecords: [
          _record(
            clockIn: _myt(2026, 8, 5, 9),
            clockOut: _myt(2026, 8, 5, 18),
          ),
        ],
        approvedLeave: null,
        isToday: false,
      );

      expect(halfAm.stateLabel, 'Half day AM');
      expect(full.stateLabel, 'Attended');

      final month = EmployeeMonthlyCalendarData(
        month: DateTime(2026, 8),
        days: [halfAm, full],
      );
      expect(month.halfDayWorkedCount, 1);
      expect(month.fullDayPresentCount, 1);
    });
  });
}

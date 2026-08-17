import 'package:attendance_app/models/app_user.dart';
import 'package:attendance_app/models/attendance.dart';
import 'package:attendance_app/models/leave_request.dart';
import 'package:attendance_app/models/monthly_attendance_summary.dart';
import 'package:attendance_app/utils/leave_catalog.dart';
import 'package:attendance_app/utils/monthly_attendance_rollup.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _myt(int year, int month, int day, [int hour = 9, int minute = 0]) {
  return DateTime.utc(year, month, day, hour, minute)
      .subtract(const Duration(hours: 8));
}

Attendance _att({
  required DateTime date,
  required DateTime clockIn,
  DateTime? clockOut,
  String status = 'completed',
}) {
  return Attendance(
    id: 'a-${date.day}-${clockIn.hour}',
    userId: 'u1',
    clockInTime: clockIn,
    clockOutTime: clockOut,
    date: DateTime(date.year, date.month, date.day),
    status: status,
  );
}

LeaveRequest _leave({
  required String type,
  required DateTime start,
  required DateTime end,
}) {
  return LeaveRequest(
    id: 'l-$type-${start.day}',
    userId: 'u1',
    leaveType: type,
    startDate: start,
    endDate: end,
    reason: 'test',
    status: 'approved',
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

AppUser _employee({
  DateTime? employmentStart,
  String department = 'Ops',
}) {
  return AppUser(
    id: 'u1',
    username: 'ahmad',
    name: 'Ahmad Faiz',
    email: 'a@example.com',
    role: 'employee',
    createdAt: DateTime.utc(2025, 1, 1),
    employmentStartDate: employmentStart,
    department: department,
  );
}

void main() {
  group('MonthlyAttendanceRollup.formatDays', () {
    test('formats whole and half days', () {
      expect(MonthlyAttendanceRollup.formatDays(18), '18');
      expect(MonthlyAttendanceRollup.formatDays(18.0), '18');
      expect(MonthlyAttendanceRollup.formatDays(18.5), '18.5');
      expect(MonthlyAttendanceRollup.formatDays(0.5), '0.5');
    });
  });

  group('attendCreditForRecord', () {
    test('attendCreditForRecord full / half / open', () {
      final full = _att(
        date: DateTime(2026, 8, 17),
        clockIn: _myt(2026, 8, 17, 9),
        clockOut: _myt(2026, 8, 17, 18),
      );
      final halfAm = _att(
        date: DateTime(2026, 8, 17),
        clockIn: _myt(2026, 8, 17, 9),
        clockOut: _myt(2026, 8, 17, 13),
      );
      final halfPm = _att(
        date: DateTime(2026, 8, 17),
        clockIn: _myt(2026, 8, 17, 13),
        clockOut: _myt(2026, 8, 17, 18),
      );
      final openMorning = _att(
        date: DateTime(2026, 8, 17),
        clockIn: _myt(2026, 8, 17, 9),
        status: 'in_progress',
      );
      final openAfternoon = _att(
        date: DateTime(2026, 8, 17),
        clockIn: _myt(2026, 8, 17, 14),
        status: 'in_progress',
      );

      expect(MonthlyAttendanceRollup.attendCreditForRecord(full), 1);
      expect(MonthlyAttendanceRollup.attendCreditForRecord(halfAm), 0.5);
      expect(MonthlyAttendanceRollup.attendCreditForRecord(halfPm), 0.5);
      expect(MonthlyAttendanceRollup.attendCreditForRecord(openMorning), 1);
      expect(MonthlyAttendanceRollup.attendCreditForRecord(openAfternoon), 0.5);
    });
  });

  group('summarizeEmployee', () {
    // August 2026: Sat 1, Sun 2, Mon 3 … — use a fixed "today" deep in August.
    final today = DateTime(2026, 8, 31);
    final month = DateTime(2026, 8);

    test('weekday full + half, saturday optional, MIA formula', () {
      // Mon 3 Aug full, Tue 4 Aug half AM, Sat 8 Aug full (optional).
      final records = [
        _att(
          date: DateTime(2026, 8, 3),
          clockIn: _myt(2026, 8, 3, 9),
          clockOut: _myt(2026, 8, 3, 18),
        ),
        _att(
          date: DateTime(2026, 8, 4),
          clockIn: _myt(2026, 8, 4, 9),
          clockOut: _myt(2026, 8, 4, 13),
        ),
        _att(
          date: DateTime(2026, 8, 8),
          clockIn: _myt(2026, 8, 8, 9),
          clockOut: _myt(2026, 8, 8, 13),
        ),
      ];

      final summary = MonthlyAttendanceRollup.summarizeEmployee(
        employee: _employee(),
        month: month,
        records: records,
        approvedLeaves: const [],
        today: today,
      );

      expect(summary.department, 'Ops');
      expect(summary.attendDays, 1.5); // sat not included
      expect(summary.saturdayAttendCount, 1);
      expect(summary.leaveDays, 0);
      expect(summary.mcDays, 0);
      expect(summary.notes, isEmpty);
      expect(summary.reportingOn, DateTime(2026, 8, 3));
      expect(summary.totalWorkingDays, greaterThan(0));
      expect(
        summary.miaDays,
        closeTo(summary.totalWorkingDays - 1.5, 0.01),
      );
    });

    test('MC and leave split; half annual = 0.5', () {
      final leaves = [
        _leave(
          type: LeaveCatalog.sick,
          start: DateTime(2026, 8, 5), // Wed
          end: DateTime(2026, 8, 5),
        ),
        _leave(
          type: LeaveCatalog.annualHalfAm,
          start: DateTime(2026, 8, 6), // Thu
          end: DateTime(2026, 8, 6),
        ),
        _leave(
          type: LeaveCatalog.annual,
          start: DateTime(2026, 8, 7), // Fri
          end: DateTime(2026, 8, 7),
        ),
      ];

      final summary = MonthlyAttendanceRollup.summarizeEmployee(
        employee: _employee(),
        month: month,
        records: const [],
        approvedLeaves: leaves,
        today: today,
      );

      expect(summary.mcDays, 1);
      expect(summary.leaveDays, 1.5); // 0.5 + 1
      expect(summary.attendDays, 0);
      expect(summary.hasNoAttendance, isTrue);
      // MIA reduced by leave+mc
      expect(
        summary.miaDays,
        closeTo(summary.totalWorkingDays - 2.5, 0.01),
      );
    });

    test('saturday does not increase total working days', () {
      final withSat = MonthlyAttendanceRollup.summarizeEmployee(
        employee: _employee(),
        month: month,
        records: [
          _att(
            date: DateTime(2026, 8, 8),
            clockIn: _myt(2026, 8, 8, 9),
            clockOut: _myt(2026, 8, 8, 18),
          ),
        ],
        approvedLeaves: const [],
        today: today,
      );
      final empty = MonthlyAttendanceRollup.summarizeEmployee(
        employee: _employee(),
        month: month,
        records: const [],
        approvedLeaves: const [],
        today: today,
      );

      expect(withSat.totalWorkingDays, empty.totalWorkingDays);
      expect(withSat.saturdayAttendCount, 1);
      expect(withSat.attendDays, 0);
    });

    test('employment start clips working days', () {
      final lateStart = MonthlyAttendanceRollup.summarizeEmployee(
        employee: _employee(employmentStart: DateTime(2026, 8, 17)),
        month: month,
        records: const [],
        approvedLeaves: const [],
        today: today,
      );
      final full = MonthlyAttendanceRollup.summarizeEmployee(
        employee: _employee(employmentStart: DateTime(2026, 1, 1)),
        month: month,
        records: const [],
        approvedLeaves: const [],
        today: today,
      );

      expect(lateStart.totalWorkingDays, lessThan(full.totalWorkingDays));
      expect(lateStart.reportingOn, isNull);
    });

    test('current month does not count future weekdays', () {
      final midMonth = MonthlyAttendanceRollup.summarizeEmployee(
        employee: _employee(),
        month: month,
        records: const [],
        approvedLeaves: const [],
        today: DateTime(2026, 8, 10),
      );
      final endMonth = MonthlyAttendanceRollup.summarizeEmployee(
        employee: _employee(),
        month: month,
        records: const [],
        approvedLeaves: const [],
        today: DateTime(2026, 8, 31),
      );

      expect(midMonth.totalWorkingDays, lessThan(endMonth.totalWorkingDays));
    });

    test('sat over limit note and clean/mia states', () {
      final sats = [
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 8),
        DateTime(2026, 8, 15),
      ];
      final records = [
        for (final d in sats)
          _att(
            date: d,
            clockIn: _myt(d.year, d.month, d.day, 9),
            clockOut: _myt(d.year, d.month, d.day, 13),
          ),
        // One weekday so not "no attendance"
        _att(
          date: DateTime(2026, 8, 3),
          clockIn: _myt(2026, 8, 3, 9),
          clockOut: _myt(2026, 8, 3, 18),
        ),
      ];

      final summary = MonthlyAttendanceRollup.summarizeEmployee(
        employee: _employee(),
        month: month,
        records: records,
        approvedLeaves: const [],
        today: today,
      );

      expect(summary.saturdayAttendCount, 3);
      expect(summary.saturdayOverLimit, isTrue);
      expect(summary.notes, isEmpty);
      expect(summary.reviewState, MonthlyAttendanceReviewState.hasMia);
    });

    test('forgot clock-out still counts as attend (full or half)', () {
      final empty = MonthlyAttendanceRollup.summarizeEmployee(
        employee: _employee(),
        month: month,
        records: const [],
        approvedLeaves: const [],
        today: today,
      );

      final openFull = MonthlyAttendanceRollup.summarizeEmployee(
        employee: _employee(),
        month: month,
        records: [
          _att(
            date: DateTime(2026, 8, 17), // Monday
            clockIn: _myt(2026, 8, 17, 9),
            status: 'in_progress',
          ),
        ],
        approvedLeaves: const [],
        today: today,
      );

      final openHalf = MonthlyAttendanceRollup.summarizeEmployee(
        employee: _employee(),
        month: month,
        records: [
          _att(
            date: DateTime(2026, 8, 17),
            clockIn: _myt(2026, 8, 17, 14),
            status: 'in_progress',
          ),
        ],
        approvedLeaves: const [],
        today: today,
      );

      expect(openFull.attendDays, 1);
      expect(openFull.openAttendanceDays, 1);
      expect(openFull.notes, isEmpty);
      expect(openFull.reportingOn, DateTime(2026, 8, 17));
      expect(openFull.hasNoAttendance, isFalse);
      expect(
        openFull.miaDays,
        closeTo(empty.miaDays - 1, 0.01),
      );

      expect(openHalf.attendDays, 0.5);
      expect(
        openHalf.miaDays,
        closeTo(empty.miaDays - 0.5, 0.01),
      );
    });

    test('open saturday counts toward Sat only, not weekday Attend', () {
      final summary = MonthlyAttendanceRollup.summarizeEmployee(
        employee: _employee(),
        month: month,
        records: [
          _att(
            date: DateTime(2026, 8, 8), // Saturday
            clockIn: _myt(2026, 8, 8, 9),
            status: 'in_progress',
          ),
        ],
        approvedLeaves: const [],
        today: today,
      );

      expect(summary.attendDays, 0);
      expect(summary.saturdayAttendCount, 1);
      expect(summary.openAttendanceDays, 1);
      expect(summary.hasNoAttendance, isFalse);
    });

    test('completed same day preferred over open inference', () {
      final summary = MonthlyAttendanceRollup.summarizeEmployee(
        employee: _employee(),
        month: month,
        records: [
          _att(
            date: DateTime(2026, 8, 17),
            clockIn: _myt(2026, 8, 17, 9),
            clockOut: _myt(2026, 8, 17, 13),
          ),
          _att(
            date: DateTime(2026, 8, 17),
            clockIn: _myt(2026, 8, 17, 9),
            status: 'in_progress',
          ),
        ],
        approvedLeaves: const [],
        today: today,
      );

      // Completed half AM (0.5) wins over open morning inference (1.0).
      expect(summary.attendDays, 0.5);
      expect(summary.openAttendanceDays, 1);
    });

    test('admin notes pass through blank by default', () {
      final blank = MonthlyAttendanceRollup.summarizeEmployee(
        employee: _employee(),
        month: month,
        records: [
          _att(
            date: DateTime(2026, 8, 3),
            clockIn: _myt(2026, 8, 3, 9),
            clockOut: _myt(2026, 8, 3, 18),
          ),
        ],
        approvedLeaves: const [],
        today: today,
      );
      final withNote = MonthlyAttendanceRollup.summarizeEmployee(
        employee: _employee(),
        month: month,
        records: [
          _att(
            date: DateTime(2026, 8, 3),
            clockIn: _myt(2026, 8, 3, 9),
            clockOut: _myt(2026, 8, 3, 18),
          ),
        ],
        approvedLeaves: const [],
        today: today,
        notes: 'Late approval',
      );
      expect(blank.notes, isEmpty);
      expect(withNote.notes, 'Late approval');
      expect(withNote.reportingOn, DateTime(2026, 8, 3));
    });
  });
}

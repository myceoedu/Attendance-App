import 'package:attendance_app/models/attendance.dart';
import 'package:attendance_app/models/leave_request.dart';
import 'package:attendance_app/models/payroll_salary_setting.dart';
import 'package:attendance_app/models/payroll_statutory_config.dart';
import 'package:attendance_app/services/payroll_engine.dart';
import 'package:attendance_app/utils/employment_status.dart';
import 'package:flutter_test/flutter_test.dart';

PayrollSalarySetting _salary({
  double basic = 3000,
  double allowance = 500,
  double monthlyCommission = 0,
  double monthlyIncentive = 0,
  double monthlyIncrement = 0,
  bool ot = true,
  String employmentStatus = EmploymentStatus.permanent,
  String epfCategory = 'standard',
  String socsoCategory = 'standard',
  bool eisEligible = true,
  String compensationType = 'employee',
}) {
  return PayrollSalarySetting(
    userId: 'u1',
    staffId: 's1',
    department: '',
    position: '',
    employmentStatus: EmploymentStatus.normalize(employmentStatus),
    basicSalary: basic,
    fixedAllowance: allowance,
    monthlyCommission: monthlyCommission,
    monthlyIncentive: monthlyIncentive,
    monthlyIncrement: monthlyIncrement,
    otEligible: ot,
    compensationType: compensationType,
    epfCategory: epfCategory,
    socsoCategory: socsoCategory,
    eisEligible: eisEligible,
    paymentMethod: 'bank_transfer',
    bankName: '',
    bankAccountNumber: '',
    payrollStatus: 'active',
    updatedAt: DateTime.utc(2025),
  );
}

PayrollStatutoryConfig _statutory() {
  return PayrollStatutoryConfig(
    id: 'c1',
    label: 'test',
    effectiveFrom: DateTime.utc(2025),
    epfEmployeePct: 11,
    epfEmployerPct: 13,
    epfSalaryCeiling: 50000,
    socsoEmployeePct: 0.5,
    socsoEmployerPct: 1.75,
    eisEmployeePct: 0.2,
    eisEmployerPct: 0.2,
    otHourlyMultiplier: 1.5,
    standardHoursPerDay: 8,
    createdAt: DateTime.utc(2025),
  );
}

void main() {
  group('PayrollEngine.compute', () {
    test('net equals gross minus statutory employee contributions', () {
      final month = DateTime(2025, 6);
      final calc = PayrollEngine.compute(
        salary: _salary(),
        statutory: _statutory(),
        workingWeekdays: 22,
        presentDays: 20,
        month: month,
        leaves: const [],
      );
      final statutory =
          calc.epfEmployee + calc.socsoEmployee + calc.eisEmployee;
      expect(calc.netSalary, closeTo(calc.grossPay - statutory, 0.02));
      expect(calc.otAmount, 0);
    });

    test('unpaid leave reduces gross and is included in totalDeduction', () {
      final month = DateTime(2025, 6);
      final none = PayrollEngine.compute(
        salary: _salary(),
        statutory: _statutory(),
        workingWeekdays: 22,
        presentDays: 22,
        month: month,
        leaves: const [],
      );
      final oneDay = PayrollEngine.compute(
        salary: _salary(),
        statutory: _statutory(),
        workingWeekdays: 22,
        presentDays: 21,
        month: month,
        leaves: [
          LeaveRequest(
            id: '1',
            userId: 'u1',
            leaveType: 'unpaid',
            startDate: DateTime(2025, 6, 2),
            endDate: DateTime(2025, 6, 2),
            reason: '',
            status: 'approved',
            createdAt: DateTime.utc(2025),
          ),
        ],
      );
      expect(oneDay.unpaidLeaveDeduction, greaterThan(0));
      expect(
        oneDay.grossPay,
        closeTo(none.grossPay - oneDay.unpaidLeaveDeduction, 0.02),
      );
      expect(
        oneDay.totalDeduction,
        closeTo(
          oneDay.unpaidLeaveDeduction +
              oneDay.epfEmployee +
              oneDay.socsoEmployee +
              oneDay.eisEmployee,
          0.02,
        ),
      );
    });

    test(
      'full package divided by WD drives unpaid leave (basic + allowance)',
      () {
        final month = DateTime(2025, 6);
        final calc = PayrollEngine.compute(
          salary: _salary(basic: 2200, allowance: 220),
          statutory: _statutory(),
          workingWeekdays: 22,
          presentDays: 22,
          month: month,
          leaves: [
            LeaveRequest(
              id: '1',
              userId: 'u1',
              leaveType: 'unpaid',
              startDate: DateTime(2025, 6, 3),
              endDate: DateTime(2025, 6, 3),
              reason: '',
              status: 'approved',
              createdAt: DateTime.utc(2025),
            ),
          ],
        );
        expect(calc.unpaidLeaveDeduction, closeTo(110.0, 0.01));
      },
    );

    test('EPF above60: 0% employee and senior employer rate', () {
      final month = DateTime(2025, 6);
      final standard = PayrollEngine.compute(
        salary: _salary(),
        statutory: _statutory(),
        workingWeekdays: 22,
        presentDays: 22,
        month: month,
        leaves: const [],
      );
      final above60 = PayrollEngine.compute(
        salary: _salary(epfCategory: 'above60'),
        statutory: _statutory(),
        workingWeekdays: 22,
        presentDays: 22,
        month: month,
        leaves: const [],
      );
      final epfBase = 3000.0 + 500.0;
      expect(above60.epfEmployee, 0);
      expect(
        above60.epfEmployer,
        closeTo(PayrollEngine.round2(epfBase * 0.065), 0.02),
      );
      expect(above60.socsoEmployee, 0);
      expect(above60.eisEmployee, 0);
      expect(standard.epfEmployee, greaterThan(0));
      expect(above60.netSalary, closeTo(above60.grossPay, 0.02));
    });

    test('EPF employer rate changes above RM5,000 wage base', () {
      final month = DateTime(2025, 6);
      final low = PayrollEngine.compute(
        salary: _salary(basic: 5000, allowance: 0),
        statutory: _statutory(),
        workingWeekdays: 22,
        presentDays: 22,
        month: month,
        leaves: const [],
      );
      final high = PayrollEngine.compute(
        salary: _salary(basic: 5000.01, allowance: 0),
        statutory: _statutory(),
        workingWeekdays: 22,
        presentDays: 22,
        month: month,
        leaves: const [],
      );
      expect(low.epfEmployer, closeTo(650.00, 0.02));
      expect(high.epfEmployer, closeTo(600.00, 0.02));
      expect(high.epfEmployee, closeTo(550.00, 0.02));
    });

    test('date of birth can trigger age 60+ statutory rules', () {
      final month = DateTime(2025, 6);
      final calc = PayrollEngine.compute(
        salary: _salary(epfCategory: 'standard'),
        statutory: _statutory(),
        workingWeekdays: 22,
        presentDays: 22,
        month: month,
        leaves: const [],
        employeeDateOfBirth: DateTime(1960, 1, 1),
      );
      expect(calc.epfEmployee, 0);
      expect(calc.socsoEmployee, 0);
      expect(calc.eisEmployee, 0);
    });

    test('SOCSO uses official PERKESO table lookup and caps at RM6,000', () {
      final month = DateTime(2025, 6);
      final mid = PayrollEngine.compute(
        salary: _salary(basic: 1700, allowance: 0),
        statutory: _statutory(),
        workingWeekdays: 22,
        presentDays: 22,
        month: month,
        leaves: const [],
      );
      final capped = PayrollEngine.compute(
        salary: _salary(basic: 7000, allowance: 0),
        statutory: _statutory(),
        workingWeekdays: 22,
        presentDays: 22,
        month: month,
        leaves: const [],
      );
      // Official example: RM1700 -> employee RM8.25, employer RM28.85.
      expect(mid.socsoEmployee, closeTo(8.25, 0.02));
      expect(mid.socsoEmployer, closeTo(28.85, 0.02));
      expect(capped.socsoEmployee, closeTo(29.75, 0.02));
      expect(capped.socsoEmployer, closeTo(104.15, 0.02));
    });

    test('EIS uses official table lookup and caps at RM6,000 table max', () {
      final month = DateTime(2025, 6);
      final mid = PayrollEngine.compute(
        salary: _salary(basic: 1700, allowance: 0),
        statutory: _statutory(),
        workingWeekdays: 22,
        presentDays: 22,
        month: month,
        leaves: const [],
      );
      final capped = PayrollEngine.compute(
        salary: _salary(basic: 7000, allowance: 0),
        statutory: _statutory(),
        workingWeekdays: 22,
        presentDays: 22,
        month: month,
        leaves: const [],
      );
      // Official example: RM1700 -> employee/employer RM3.30 each.
      expect(mid.eisEmployee, closeTo(3.30, 0.02));
      expect(mid.eisEmployer, closeTo(3.30, 0.02));
      expect(capped.eisEmployee, closeTo(11.90, 0.02));
      expect(capped.eisEmployer, closeTo(11.90, 0.02));
    });

    test('unpaid leave reduces statutory wage base before table lookup', () {
      final month = DateTime(2025, 6);
      final calc = PayrollEngine.compute(
        salary: _salary(basic: 2200, allowance: 0),
        statutory: _statutory(),
        workingWeekdays: 22,
        presentDays: 21,
        month: month,
        leaves: [
          LeaveRequest(
            id: '1',
            userId: 'u1',
            leaveType: 'unpaid',
            startDate: DateTime(2025, 6, 2),
            endDate: DateTime(2025, 6, 2),
            reason: '',
            status: 'approved',
            createdAt: DateTime.utc(2025),
          ),
        ],
      );
      expect(calc.unpaidLeaveDeduction, closeTo(100, 0.02));
      expect(calc.epfEmployee, closeTo(231, 0.02));
      expect(calc.socsoEmployee, closeTo(10.25, 0.02));
      expect(calc.eisEmployee, closeTo(4.10, 0.02));
    });

    test('intern: allowance / calendar days minus any approved leave', () {
      final month = DateTime(2025, 3);
      final leaves = [
        LeaveRequest(
          id: '1',
          userId: 'u1',
          leaveType: 'sick',
          startDate: DateTime(2025, 3, 10),
          endDate: DateTime(2025, 3, 10),
          reason: '',
          status: 'approved',
          createdAt: DateTime.utc(2025),
        ),
      ];
      final calc = PayrollEngine.compute(
        salary: _salary(basic: 999, allowance: 500, compensationType: 'intern'),
        statutory: _statutory(),
        workingWeekdays: 22,
        presentDays: 20,
        month: month,
        leaves: leaves,
      );
      final daily = 500 / 31;
      expect(calc.basicAmount, 0);
      expect(calc.allowanceAmount, 500);
      expect(calc.commissionAmount, 0);
      expect(
        calc.unpaidLeaveDeduction,
        closeTo(PayrollEngine.round2(daily * 1), 0.02),
      );
      expect(calc.epfEmployee, 0);
      expect(calc.epfEmployer, 0);
      expect(calc.socsoEmployee, 0);
      expect(calc.eisEmployee, 0);
      expect(calc.netSalary, closeTo(500 - calc.unpaidLeaveDeduction, 0.02));
    });

    test('employee: monthly commission adds to gross and EPF base', () {
      final month = DateTime(2025, 6);
      final noComm = PayrollEngine.compute(
        salary: _salary(),
        statutory: _statutory(),
        workingWeekdays: 22,
        presentDays: 22,
        month: month,
        leaves: const [],
      );
      final withComm = PayrollEngine.compute(
        salary: _salary(monthlyCommission: 200),
        statutory: _statutory(),
        workingWeekdays: 22,
        presentDays: 22,
        month: month,
        leaves: const [],
      );
      expect(withComm.commissionAmount, 200);
      expect(withComm.grossPay, closeTo(noComm.grossPay + 200, 0.02));
      expect(withComm.epfEmployee, greaterThan(noComm.epfEmployee));
    });

    test('employee: allowance and commission both count toward gross', () {
      final month = DateTime(2025, 6);
      final calc = PayrollEngine.compute(
        salary: _salary(allowance: 300, monthlyCommission: 200),
        statutory: _statutory(),
        workingWeekdays: 22,
        presentDays: 22,
        month: month,
        leaves: const [],
      );
      expect(calc.allowanceAmount, 300);
      expect(calc.commissionAmount, 200);
      expect(calc.incentiveAmount, 0);
      expect(calc.incrementAmount, 0);
      expect(calc.grossPay, closeTo(3000 + 300 + 200, 0.02));
    });

    test('intern: commission pooled with allowance for leave pro-rating', () {
      final month = DateTime(2025, 3);
      final leaves = [
        LeaveRequest(
          id: '1',
          userId: 'u1',
          leaveType: 'sick',
          startDate: DateTime(2025, 3, 10),
          endDate: DateTime(2025, 3, 10),
          reason: '',
          status: 'approved',
          createdAt: DateTime.utc(2025),
        ),
      ];
      final calc = PayrollEngine.compute(
        salary: _salary(
          basic: 0,
          allowance: 400,
          monthlyCommission: 100,
          compensationType: 'intern',
        ),
        statutory: _statutory(),
        workingWeekdays: 22,
        presentDays: 20,
        month: month,
        leaves: leaves,
      );
      final daily = 500 / 31;
      expect(calc.commissionAmount, 100);
      expect(
        calc.unpaidLeaveDeduction,
        closeTo(PayrollEngine.round2(daily * 1), 0.02),
      );
      expect(calc.grossPay, closeTo(500 - calc.unpaidLeaveDeduction, 0.02));
    });

    test('intern: annual leave is not deducted', () {
      final month = DateTime(2025, 3);
      final leaves = [
        LeaveRequest(
          id: '1',
          userId: 'u1',
          leaveType: 'annual_half_am',
          startDate: DateTime(2025, 3, 5),
          endDate: DateTime(2025, 3, 5),
          reason: '',
          status: 'approved',
          createdAt: DateTime.utc(2025),
        ),
      ];
      final calc = PayrollEngine.compute(
        salary: _salary(allowance: 310, basic: 0, compensationType: 'intern'),
        statutory: _statutory(),
        workingWeekdays: 22,
        presentDays: 22,
        month: month,
        leaves: leaves,
      );
      expect(calc.unpaidLeaveDeduction, 0);
    });
  });

  group('PayrollEngine.unpaidLeaveDaysFromRequests', () {
    test('counts working weekdays in month, not Sat/Sun', () {
      final month = DateTime(2025, 6);
      final leaves = [
        LeaveRequest(
          id: '1',
          userId: 'u',
          leaveType: 'unpaid',
          startDate: DateTime(2025, 6, 5),
          endDate: DateTime(2025, 6, 6),
          reason: '',
          status: 'approved',
          createdAt: DateTime.utc(2025),
        ),
      ];
      final d = PayrollEngine.unpaidLeaveDaysFromRequests(
        userId: 'u',
        month: month,
        leaves: leaves,
      );
      expect(d, 2);
    });

    test('sick leave is paid for payroll — no unpaid days', () {
      final month = DateTime(2025, 6);
      final leaves = [
        LeaveRequest(
          id: '1',
          userId: 'u',
          leaveType: 'sick',
          startDate: DateTime(2025, 6, 2),
          endDate: DateTime(2025, 6, 6),
          reason: '',
          status: 'approved',
          createdAt: DateTime.utc(2025),
        ),
      ];
      final d = PayrollEngine.unpaidLeaveDaysFromRequests(
        userId: 'u',
        month: month,
        leaves: leaves,
      );
      expect(d, 0.0);
    });
  });

  group('presentDaysExcludingApprovedLeave', () {
    test('does not count attendance on approved leave dates', () {
      final month = DateTime(2025, 6);
      const uid = 'emp1';
      final attendance = [
        Attendance(
          id: '1',
          userId: uid,
          clockInTime: DateTime.utc(2025, 6, 2, 1),
          clockOutTime: DateTime.utc(2025, 6, 2, 10),
          date: DateTime(2025, 6, 2),
          status: 'completed',
        ),
        Attendance(
          id: '2',
          userId: uid,
          clockInTime: DateTime.utc(2025, 6, 3, 1),
          clockOutTime: DateTime.utc(2025, 6, 3, 10),
          date: DateTime(2025, 6, 3),
          status: 'completed',
        ),
      ];
      final leaves = [
        LeaveRequest(
          id: 'l1',
          userId: uid,
          leaveType: 'annual',
          startDate: DateTime(2025, 6, 3),
          endDate: DateTime(2025, 6, 3),
          reason: '',
          status: 'approved',
          createdAt: DateTime.utc(2025),
        ),
      ];
      expect(
        PayrollEngine.presentDaysExcludingApprovedLeave(
          userId: uid,
          month: month,
          attendanceInMonth: attendance,
          leaves: leaves,
        ),
        1,
      );
    });

    test('counts distinct dates only once', () {
      final month = DateTime(2025, 6);
      const uid = 'emp1';
      final attendance = [
        Attendance(
          id: '1',
          userId: uid,
          clockInTime: DateTime.utc(2025, 6, 2, 1),
          date: DateTime(2025, 6, 2),
          status: 'completed',
        ),
        Attendance(
          id: '2',
          userId: uid,
          clockInTime: DateTime.utc(2025, 6, 2, 8),
          date: DateTime(2025, 6, 2),
          status: 'completed',
        ),
      ];
      expect(
        PayrollEngine.presentDaysExcludingApprovedLeave(
          userId: uid,
          month: month,
          attendanceInMonth: attendance,
          leaves: const [],
        ),
        1,
      );
    });
  });
}

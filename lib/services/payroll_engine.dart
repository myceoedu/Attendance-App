import '../models/attendance.dart';
import '../models/leave_request.dart';
import '../payroll/payroll_calculator.dart';
import '../models/payroll_salary_setting.dart';
import '../models/payroll_statutory_config.dart';
import '../utils/leave_catalog.dart';

/// Malaysia-oriented payroll calculation.
///
/// EPF/KWSP, SOCSO/PERKESO, and EIS use Malaysia rule helpers instead of the
/// editable flat percentage fields on [PayrollStatutoryConfig]. The config is
/// still used by the wider payroll module for effective-dated setup and
/// non-statutory settings.
///
/// **Add-ons:** [PayrollSalarySetting] monthly fields (allowance, commission,
/// incentive, increment) are summed into gross and Malaysia statutory wage base
/// for employees. Interns: same four fields are pooled for calendar-day leave
/// pro-rating (no statutory).
class PayrollEngine {
  PayrollEngine._();

  static double round2(double v) => (v * 100).roundToDouble() / 100;

  /// Calendar days in [month]'s month (e.g. March → 31).
  static int calendarDaysInMonth(DateTime month) {
    return DateTime(month.year, month.month + 1, 0).day;
  }

  /// Weekdays Mon–Fri in [month].
  static int workingWeekdaysInMonth(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1, 0);
    var n = 0;
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      final w = d.weekday;
      if (w != DateTime.saturday && w != DateTime.sunday) n++;
    }
    return n;
  }

  /// Working weekdays (Mon–Fri) in \[effectiveStart, effectiveEnd\] inclusive,
  /// intersected with calendar days inside \[month\].
  static double _overlapWorkingWeekdaysInMonth(
    DateTime start,
    DateTime end,
    DateTime month,
  ) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    var effectiveStart = start.isAfter(monthStart) ? start : monthStart;
    var effectiveEnd = end.isBefore(monthEnd) ? end : monthEnd;
    if (effectiveEnd.isBefore(monthStart)) return 0;
    if (effectiveStart.isAfter(monthEnd)) return 0;
    if (effectiveStart.isBefore(monthStart)) effectiveStart = monthStart;
    if (effectiveEnd.isAfter(monthEnd)) effectiveEnd = monthEnd;
    if (effectiveEnd.isBefore(effectiveStart)) return 0;

    var startDay = DateTime(
      effectiveStart.year,
      effectiveStart.month,
      effectiveStart.day,
    );
    final endDay = DateTime(
      effectiveEnd.year,
      effectiveEnd.month,
      effectiveEnd.day,
    );
    var n = 0.0;
    for (
      var d = startDay;
      !d.isAfter(endDay);
      d = d.add(const Duration(days: 1))
    ) {
      final w = d.weekday;
      if (w != DateTime.saturday && w != DateTime.sunday) n += 1;
    }
    return n;
  }

  /// Approved leave types that reduce pay: **unpaid** weekdays in [month] only.
  ///
  /// Annual, sick, emergency, etc. are treated as paid (no deduction). Matches
  /// [LeaveCatalog.isPayrollUnpaidDeduction].
  static double unpaidLeaveDaysFromRequests({
    required String userId,
    required DateTime month,
    required List<LeaveRequest> leaves,
  }) {
    var total = 0.0;
    for (final leave in leaves) {
      if (leave.userId != userId) continue;
      if (leave.status.toLowerCase() != 'approved') continue;
      if (!LeaveCatalog.isPayrollUnpaidDeduction(leave.leaveType)) continue;
      total += _overlapWorkingWeekdaysInMonth(
        leave.startDate,
        leave.endDate,
        month,
      );
    }
    return total;
  }

  /// **Intern:** all approved **non-annual** leave overlapping [month]; calendar-day units
  /// (interns do not use annual leave).
  static double internLeaveCalendarUnitsFromRequests({
    required String userId,
    required DateTime month,
    required List<LeaveRequest> leaves,
  }) {
    var total = 0.0;
    for (final leave in leaves) {
      if (leave.userId != userId) continue;
      if (leave.status.toLowerCase() != 'approved') continue;
      if (LeaveCatalog.consumesAnnual(leave.leaveType)) continue;
      total += _overlapCalendarLeaveUnitsInMonth(
        leave.startDate,
        leave.endDate,
        leave.leaveType,
        month,
      );
    }
    return total;
  }

  static double _overlapCalendarLeaveUnitsInMonth(
    DateTime start,
    DateTime end,
    String leaveType,
    DateTime month,
  ) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    var effectiveStart = DateTime(start.year, start.month, start.day);
    var effectiveEnd = DateTime(end.year, end.month, end.day);
    if (effectiveEnd.isBefore(monthStart)) return 0;
    if (effectiveStart.isAfter(monthEnd)) return 0;
    if (effectiveStart.isBefore(monthStart)) effectiveStart = monthStart;
    if (effectiveEnd.isAfter(monthEnd)) effectiveEnd = monthEnd;
    if (effectiveEnd.isBefore(effectiveStart)) return 0;

    final unit = LeaveCatalog.isHalfDayAnnual(leaveType) ? 0.5 : 1.0;
    var n = 0.0;
    for (
      var d = effectiveStart;
      !d.isAfter(effectiveEnd);
      d = d.add(const Duration(days: 1))
    ) {
      n += unit;
    }
    return n;
  }

  /// Distinct days in [month] with clock-in [attendanceInMonth] for [userId],
  /// excluding calendar days covered by **approved** leave (any type). Matches
  /// the employee calendar where leave overrides attendance on the same date.
  static int presentDaysExcludingApprovedLeave({
    required String userId,
    required DateTime month,
    required List<Attendance> attendanceInMonth,
    required List<LeaveRequest> leaves,
  }) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);

    String dateKey(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final leaveDates = <String>{};
    for (final leave in leaves) {
      if (leave.userId != userId) continue;
      if (leave.status.toLowerCase() != 'approved') continue;

      var cur = DateTime(
        leave.startDate.year,
        leave.startDate.month,
        leave.startDate.day,
      );
      final end = DateTime(
        leave.endDate.year,
        leave.endDate.month,
        leave.endDate.day,
      );
      if (end.isBefore(monthStart) || cur.isAfter(monthEnd)) continue;
      if (cur.isBefore(monthStart)) cur = monthStart;
      final last = end.isAfter(monthEnd) ? monthEnd : end;
      for (var d = cur; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
        leaveDates.add(dateKey(d));
      }
    }

    final presentDates = <String>{};
    for (final a in attendanceInMonth) {
      if (a.userId != userId || a.clockInTime == null) continue;
      final dk = dateKey(a.date);
      if (leaveDates.contains(dk)) continue;
      presentDates.add(dk);
    }
    return presentDates.length;
  }

  /// [presentDays] is recorded on line items for reporting only; it does not
  /// change computed amounts (no pro‑rata for simple absence). Populate with
  /// [presentDaysExcludingApprovedLeave] so values match the employee calendar.
  ///
  /// Uses [PayrollSalarySetting.isIntern] to pick intern vs employee rules.
  static PayrollComputedAmounts compute({
    required PayrollSalarySetting salary,
    required PayrollStatutoryConfig statutory,
    required int workingWeekdays,
    required int presentDays,
    required DateTime month,
    required List<LeaveRequest> leaves,
    DateTime? employeeDateOfBirth,
  }) {
    if (salary.isIntern) {
      final internUnits = internLeaveCalendarUnitsFromRequests(
        userId: salary.userId,
        month: month,
        leaves: leaves,
      );
      return _computeIntern(
        salary: salary,
        workingWeekdays: workingWeekdays,
        presentDays: presentDays,
        month: month,
        internLeaveUnits: internUnits,
      );
    }
    final unpaidLeaveDays = unpaidLeaveDaysFromRequests(
      userId: salary.userId,
      month: month,
      leaves: leaves,
    );
    return _computeEmployee(
      salary: salary,
      workingWeekdays: workingWeekdays,
      presentDays: presentDays,
      unpaidLeaveDays: unpaidLeaveDays,
      month: month,
      employeeDateOfBirth: employeeDateOfBirth,
    );
  }

  static PayrollComputedAmounts _computeIntern({
    required PayrollSalarySetting salary,
    required int workingWeekdays,
    required int presentDays,
    required DateTime month,
    required double internLeaveUnits,
  }) {
    final calDays = calendarDaysInMonth(month);
    final denom = calDays > 0 ? calDays : 1;
    final allowanceAmount = round2(salary.fixedAllowance);
    final commissionAmount = round2(salary.monthlyCommission);
    final incentiveAmount = round2(salary.monthlyIncentive);
    final incrementAmount = round2(salary.monthlyIncrement);
    final totalPool =
        allowanceAmount + commissionAmount + incentiveAmount + incrementAmount;
    final daily = totalPool / denom;
    var leaveDeduction = round2(daily * internLeaveUnits);
    if (leaveDeduction > totalPool) {
      leaveDeduction = totalPool;
    }
    final grossPay = round2(totalPool - leaveDeduction);

    final wd = workingWeekdays > 0 ? workingWeekdays : 22;
    return PayrollComputedAmounts(
      basicAmount: 0,
      allowanceAmount: allowanceAmount,
      commissionAmount: commissionAmount,
      incentiveAmount: incentiveAmount,
      incrementAmount: incrementAmount,
      otAmount: 0,
      unpaidLeaveDeduction: leaveDeduction,
      epfEmployee: 0,
      epfEmployer: 0,
      socsoEmployee: 0,
      socsoEmployer: 0,
      eisEmployee: 0,
      eisEmployer: 0,
      grossPay: grossPay,
      totalDeduction: leaveDeduction,
      netSalary: grossPay,
      calcNote:
          'kind=intern cal_d=$calDays present=$presentDays leave_u=$internLeaveUnits WD=$wd epf=${salary.epfCategory}',
    );
  }

  static PayrollComputedAmounts _computeEmployee({
    required PayrollSalarySetting salary,
    required int workingWeekdays,
    required int presentDays,
    required double unpaidLeaveDays,
    required DateTime month,
    DateTime? employeeDateOfBirth,
  }) {
    final wd = workingWeekdays > 0 ? workingWeekdays : 22;
    final basicAmount = round2(salary.basicSalary);
    final allowanceAmount = round2(salary.fixedAllowance);
    final commissionAmount = round2(salary.monthlyCommission);
    final incentiveAmount = round2(salary.monthlyIncentive);
    final incrementAmount = round2(salary.monthlyIncrement);
    final addOnTotal =
        allowanceAmount + commissionAmount + incentiveAmount + incrementAmount;
    final monthlyNormalComp = basicAmount + addOnTotal;
    final dailyRate = monthlyNormalComp / wd;
    final unpaidDeduction = round2(dailyRate * unpaidLeaveDays);

    // Chargeable monthly wages approximation for statutory tables. Unpaid
    // leave reduces the wage base before Malaysia statutory lookup.
    var statutoryBase = basicAmount + addOnTotal - unpaidDeduction;
    if (statutoryBase < 0) statutoryBase = 0;

    final grossPay = round2(basicAmount + addOnTotal - unpaidDeduction);

    final statutoryAmounts = PayrollCalculator.computeMalaysiaStatutory(
      wageBase: statutoryBase,
      month: month,
      salary: salary,
      employeeDateOfBirth: employeeDateOfBirth,
    );

    final totalDeduction = round2(
      unpaidDeduction +
          statutoryAmounts.epfEmployee +
          statutoryAmounts.socsoEmployee +
          statutoryAmounts.eisEmployee,
    );
    final net = round2(
      grossPay -
          statutoryAmounts.epfEmployee -
          statutoryAmounts.socsoEmployee -
          statutoryAmounts.eisEmployee,
    );

    return PayrollComputedAmounts(
      basicAmount: basicAmount,
      allowanceAmount: allowanceAmount,
      commissionAmount: commissionAmount,
      incentiveAmount: incentiveAmount,
      incrementAmount: incrementAmount,
      otAmount: 0,
      unpaidLeaveDeduction: unpaidDeduction,
      epfEmployee: statutoryAmounts.epfEmployee,
      epfEmployer: statutoryAmounts.epfEmployer,
      socsoEmployee: statutoryAmounts.socsoEmployee,
      socsoEmployer: statutoryAmounts.socsoEmployer,
      eisEmployee: statutoryAmounts.eisEmployee,
      eisEmployer: statutoryAmounts.eisEmployer,
      grossPay: grossPay,
      totalDeduction: totalDeduction,
      netSalary: net,
      calcNote:
          'kind=employee MY statutory WD=$wd present=$presentDays unpaid_d=$unpaidLeaveDays base=${round2(statutoryBase)} epf=${salary.epfCategory} socso=${salary.socsoCategory}',
    );
  }
}

class PayrollComputedAmounts {
  PayrollComputedAmounts({
    required this.basicAmount,
    required this.allowanceAmount,
    required this.commissionAmount,
    required this.incentiveAmount,
    required this.incrementAmount,
    required this.otAmount,
    required this.unpaidLeaveDeduction,
    required this.epfEmployee,
    required this.epfEmployer,
    required this.socsoEmployee,
    required this.socsoEmployer,
    required this.eisEmployee,
    required this.eisEmployer,
    required this.grossPay,
    required this.totalDeduction,
    required this.netSalary,
    required this.calcNote,
  });

  final double basicAmount;
  final double allowanceAmount;
  final double commissionAmount;
  final double incentiveAmount;
  final double incrementAmount;
  final double otAmount;
  final double unpaidLeaveDeduction;
  final double epfEmployee;
  final double epfEmployer;
  final double socsoEmployee;
  final double socsoEmployer;
  final double eisEmployee;
  final double eisEmployer;
  final double grossPay;
  final double totalDeduction;
  final double netSalary;
  final String calcNote;
}

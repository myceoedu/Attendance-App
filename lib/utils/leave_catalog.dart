import 'package:flutter/material.dart';

import '../models/leave_request.dart';

/// Canonical leave type IDs stored in [LeaveRequest.leaveType] / `leave_requests.leave_type`.
abstract final class LeaveCatalog {
  static const String annual = 'annual';
  static const String annualHalfAm = 'annual_half_am';
  static const String annualHalfPm = 'annual_half_pm';
  static const String sick = 'sick';
  static const String emergency = 'emergency';
  static const String unpaid = 'unpaid';
  static const String maternity = 'maternity';
  static const String paternity = 'paternity';
  static const String marriage = 'marriage';
  static const String publicHoliday = 'public_holiday';

  static const Set<String> all = {
    annual,
    annualHalfAm,
    annualHalfPm,
    sick,
    emergency,
    unpaid,
    maternity,
    paternity,
    marriage,
    publicHoliday,
  };

  /// Types that consume the employee's **annual leave balance** (incl. half-days).
  static const Set<String> consumesAnnualBalance = {
    annual,
    annualHalfAm,
    annualHalfPm,
  };

  static const Set<String> otherLeaveTypes = {
    sick,
    emergency,
    unpaid,
    maternity,
    paternity,
    marriage,
    publicHoliday,
  };

  static const List<String> orderedOtherTypes = [
    sick,
    emergency,
    unpaid,
    maternity,
    paternity,
    marriage,
    publicHoliday,
  ];

  static const List<String> orderedAllTypes = [
    annual,
    annualHalfAm,
    annualHalfPm,
    sick,
    emergency,
    unpaid,
    maternity,
    paternity,
    marriage,
    publicHoliday,
  ];

  static bool consumesAnnual(String leaveType) =>
      consumesAnnualBalance.contains(leaveType);

  static bool isHalfDayAnnual(String leaveType) =>
      leaveType == annualHalfAm || leaveType == annualHalfPm;

  /// Leave types that **reduce monthly pay** in payroll (unpaid weekdays only).
  ///
  /// Annual, sick, emergency, maternity, etc. are treated as **paid** for the MVP
  /// payroll engine — no salary deduction. Only [unpaid] (and explicit `no_pay`
  /// aliases if stored) triggers a deduction.
  static bool isPayrollUnpaidDeduction(String leaveType) {
    final t = leaveType.toLowerCase().trim();
    return t == unpaid || t == 'no_pay' || t == 'no-pay';
  }

  /// Approved leave blocks clock-in for the whole day unless it is half-day annual.
  static bool blocksFullDayClockIn(String leaveType) =>
      !isHalfDayAnnual(leaveType);

  static bool requiresMcAttachment(String leaveType) => leaveType == sick;

  static String displayName(String leaveType) {
    switch (leaveType) {
      case annual:
        return 'Annual leave (full day)';
      case annualHalfAm:
        return 'Annual leave (half day, AM)';
      case annualHalfPm:
        return 'Annual leave (half day, PM)';
      case sick:
        return 'Sick leave';
      case emergency:
        return 'Emergency leave';
      case unpaid:
        return 'Unpaid leave';
      case maternity:
        return 'Maternity leave';
      case paternity:
        return 'Paternity leave';
      case marriage:
        return 'Marriage leave';
      case publicHoliday:
        return 'Public holiday / replacement';
      default:
        return leaveType;
    }
  }

  static String durationLabel(LeaveRequest r) {
    if (isHalfDayAnnual(r.leaveType)) return 'Half day';
    final d = r.durationDays;
    return '$d day${d == 1 ? '' : 's'}';
  }

  /// Annual balance “charge” for one calendar year — must match SQL [annual_leave_credit_in_year].
  static double annualCreditInYear(
    String leaveType,
    DateTime start,
    DateTime end,
    int year,
  ) {
    if (!consumesAnnual(leaveType)) return 0;

    final ds = DateTime(start.year, start.month, start.day);
    final de = DateTime(end.year, end.month, end.day);
    final yStart = DateTime(year, 1, 1);
    final yEnd = DateTime(year, 12, 31);

    if (isHalfDayAnnual(leaveType)) {
      if (ds != de) return 0;
      if (de.isBefore(yStart) || ds.isAfter(yEnd)) return 0;
      return 0.5;
    }

    if (de.isBefore(yStart) || ds.isAfter(yEnd)) return 0;
    var effStart = ds.isBefore(yStart) ? yStart : ds;
    var effEnd = de.isAfter(yEnd) ? yEnd : de;
    if (effEnd.isBefore(effStart)) return 0;
    return (effEnd.difference(effStart).inDays + 1).toDouble();
  }

  static LeaveTypeStyle uiStyle(String leaveType) {
    switch (leaveType) {
      case annual:
        return LeaveTypeStyle(
          color: const Color(0xFF0EA5E9),
          icon: Icons.beach_access_rounded,
        );
      case annualHalfAm:
        return LeaveTypeStyle(
          color: const Color(0xFF0284C7),
          icon: Icons.wb_sunny_outlined,
        );
      case annualHalfPm:
        return LeaveTypeStyle(
          color: const Color(0xFF0369A1),
          icon: Icons.nights_stay_outlined,
        );
      case sick:
        return LeaveTypeStyle(
          color: const Color(0xFFEC4899),
          icon: Icons.local_hospital_rounded,
        );
      case emergency:
        return LeaveTypeStyle(
          color: const Color(0xFFF97316),
          icon: Icons.warning_amber_rounded,
        );
      case unpaid:
        return LeaveTypeStyle(
          color: const Color(0xFF64748B),
          icon: Icons.payments_outlined,
        );
      case maternity:
        return LeaveTypeStyle(
          color: const Color(0xFFC026D3),
          icon: Icons.pregnant_woman_rounded,
        );
      case paternity:
        return LeaveTypeStyle(
          color: const Color(0xFF7C3AED),
          icon: Icons.child_care_rounded,
        );
      case marriage:
        return LeaveTypeStyle(
          color: const Color(0xFFDB2777),
          icon: Icons.favorite_rounded,
        );
      case publicHoliday:
        return LeaveTypeStyle(
          color: const Color(0xFF059669),
          icon: Icons.flag_rounded,
        );
      default:
        return LeaveTypeStyle(
          color: const Color(0xFF6366F1),
          icon: Icons.event_note_rounded,
        );
    }
  }
}

class LeaveTypeStyle {
  const LeaveTypeStyle({required this.color, required this.icon});

  final Color color;
  final IconData icon;
}

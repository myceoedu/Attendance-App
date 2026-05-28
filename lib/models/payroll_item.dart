import '../utils/payroll_additional_pay.dart';

class PayrollItem {
  PayrollItem({
    required this.id,
    required this.payrollRunId,
    required this.userId,
    required this.employeeNameSnapshot,
    required this.workingWeekdays,
    required this.presentDays,
    required this.otHours,
    required this.unpaidLeaveDays,
    required this.compensationType,
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
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String payrollRunId;
  final String userId;
  final String employeeNameSnapshot;
  final int workingWeekdays;
  final int presentDays;
  final double otHours;
  final double unpaidLeaveDays;
  /// Snapshot: `employee` or `intern` at calculation time.
  final String compensationType;
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
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isIntern =>
      compensationType.trim().toLowerCase() == 'intern';

  double get addOnSubtotal =>
      allowanceAmount + commissionAmount + incentiveAmount + incrementAmount;

  /// Basic + all add-ons + OT (before leave deduction). OT is always zero.
  double get earningsSubtotal =>
      basicAmount + addOnSubtotal + otAmount;

  /// EPF + SOCSO + EIS (employee) only — what statutory rows take from [grossPay].
  double get statutoryEmployeeDeductions =>
      epfEmployee + socsoEmployee + eisEmployee;

  List<MapEntry<String, double>> get variablePayEarningsLines =>
      PayrollAdditionalPay.componentEarningLines(
        allowanceAmount: allowanceAmount,
        commissionAmount: commissionAmount,
        incentiveAmount: incentiveAmount,
        incrementAmount: incrementAmount,
      );

  factory PayrollItem.fromMap(Map<String, dynamic> map) {
    return PayrollItem(
      id: map['id'] as String,
      payrollRunId: map['payroll_run_id'] as String,
      userId: map['user_id'] as String,
      employeeNameSnapshot: map['employee_name_snapshot'] as String? ?? '',
      workingWeekdays: map['working_weekdays'] as int? ?? 0,
      presentDays: map['present_days'] as int? ?? 0,
      otHours: _num(map['ot_hours']),
      unpaidLeaveDays: _num(map['unpaid_leave_days']),
      compensationType: map['compensation_type'] as String? ?? 'employee',
      basicAmount: _num(map['basic_amount']),
      allowanceAmount: _num(map['allowance_amount']),
      commissionAmount: _num(map['commission_amount']),
      incentiveAmount: _num(map['incentive_amount']),
      incrementAmount: _num(map['increment_amount']),
      otAmount: _num(map['ot_amount']),
      unpaidLeaveDeduction: _num(map['unpaid_leave_deduction']),
      epfEmployee: _num(map['epf_employee']),
      epfEmployer: _num(map['epf_employer']),
      socsoEmployee: _num(map['socso_employee']),
      socsoEmployer: _num(map['socso_employer']),
      eisEmployee: _num(map['eis_employee']),
      eisEmployer: _num(map['eis_employer']),
      grossPay: _num(map['gross_pay']),
      totalDeduction: _num(map['total_deduction']),
      netSalary: _num(map['net_salary']),
      calcNote: map['calc_note'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toUpdateAmountsMap() {
    return {
      'ot_hours': otHours,
      'unpaid_leave_days': unpaidLeaveDays,
      'compensation_type': compensationType,
      'basic_amount': basicAmount,
      'allowance_amount': allowanceAmount,
      'commission_amount': commissionAmount,
      'incentive_amount': incentiveAmount,
      'increment_amount': incrementAmount,
      'ot_amount': otAmount,
      'unpaid_leave_deduction': unpaidLeaveDeduction,
      'epf_employee': epfEmployee,
      'epf_employer': epfEmployer,
      'socso_employee': socsoEmployee,
      'socso_employer': socsoEmployer,
      'eis_employee': eisEmployee,
      'eis_employer': eisEmployer,
      'gross_pay': grossPay,
      'total_deduction': totalDeduction,
      'net_salary': netSalary,
      'calc_note': calcNote,
    };
  }

  static double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }
}

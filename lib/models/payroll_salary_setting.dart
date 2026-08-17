import '../utils/employment_status.dart';

class PayrollSalarySetting {
  PayrollSalarySetting({
    required this.userId,
    required this.staffId,
    required this.department,
    required this.position,
    required this.employmentStatus,
    required this.basicSalary,
    required this.fixedAllowance,
    required this.monthlyCommission,
    required this.monthlyIncentive,
    required this.monthlyIncrement,
    required this.otEligible,
    required this.compensationType,
    required this.epfCategory,
    required this.socsoCategory,
    required this.eisEligible,
    required this.paymentMethod,
    required this.bankName,
    required this.bankAccountNumber,
    required this.payrollStatus,
    required this.updatedAt,
  });

  final String userId;
  final String staffId;
  final String department;
  final String position;

  /// HR category: permanent, contract, probation, intern, part_time.
  final String employmentStatus;
  final double basicSalary;
  final double fixedAllowance;
  final double monthlyCommission;
  final double monthlyIncentive;
  final double monthlyIncrement;
  final bool otEligible;

  /// `employee` (default) or `intern` (allowance / calendar leave; no statutory).
  final String compensationType;
  final String epfCategory;
  final String socsoCategory;
  final bool eisEligible;
  final String paymentMethod;
  final String bankName;
  final String bankAccountNumber;
  final String payrollStatus;
  final DateTime updatedAt;

  bool get isActive => payrollStatus == 'active';

  bool get isIntern => compensationType.trim().toLowerCase() == 'intern';

  /// Intern pay, intern status, probation, and part-time have no annual leave.
  bool get hasAnnualLeave =>
      !isIntern && EmploymentStatus.hasAnnualLeave(employmentStatus);

  double get totalMonthlyAddOns =>
      fixedAllowance + monthlyCommission + monthlyIncentive + monthlyIncrement;

  factory PayrollSalarySetting.fromMap(Map<String, dynamic> map) {
    return PayrollSalarySetting(
      userId: (map['user_id'] as String?) ?? '',
      staffId: map['staff_id'] as String? ?? '',
      department: map['department'] as String? ?? '',
      position: map['position'] as String? ?? '',
      employmentStatus: EmploymentStatus.normalize(map['employment_status']),
      basicSalary: _num(map['basic_salary']) ?? 0,
      fixedAllowance: _num(map['fixed_allowance']) ?? 0,
      monthlyCommission: _num(map['monthly_commission']) ?? 0,
      monthlyIncentive: _num(map['monthly_incentive']) ?? 0,
      monthlyIncrement: _num(map['monthly_increment']) ?? 0,
      otEligible: map['ot_eligible'] as bool? ?? true,
      compensationType: map['compensation_type'] as String? ?? 'employee',
      epfCategory: map['epf_category'] as String? ?? 'standard',
      socsoCategory: map['socso_category'] as String? ?? 'standard',
      eisEligible: map['eis_eligible'] as bool? ?? true,
      paymentMethod: map['payment_method'] as String? ?? 'bank_transfer',
      bankName: map['bank_name'] as String? ?? '',
      bankAccountNumber: map['bank_account_number'] as String? ?? '',
      payrollStatus: map['payroll_status'] as String? ?? 'active',
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  static DateTime _parseDateTime(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is String && v.isNotEmpty) {
      return DateTime.tryParse(v) ?? DateTime.now();
    }
    return DateTime.now();
  }

  Map<String, dynamic> toUpsertMap() {
    return {
      'user_id': userId,
      'staff_id': staffId,
      'department': department,
      'position': position,
      'employment_status': EmploymentStatus.normalize(employmentStatus),
      'basic_salary': basicSalary,
      'fixed_allowance': fixedAllowance,
      'monthly_commission': monthlyCommission,
      'monthly_incentive': monthlyIncentive,
      'monthly_increment': monthlyIncrement,
      'ot_eligible': otEligible,
      'compensation_type': compensationType,
      'epf_category': epfCategory,
      'socso_category': socsoCategory,
      'eis_eligible': eisEligible,
      'payment_method': paymentMethod,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'payroll_status': payrollStatus,
    };
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }
}

class PayrollRun {
  PayrollRun({
    required this.id,
    required this.periodYear,
    required this.periodMonth,
    required this.status,
    this.statutoryConfigId,
    this.payDate,
    required this.notes,
    this.totalNetPay,
    this.totalEmployerCost,
    this.employeeCount,
    this.createdBy,
    this.approvedBy,
    this.paidBy,
    this.approvedAt,
    this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final int periodYear;
  final int periodMonth;
  final String status;
  final String? statutoryConfigId;
  final DateTime? payDate;
  final String notes;
  final double? totalNetPay;
  final double? totalEmployerCost;
  final int? employeeCount;
  final String? createdBy;
  final String? approvedBy;
  final String? paidBy;
  final DateTime? approvedAt;
  final DateTime? paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDraft => status == 'draft';
  bool get isCalculated => status == 'calculated';
  bool get isApproved => status == 'approved';
  bool get isPaid => status == 'paid';

  factory PayrollRun.fromMap(Map<String, dynamic> map) {
    return PayrollRun(
      id: map['id'] as String,
      periodYear: (map['period_year'] as num).toInt(),
      periodMonth: (map['period_month'] as num).toInt(),
      status: map['status'] as String? ?? 'draft',
      statutoryConfigId: map['statutory_config_id'] as String?,
      payDate: map['pay_date'] != null
          ? DateTime.parse(map['pay_date'] as String)
          : null,
      notes: map['notes'] as String? ?? '',
      totalNetPay: _num(map['total_net_pay']),
      totalEmployerCost: _num(map['total_employer_cost']),
      employeeCount: map['employee_count'] as int?,
      createdBy: map['created_by'] as String?,
      approvedBy: map['approved_by'] as String?,
      paidBy: map['paid_by'] as String?,
      approvedAt: map['approved_at'] != null
          ? DateTime.parse(map['approved_at'] as String)
          : null,
      paidAt: map['paid_at'] != null
          ? DateTime.parse(map['paid_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }
}

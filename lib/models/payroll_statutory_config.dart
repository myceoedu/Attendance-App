class PayrollStatutoryConfig {
  PayrollStatutoryConfig({
    required this.id,
    required this.label,
    required this.effectiveFrom,
    required this.epfEmployeePct,
    required this.epfEmployerPct,
    this.epfSalaryCeiling,
    required this.socsoEmployeePct,
    required this.socsoEmployerPct,
    required this.eisEmployeePct,
    required this.eisEmployerPct,
    required this.otHourlyMultiplier,
    required this.standardHoursPerDay,
    required this.createdAt,
  });

  final String id;
  final String label;
  final DateTime effectiveFrom;
  final double epfEmployeePct;
  final double epfEmployerPct;
  final double? epfSalaryCeiling;
  final double socsoEmployeePct;
  final double socsoEmployerPct;
  final double eisEmployeePct;
  final double eisEmployerPct;
  final double otHourlyMultiplier;
  final double standardHoursPerDay;
  final DateTime createdAt;

  factory PayrollStatutoryConfig.fromMap(Map<String, dynamic> map) {
    return PayrollStatutoryConfig(
      id: map['id'] as String,
      label: map['label'] as String? ?? '',
      effectiveFrom: DateTime.parse(map['effective_from'] as String),
      epfEmployeePct: _num(map['epf_employee_pct']) ?? 11,
      epfEmployerPct: _num(map['epf_employer_pct']) ?? 13,
      epfSalaryCeiling: _num(map['epf_salary_ceiling']),
      socsoEmployeePct: _num(map['socso_employee_pct']) ?? 0.5,
      socsoEmployerPct: _num(map['socso_employer_pct']) ?? 1.75,
      eisEmployeePct: _num(map['eis_employee_pct']) ?? 0.2,
      eisEmployerPct: _num(map['eis_employer_pct']) ?? 0.2,
      otHourlyMultiplier: _num(map['ot_hourly_multiplier']) ?? 1.5,
      standardHoursPerDay: _num(map['standard_hours_per_day']) ?? 8,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toUpsertMap() {
    return {
      'label': label,
      'effective_from': _dateOnly(effectiveFrom),
      'epf_employee_pct': epfEmployeePct,
      'epf_employer_pct': epfEmployerPct,
      'epf_salary_ceiling': epfSalaryCeiling,
      'socso_employee_pct': socsoEmployeePct,
      'socso_employer_pct': socsoEmployerPct,
      'eis_employee_pct': eisEmployeePct,
      'eis_employer_pct': eisEmployerPct,
      'ot_hourly_multiplier': otHourlyMultiplier,
      'standard_hours_per_day': standardHoursPerDay,
    };
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  static String _dateOnly(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

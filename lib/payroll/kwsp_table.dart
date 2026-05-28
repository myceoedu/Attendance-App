/// EPF/KWSP contribution rules used by payroll.
///
/// Malaysia EPF remains percentage-based (not bracket table), split by age band
/// and wage threshold.
final class KwspTable {
  KwspTable._();

  static const double _employeePctUnder60 = 11.0;
  static const double _employerPctUnder60LowWage = 13.0;
  static const double _employerPctUnder60HighWage = 12.0;
  static const double _employerPctAge60LowWage = 6.5;
  static const double _employerPctAge60HighWage = 6.0;
  static const double _threshold = 5000.0;

  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  static KwspContribution lookup({
    required double wageBase,
    required bool age60OrAbove,
  }) {
    if (wageBase <= 0) return const KwspContribution.zero();

    if (age60OrAbove) {
      final employerPct = wageBase <= _threshold
          ? _employerPctAge60LowWage
          : _employerPctAge60HighWage;
      return KwspContribution(
        employee: 0,
        employer: _round2(wageBase * employerPct / 100),
      );
    }

    final employerPct = wageBase <= _threshold
        ? _employerPctUnder60LowWage
        : _employerPctUnder60HighWage;
    return KwspContribution(
      employee: _round2(wageBase * _employeePctUnder60 / 100),
      employer: _round2(wageBase * employerPct / 100),
    );
  }
}

class KwspContribution {
  const KwspContribution({
    required this.employee,
    required this.employer,
  });

  const KwspContribution.zero()
      : employee = 0,
        employer = 0;

  final double employee;
  final double employer;
}


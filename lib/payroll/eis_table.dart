/// EIS/SIP contribution table lookup (employee and employer).
///
/// Uses official wage brackets instead of direct percentage multiplication.
final class EisTable {
  EisTable._();

  static const List<_EisBracket> _brackets = [
    _EisBracket(upperBound: 30, employee: 0.05, employer: 0.05),
    _EisBracket(upperBound: 50, employee: 0.10, employer: 0.10),
    _EisBracket(upperBound: 70, employee: 0.15, employer: 0.15),
    _EisBracket(upperBound: 100, employee: 0.20, employer: 0.20),
    _EisBracket(upperBound: 140, employee: 0.25, employer: 0.25),
    _EisBracket(upperBound: 200, employee: 0.35, employer: 0.35),
    _EisBracket(upperBound: 300, employee: 0.50, employer: 0.50),
    _EisBracket(upperBound: 400, employee: 0.70, employer: 0.70),
    _EisBracket(upperBound: 500, employee: 0.90, employer: 0.90),
    _EisBracket(upperBound: 600, employee: 1.10, employer: 1.10),
    _EisBracket(upperBound: 700, employee: 1.30, employer: 1.30),
    _EisBracket(upperBound: 800, employee: 1.50, employer: 1.50),
    _EisBracket(upperBound: 900, employee: 1.70, employer: 1.70),
    _EisBracket(upperBound: 1000, employee: 1.90, employer: 1.90),
    _EisBracket(upperBound: 1100, employee: 2.10, employer: 2.10),
    _EisBracket(upperBound: 1200, employee: 2.30, employer: 2.30),
    _EisBracket(upperBound: 1300, employee: 2.50, employer: 2.50),
    _EisBracket(upperBound: 1400, employee: 2.70, employer: 2.70),
    _EisBracket(upperBound: 1500, employee: 2.90, employer: 2.90),
    _EisBracket(upperBound: 1600, employee: 3.10, employer: 3.10),
    _EisBracket(upperBound: 1700, employee: 3.30, employer: 3.30),
    _EisBracket(upperBound: 1800, employee: 3.50, employer: 3.50),
    _EisBracket(upperBound: 1900, employee: 3.70, employer: 3.70),
    _EisBracket(upperBound: 2000, employee: 3.90, employer: 3.90),
    _EisBracket(upperBound: 2100, employee: 4.10, employer: 4.10),
    _EisBracket(upperBound: 2200, employee: 4.30, employer: 4.30),
    _EisBracket(upperBound: 2300, employee: 4.50, employer: 4.50),
    _EisBracket(upperBound: 2400, employee: 4.70, employer: 4.70),
    _EisBracket(upperBound: 2500, employee: 4.90, employer: 4.90),
    _EisBracket(upperBound: 2600, employee: 5.10, employer: 5.10),
    _EisBracket(upperBound: 2700, employee: 5.30, employer: 5.30),
    _EisBracket(upperBound: 2800, employee: 5.50, employer: 5.50),
    _EisBracket(upperBound: 2900, employee: 5.70, employer: 5.70),
    _EisBracket(upperBound: 3000, employee: 5.90, employer: 5.90),
    _EisBracket(upperBound: 3100, employee: 6.10, employer: 6.10),
    _EisBracket(upperBound: 3200, employee: 6.30, employer: 6.30),
    _EisBracket(upperBound: 3300, employee: 6.50, employer: 6.50),
    _EisBracket(upperBound: 3400, employee: 6.70, employer: 6.70),
    _EisBracket(upperBound: 3500, employee: 6.90, employer: 6.90),
    _EisBracket(upperBound: 3600, employee: 7.10, employer: 7.10),
    _EisBracket(upperBound: 3700, employee: 7.30, employer: 7.30),
    _EisBracket(upperBound: 3800, employee: 7.50, employer: 7.50),
    _EisBracket(upperBound: 3900, employee: 7.70, employer: 7.70),
    _EisBracket(upperBound: 4000, employee: 7.90, employer: 7.90),
    _EisBracket(upperBound: 4100, employee: 8.10, employer: 8.10),
    _EisBracket(upperBound: 4200, employee: 8.30, employer: 8.30),
    _EisBracket(upperBound: 4300, employee: 8.50, employer: 8.50),
    _EisBracket(upperBound: 4400, employee: 8.70, employer: 8.70),
    _EisBracket(upperBound: 4500, employee: 8.90, employer: 8.90),
    _EisBracket(upperBound: 4600, employee: 9.10, employer: 9.10),
    _EisBracket(upperBound: 4700, employee: 9.30, employer: 9.30),
    _EisBracket(upperBound: 4800, employee: 9.50, employer: 9.50),
    _EisBracket(upperBound: 4900, employee: 9.70, employer: 9.70),
    _EisBracket(upperBound: 5000, employee: 9.90, employer: 9.90),
    _EisBracket(upperBound: 5100, employee: 10.10, employer: 10.10),
    _EisBracket(upperBound: 5200, employee: 10.30, employer: 10.30),
    _EisBracket(upperBound: 5300, employee: 10.50, employer: 10.50),
    _EisBracket(upperBound: 5400, employee: 10.70, employer: 10.70),
    _EisBracket(upperBound: 5500, employee: 10.90, employer: 10.90),
    _EisBracket(upperBound: 5600, employee: 11.10, employer: 11.10),
    _EisBracket(upperBound: 5700, employee: 11.30, employer: 11.30),
    _EisBracket(upperBound: 5800, employee: 11.50, employer: 11.50),
    _EisBracket(upperBound: 5900, employee: 11.70, employer: 11.70),
    _EisBracket(upperBound: 6000, employee: 11.90, employer: 11.90),
    _EisBracket(upperBound: double.infinity, employee: 11.90, employer: 11.90),
  ];

  static EisContribution lookup({required double wageBase}) {
    if (wageBase <= 0) return const EisContribution.zero();
    final bracket = _brackets.firstWhere((b) => wageBase <= b.upperBound);
    return EisContribution(
      employee: bracket.employee,
      employer: bracket.employer,
    );
  }
}

class EisContribution {
  const EisContribution({
    required this.employee,
    required this.employer,
  });

  const EisContribution.zero()
      : employee = 0,
        employer = 0;

  final double employee;
  final double employer;
}

class _EisBracket {
  const _EisBracket({
    required this.upperBound,
    required this.employee,
    required this.employer,
  });

  final double upperBound;
  final double employee;
  final double employer;
}


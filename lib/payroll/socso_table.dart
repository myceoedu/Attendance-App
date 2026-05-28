/// PERKESO/SOCSO contribution table lookup.
///
/// Uses wage brackets (not percentage formula) so payroll matches official
/// contribution schedules.
final class SocsoTable {
  SocsoTable._();

  /// Official wage brackets (effective Jun 2026 table shape used by app).
  ///
  /// - `firstEmployee` and `firstEmployer`: category 1 (<60 by default)
  /// - `secondEmployer`: category 2 (employer-only in app payroll policy)
  static const List<_SocsoBracket> _brackets = [
    _SocsoBracket(upperBound: 30, firstEmployee: 0.10, firstEmployer: 0.40, secondEmployer: 0.30),
    _SocsoBracket(upperBound: 50, firstEmployee: 0.20, firstEmployer: 0.70, secondEmployer: 0.50),
    _SocsoBracket(upperBound: 70, firstEmployee: 0.30, firstEmployer: 1.10, secondEmployer: 0.80),
    _SocsoBracket(upperBound: 100, firstEmployee: 0.40, firstEmployer: 1.50, secondEmployer: 1.10),
    _SocsoBracket(upperBound: 140, firstEmployee: 0.60, firstEmployer: 2.10, secondEmployer: 1.50),
    _SocsoBracket(upperBound: 200, firstEmployee: 0.85, firstEmployer: 2.95, secondEmployer: 2.10),
    _SocsoBracket(upperBound: 300, firstEmployee: 1.25, firstEmployer: 4.35, secondEmployer: 3.10),
    _SocsoBracket(upperBound: 400, firstEmployee: 1.75, firstEmployer: 6.15, secondEmployer: 4.40),
    _SocsoBracket(upperBound: 500, firstEmployee: 2.25, firstEmployer: 7.85, secondEmployer: 5.60),
    _SocsoBracket(upperBound: 600, firstEmployee: 2.75, firstEmployer: 9.65, secondEmployer: 6.90),
    _SocsoBracket(upperBound: 700, firstEmployee: 3.25, firstEmployer: 11.35, secondEmployer: 8.10),
    _SocsoBracket(upperBound: 800, firstEmployee: 3.75, firstEmployer: 13.15, secondEmployer: 9.40),
    _SocsoBracket(upperBound: 900, firstEmployee: 4.25, firstEmployer: 14.85, secondEmployer: 10.60),
    _SocsoBracket(upperBound: 1000, firstEmployee: 4.75, firstEmployer: 16.65, secondEmployer: 11.90),
    _SocsoBracket(upperBound: 1100, firstEmployee: 5.25, firstEmployer: 18.35, secondEmployer: 13.10),
    _SocsoBracket(upperBound: 1200, firstEmployee: 5.75, firstEmployer: 20.15, secondEmployer: 14.40),
    _SocsoBracket(upperBound: 1300, firstEmployee: 6.25, firstEmployer: 21.85, secondEmployer: 15.60),
    _SocsoBracket(upperBound: 1400, firstEmployee: 6.75, firstEmployer: 23.65, secondEmployer: 16.90),
    _SocsoBracket(upperBound: 1500, firstEmployee: 7.25, firstEmployer: 25.35, secondEmployer: 18.10),
    _SocsoBracket(upperBound: 1600, firstEmployee: 7.75, firstEmployer: 27.15, secondEmployer: 19.40),
    _SocsoBracket(upperBound: 1700, firstEmployee: 8.25, firstEmployer: 28.85, secondEmployer: 20.60),
    _SocsoBracket(upperBound: 1800, firstEmployee: 8.75, firstEmployer: 30.65, secondEmployer: 21.90),
    _SocsoBracket(upperBound: 1900, firstEmployee: 9.25, firstEmployer: 32.35, secondEmployer: 23.10),
    _SocsoBracket(upperBound: 2000, firstEmployee: 9.75, firstEmployer: 34.15, secondEmployer: 24.40),
    _SocsoBracket(upperBound: 2100, firstEmployee: 10.25, firstEmployer: 35.85, secondEmployer: 25.60),
    _SocsoBracket(upperBound: 2200, firstEmployee: 10.75, firstEmployer: 37.65, secondEmployer: 26.90),
    _SocsoBracket(upperBound: 2300, firstEmployee: 11.25, firstEmployer: 39.35, secondEmployer: 28.10),
    _SocsoBracket(upperBound: 2400, firstEmployee: 11.75, firstEmployer: 41.15, secondEmployer: 29.40),
    _SocsoBracket(upperBound: 2500, firstEmployee: 12.25, firstEmployer: 42.85, secondEmployer: 30.60),
    _SocsoBracket(upperBound: 2600, firstEmployee: 12.75, firstEmployer: 44.65, secondEmployer: 31.90),
    _SocsoBracket(upperBound: 2700, firstEmployee: 13.25, firstEmployer: 46.35, secondEmployer: 33.10),
    _SocsoBracket(upperBound: 2800, firstEmployee: 13.75, firstEmployer: 48.15, secondEmployer: 34.40),
    _SocsoBracket(upperBound: 2900, firstEmployee: 14.25, firstEmployer: 49.85, secondEmployer: 35.60),
    _SocsoBracket(upperBound: 3000, firstEmployee: 14.75, firstEmployer: 51.65, secondEmployer: 36.90),
    _SocsoBracket(upperBound: 3100, firstEmployee: 15.25, firstEmployer: 53.35, secondEmployer: 38.10),
    _SocsoBracket(upperBound: 3200, firstEmployee: 15.75, firstEmployer: 55.15, secondEmployer: 39.40),
    _SocsoBracket(upperBound: 3300, firstEmployee: 16.25, firstEmployer: 56.85, secondEmployer: 40.60),
    _SocsoBracket(upperBound: 3400, firstEmployee: 16.75, firstEmployer: 58.65, secondEmployer: 41.90),
    _SocsoBracket(upperBound: 3500, firstEmployee: 17.25, firstEmployer: 60.35, secondEmployer: 43.10),
    _SocsoBracket(upperBound: 3600, firstEmployee: 17.75, firstEmployer: 62.15, secondEmployer: 44.40),
    _SocsoBracket(upperBound: 3700, firstEmployee: 18.25, firstEmployer: 63.85, secondEmployer: 45.60),
    _SocsoBracket(upperBound: 3800, firstEmployee: 18.75, firstEmployer: 65.65, secondEmployer: 46.90),
    _SocsoBracket(upperBound: 3900, firstEmployee: 19.25, firstEmployer: 67.35, secondEmployer: 48.10),
    _SocsoBracket(upperBound: 4000, firstEmployee: 19.75, firstEmployer: 69.15, secondEmployer: 49.40),
    _SocsoBracket(upperBound: 4100, firstEmployee: 20.25, firstEmployer: 70.85, secondEmployer: 50.60),
    _SocsoBracket(upperBound: 4200, firstEmployee: 20.75, firstEmployer: 72.65, secondEmployer: 51.90),
    _SocsoBracket(upperBound: 4300, firstEmployee: 21.25, firstEmployer: 74.35, secondEmployer: 53.10),
    _SocsoBracket(upperBound: 4400, firstEmployee: 21.75, firstEmployer: 76.15, secondEmployer: 54.40),
    _SocsoBracket(upperBound: 4500, firstEmployee: 22.25, firstEmployer: 77.85, secondEmployer: 55.60),
    _SocsoBracket(upperBound: 4600, firstEmployee: 22.75, firstEmployer: 79.65, secondEmployer: 56.90),
    _SocsoBracket(upperBound: 4700, firstEmployee: 23.25, firstEmployer: 81.35, secondEmployer: 58.10),
    _SocsoBracket(upperBound: 4800, firstEmployee: 23.75, firstEmployer: 83.15, secondEmployer: 59.40),
    _SocsoBracket(upperBound: 4900, firstEmployee: 24.25, firstEmployer: 84.85, secondEmployer: 60.60),
    _SocsoBracket(upperBound: 5000, firstEmployee: 24.75, firstEmployer: 86.65, secondEmployer: 61.90),
    _SocsoBracket(upperBound: 5100, firstEmployee: 25.25, firstEmployer: 88.35, secondEmployer: 63.10),
    _SocsoBracket(upperBound: 5200, firstEmployee: 25.75, firstEmployer: 90.15, secondEmployer: 64.40),
    _SocsoBracket(upperBound: 5300, firstEmployee: 26.25, firstEmployer: 91.85, secondEmployer: 65.60),
    _SocsoBracket(upperBound: 5400, firstEmployee: 26.75, firstEmployer: 93.65, secondEmployer: 66.90),
    _SocsoBracket(upperBound: 5500, firstEmployee: 27.25, firstEmployer: 95.35, secondEmployer: 68.10),
    _SocsoBracket(upperBound: 5600, firstEmployee: 27.75, firstEmployer: 97.15, secondEmployer: 69.40),
    _SocsoBracket(upperBound: 5700, firstEmployee: 28.25, firstEmployer: 98.85, secondEmployer: 70.60),
    _SocsoBracket(upperBound: 5800, firstEmployee: 28.75, firstEmployer: 100.65, secondEmployer: 71.90),
    _SocsoBracket(upperBound: 5900, firstEmployee: 29.25, firstEmployer: 102.35, secondEmployer: 73.10),
    _SocsoBracket(upperBound: 6000, firstEmployee: 29.75, firstEmployer: 104.15, secondEmployer: 74.40),
    _SocsoBracket(upperBound: double.infinity, firstEmployee: 29.75, firstEmployer: 104.15, secondEmployer: 74.40),
  ];

  static SocsoContribution lookup({
    required double wageBase,
    required bool secondCategory,
  }) {
    if (wageBase <= 0) return const SocsoContribution.zero();
    final bracket = _brackets.firstWhere((b) => wageBase <= b.upperBound);
    if (secondCategory) {
      return SocsoContribution(
        // App policy keeps category-2 as employer-only deduction.
        employee: 0,
        employer: bracket.secondEmployer,
      );
    }
    return SocsoContribution(
      employee: bracket.firstEmployee,
      employer: bracket.firstEmployer,
    );
  }
}

class SocsoContribution {
  const SocsoContribution({
    required this.employee,
    required this.employer,
  });

  const SocsoContribution.zero()
      : employee = 0,
        employer = 0;

  final double employee;
  final double employer;
}

class _SocsoBracket {
  const _SocsoBracket({
    required this.upperBound,
    required this.firstEmployee,
    required this.firstEmployer,
    required this.secondEmployer,
  });

  final double upperBound;
  final double firstEmployee;
  final double firstEmployer;
  final double secondEmployer;
}


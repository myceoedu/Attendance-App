import '../models/payroll_salary_setting.dart';
import 'eis_table.dart';
import 'kwsp_table.dart';
import 'socso_table.dart';

class PayrollStatutoryAmounts {
  const PayrollStatutoryAmounts({
    required this.epfEmployee,
    required this.epfEmployer,
    required this.socsoEmployee,
    required this.socsoEmployer,
    required this.eisEmployee,
    required this.eisEmployer,
  });

  final double epfEmployee;
  final double epfEmployer;
  final double socsoEmployee;
  final double socsoEmployer;
  final double eisEmployee;
  final double eisEmployer;
}

/// Central Malaysia statutory calculator (KWSP + PERKESO + EIS).
///
/// - KWSP: percentage rules by age/wage threshold
/// - SOCSO/EIS: official wage-bracket table lookup
final class PayrollCalculator {
  PayrollCalculator._();

  static int? _ageAt(DateTime? dateOfBirth, DateTime month) {
    if (dateOfBirth == null) return null;
    final asOf = DateTime(month.year, month.month + 1, 0);
    var age = asOf.year - dateOfBirth.year;
    final birthdayThisYear = DateTime(asOf.year, dateOfBirth.month, dateOfBirth.day);
    if (birthdayThisYear.isAfter(asOf)) age--;
    return age;
  }

  static bool _epfIsAbove60Band(String category) {
    switch (category.trim().toLowerCase()) {
      case 'above60':
      case 'above_60':
      case '60+':
      case 'age60':
        return true;
      default:
        return false;
    }
  }

  static bool _socsoIsSecondCategory(String category) {
    final c = category.trim().toLowerCase();
    return c == 'second' ||
        c == 'second_category' ||
        c == 'category2' ||
        c == 'employer_only' ||
        c == 'above60' ||
        c == '60+';
  }

  static bool _isAge60OrAbove({
    required DateTime month,
    required PayrollSalarySetting salary,
    DateTime? employeeDateOfBirth,
  }) {
    final age = _ageAt(employeeDateOfBirth, month);
    if (age != null) return age >= 60;
    return _epfIsAbove60Band(salary.epfCategory);
  }

  static PayrollStatutoryAmounts computeMalaysiaStatutory({
    required double wageBase,
    required DateTime month,
    required PayrollSalarySetting salary,
    DateTime? employeeDateOfBirth,
  }) {
    final age60OrAbove = _isAge60OrAbove(
      month: month,
      salary: salary,
      employeeDateOfBirth: employeeDateOfBirth,
    );

    final kwsp = KwspTable.lookup(
      wageBase: wageBase,
      age60OrAbove: age60OrAbove,
    );
    final socso = SocsoTable.lookup(
      wageBase: wageBase,
      secondCategory: age60OrAbove || _socsoIsSecondCategory(salary.socsoCategory),
    );
    final eis = (!salary.eisEligible || age60OrAbove)
        ? const EisContribution.zero()
        : EisTable.lookup(wageBase: wageBase);

    return PayrollStatutoryAmounts(
      epfEmployee: kwsp.employee,
      epfEmployer: kwsp.employer,
      socsoEmployee: socso.employee,
      socsoEmployer: socso.employer,
      eisEmployee: eis.employee,
      eisEmployer: eis.employer,
    );
  }
}


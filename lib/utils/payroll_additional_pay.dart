/// Labels for salary add-on components (besides basic).
abstract final class PayrollAdditionalPay {
  static const allowance = 'allowance';
  static const commission = 'commission';
  static const incentive = 'incentive';
  static const increment = 'increment';

  static const Set<String> kinds = {
    allowance,
    commission,
    incentive,
    increment,
  };

  static String normalizeKind(String? raw) {
    final k = (raw ?? '').trim().toLowerCase();
    if (kinds.contains(k)) return k;
    return allowance;
  }

  static String displayLabel(String? kind) {
    switch (normalizeKind(kind)) {
      case commission:
        return 'Commission';
      case incentive:
        return 'Incentive';
      case increment:
        return 'Increment';
      default:
        return 'Allowance';
    }
  }

  /// Ordered payslip rows for non-zero components (Allowance → Commission → Incentive → Increment).
  static List<MapEntry<String, double>> componentEarningLines({
    required double allowanceAmount,
    required double commissionAmount,
    required double incentiveAmount,
    required double incrementAmount,
  }) {
    final out = <MapEntry<String, double>>[];
    if (allowanceAmount > 0) {
      out.add(MapEntry(displayLabel(allowance), allowanceAmount));
    }
    if (commissionAmount > 0) {
      out.add(MapEntry(displayLabel(commission), commissionAmount));
    }
    if (incentiveAmount > 0) {
      out.add(MapEntry(displayLabel(incentive), incentiveAmount));
    }
    if (incrementAmount > 0) {
      out.add(MapEntry(displayLabel(increment), incrementAmount));
    }
    return out;
  }
}

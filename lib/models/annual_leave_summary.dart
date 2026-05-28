/// Row from RPC [get_annual_leave_summary].
class AnnualLeaveSummary {
  final double entitlement;
  final double used;
  final double pending;
  final double remaining;

  AnnualLeaveSummary({
    required this.entitlement,
    required this.used,
    required this.pending,
    required this.remaining,
  });

  factory AnnualLeaveSummary.fromRpc(Map<String, dynamic> map) {
    double n(String key) {
      final v = map[key];
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? 0;
    }

    return AnnualLeaveSummary(
      entitlement: n('entitlement'),
      used: n('used'),
      pending: n('pending'),
      remaining: n('remaining'),
    );
  }
}

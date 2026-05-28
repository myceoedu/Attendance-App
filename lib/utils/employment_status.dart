/// HR employment category on [PayrollSalarySetting] (separate from payroll compensation_type).
abstract final class EmploymentStatus {
  static const permanent = 'permanent';
  static const contract = 'contract';
  static const probation = 'probation';
  static const intern = 'intern';
  static const partTime = 'part_time';

  static const List<String> codes = [
    permanent,
    contract,
    probation,
    intern,
    partTime,
  ];

  static String normalize(dynamic raw) {
    if (raw == null) return permanent;
    var v = raw.toString().trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
    if (v == 'parttime') v = partTime;
    if (codes.contains(v)) return v;
    return permanent;
  }

  static String label(String code) {
    switch (normalize(code)) {
      case contract:
        return 'Contract';
      case probation:
        return 'Probation';
      case intern:
        return 'Intern';
      case partTime:
        return 'Part time';
      default:
        return 'Permanent';
    }
  }
}

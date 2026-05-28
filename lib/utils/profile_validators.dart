/// Validation helpers for Malaysia-centric employee profile forms.
class ProfileValidators {
  ProfileValidators._();

  static final _email = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// NRIC: 12 digits, optional hyphens (######-##-####).
  static final _icLoose = RegExp(r'^\d{6}-?\d{2}-?\d{4}$');

  static String? requiredName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Full name is required';
    return null;
  }

  static String? emailOptional(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    if (!_email.hasMatch(v.trim())) return 'Enter a valid email';
    return null;
  }

  static String? phoneMalaysia(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final digits = v.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9 || digits.length > 11) {
      return 'Enter a valid mobile number';
    }
    return null;
  }

  static String? phoneRequiredForEmergency(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'Emergency phone is required if contact name is set';
    }
    return phoneMalaysia(v);
  }

  static String? icNumber(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final s = v.trim();
    if (!_icLoose.hasMatch(s)) {
      return 'Use NRIC format: ######-##-####';
    }
    return null;
  }

  static String? bankAccount(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final digits = v.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^\d+$').hasMatch(digits)) {
      return 'Account number should be numeric';
    }
    if (digits.length < 5 || digits.length > 20) {
      return 'Enter a valid account number';
    }
    return null;
  }

  /// Masks NRIC for display: ******-**-1234 when 12 digits.
  static String displayIcMasked(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length < 4) return '••••••••';
    final tail = d.substring(d.length - 4);
    if (d.length >= 12) return '******-**-$tail';
    return '${'•' * (d.length - 4)}$tail';
  }

  static String displayBankMasked(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return '••••';
    final tail = digits.substring(digits.length - 4);
    return '••••••$tail';
  }

  static String displayValue(String? raw, {required bool editing}) {
    if (editing) return raw ?? '';
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return 'Not updated yet';
    return t;
  }
}

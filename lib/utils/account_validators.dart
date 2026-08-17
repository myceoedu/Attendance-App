/// Shared rules for login accounts (register + admin add employee).
class AccountValidators {
  AccountValidators._();

  static final _email = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static final _usernameChars = RegExp(
    r"^[\p{L}\p{N} .'_\-]+$",
    unicode: true,
  );

  static String? fullName(String? v) {
    final t = (v ?? '').trim();
    if (t.length < 2) return 'Enter the full name';
    if (t.length > 80) return 'Max 80 characters';
    return null;
  }

  static String? email(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Required';
    if (!_email.hasMatch(t)) return 'Enter a valid email';
    return null;
  }

  static String? username(String? v) {
    final t = (v ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.length < 3) return 'At least 3 characters';
    if (t.length > 64) return 'Max 64 characters';
    if (!_usernameChars.hasMatch(t)) {
      return "Use letters, numbers, spaces, or . ' - _";
    }
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.length < 6) return 'Min 6 characters';
    if (v.length > 72) return 'Max 72 characters';
    return null;
  }

  static String? confirmPassword(String? v, String password) {
    if (v != password) return 'Passwords do not match';
    return null;
  }
}

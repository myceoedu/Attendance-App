import 'package:flutter/foundation.dart';

/// Auth email-link helpers (password recovery / redirects).
abstract final class AuthRedirect {
  /// Production web app origin used when not running on web (or as docs default).
  static const String defaultAppOrigin =
      'https://attendance-app-peach-rho.vercel.app';

  /// Override with `--dart-define=APP_ORIGIN=https://your.app`.
  static const String _envAppOrigin = String.fromEnvironment('APP_ORIGIN');

  /// App URL used as Supabase `redirectTo` for password reset emails.
  ///
  /// Includes `passwordReset=1` so PKCE callbacks (code-only URLs) still mark
  /// recovery. Must be allow-listed under Authentication → Redirect URLs
  /// (wildcard `https://your-app/**` or the exact URL).
  static String passwordResetRedirectUrl() {
    final base = _appBaseUrl();
    final uri = Uri.parse(base);
    return uri.replace(
      queryParameters: <String, String>{
        ...uri.queryParameters,
        'passwordReset': '1',
      },
    ).toString();
  }

  static String _appBaseUrl() {
    final env = _envAppOrigin.trim();
    if (env.isNotEmpty) {
      return _stripTrailingSlash(env);
    }
    if (kIsWeb) {
      final b = Uri.base;
      final path = b.path.isEmpty || b.path == '/'
          ? ''
          : _stripTrailingSlash(b.path);
      return '${b.origin}$path';
    }
    return defaultAppOrigin;
  }

  /// True when the current URL is a Supabase password-recovery callback.
  static bool isPasswordRecoveryUrl([Uri? uri]) {
    final u = uri ?? Uri.base;
    if (u.queryParameters['passwordReset'] == '1') return true;
    if (u.queryParameters['type'] == 'recovery') return true;

    final frag = u.fragment;
    if (frag.isEmpty) return false;
    if (frag.contains('type=recovery')) return true;

    // Hash can be `access_token=...&type=recovery`.
    final raw = frag.startsWith('/') ? frag.substring(1) : frag;
    try {
      final qp = Uri.splitQueryString(raw);
      if (qp['type'] == 'recovery') return true;
      if (qp['passwordReset'] == '1') return true;
    } catch (_) {}
    return false;
  }

  /// User-facing message if the auth email link failed (expired, etc.).
  static String? authLinkErrorMessage([Uri? uri]) {
    final u = uri ?? Uri.base;
    final q = u.queryParameters;
    final err = q['error_description'] ?? q['error_code'] ?? q['error'];
    if (err != null && err.trim().isNotEmpty) {
      return _friendlyLinkError(err);
    }

    final frag = u.fragment;
    if (frag.isEmpty) return null;
    final raw = frag.startsWith('/') ? frag.substring(1) : frag;
    try {
      final qp = Uri.splitQueryString(raw);
      final ferr = qp['error_description'] ?? qp['error_code'] ?? qp['error'];
      if (ferr != null && ferr.trim().isNotEmpty) {
        return _friendlyLinkError(ferr);
      }
    } catch (_) {}
    return null;
  }

  static String _friendlyLinkError(String raw) {
    final lower = Uri.decodeComponent(raw).toLowerCase();
    if (lower.contains('otp_expired') || lower.contains('expired')) {
      return 'This reset link has expired. Request a new one from Forgot password.';
    }
    if (lower.contains('access_denied')) {
      return 'Reset link was denied or already used. Request a new one.';
    }
    return 'Could not open the reset link. Request a new one from Forgot password.';
  }

  static String _stripTrailingSlash(String s) {
    if (s.length > 1 && s.endsWith('/')) {
      return s.substring(0, s.length - 1);
    }
    return s;
  }
}

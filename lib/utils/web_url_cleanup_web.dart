import 'package:web/web.dart' as web;

/// Clears expired Supabase auth callback query/hash so Flutter web does not
/// sit on `?error=otp_expired...` (blank / stuck look).
void clearAuthErrorQueryFromUrl() {
  final uri = Uri.base;
  final q = uri.queryParameters;
  final hasQueryError = q.containsKey('error') || q.containsKey('error_code');
  final hasHashError = uri.fragment.contains('error=');
  if (!hasQueryError && !hasHashError) return;

  final clean = uri.replace(queryParameters: <String, String>{}, fragment: '');
  web.window.history.replaceState(null, '', '${clean.origin}${clean.path}');
}

/// Removes auth tokens / query from the address bar after the session is loaded
/// so a refresh does not re-process the recovery link.
void clearAuthCallbackFromUrl() {
  final uri = Uri.base;
  final hasQueryAuth = uri.queryParameters.containsKey('code') ||
      uri.queryParameters.containsKey('access_token') ||
      uri.queryParameters.containsKey('type') ||
      uri.queryParameters.containsKey('passwordReset') ||
      uri.queryParameters.containsKey('error') ||
      uri.queryParameters.containsKey('error_code');
  final frag = uri.fragment;
  final hasHashAuth = frag.contains('access_token') ||
      frag.contains('refresh_token') ||
      frag.contains('type=') ||
      frag.contains('error=');
  if (!hasQueryAuth && !hasHashAuth) return;

  web.window.history.replaceState(null, '', '${uri.origin}${uri.path}');
}

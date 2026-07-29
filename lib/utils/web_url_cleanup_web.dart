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

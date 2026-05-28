final class AppConfig {
  AppConfig._();

  static const _defaultSupabaseUrl =
      'https://mpkctsbznxusoifqqipq.supabase.co';

  static const _defaultSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1wa2N0c2J6bnh1c29pZnFxaXBxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNjg4MzIsImV4cCI6MjA5MTY0NDgzMn0.7GtCPu80ez2JuEurq51ckBej12BqnL0pCxC38n2Y5qg';

  /// Placeholder anon key from Flutter template — treated as "not configured".
  static const _placeholderAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1wa2N0c2J6bnh1c29pZnFxaXBxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNjg4MzIsImV4cCI6MjA5MTY0NDgzMn0';

  static const _envSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _envSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Resolves compile-time env; empty `--dart-define` values fall back to defaults
  /// (Vercel/bash often passes empty strings when env vars are missing).
  static String get supabaseUrl =>
      _envSupabaseUrl.trim().isNotEmpty ? _envSupabaseUrl.trim() : _defaultSupabaseUrl;

  static String get supabaseAnonKey => _envSupabaseAnonKey.trim().isNotEmpty
      ? _envSupabaseAnonKey.trim()
      : _defaultSupabaseAnonKey;

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      supabaseAnonKey != _placeholderAnonKey;
}

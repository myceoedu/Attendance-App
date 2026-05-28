final class AppConfig {
  AppConfig._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mpkctsbznxusoifqqipq.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1wa2N0c2J6bnh1c29pZnFxaXBxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNjg4MzIsImV4cCI6MjA5MTY0NDgzMn0.7GtCPu80ez2JuEurq51ckBej12BqnL0pCxC38n2Y5qg',
  );

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      supabaseAnonKey !=
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJIUzI1NiIsInR5cCI6IkpXVCJ9';
}

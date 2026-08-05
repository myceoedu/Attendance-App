import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';
import 'constants/app_theme.dart';
import 'providers/auth_provider.dart';
import 'startup_timing.dart';
import 'screens/login_screen.dart';
import 'screens/employee/employee_shell.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/set_new_password_screen.dart';
import 'utils/auth_link_bootstrap.dart';
import 'utils/web_url_cleanup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  StartupTiming.mark('binding_ready');

  // Web: never pull Inter from fonts.gstatic.com (~400KB+ on cold load).
  if (kIsWeb) {
    GoogleFonts.config.allowRuntimeFetching = false;
  }

  // Capture recovery / error from the email link before cleaning the URL.
  AuthLinkBootstrap.captureFromCurrentUrl();
  // Drop expired email-link error params before first paint (web).
  clearAuthErrorQueryFromUrl();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  if (!AppConfig.hasSupabaseConfig) {
    runApp(const _ConfigErrorApp());
    return;
  }

  // First frame paints immediately; Supabase init no longer blocks the embedder.
  runApp(const _SupabaseBootstrapApp());
  StartupTiming.mark('run_app_scheduled');
}

/// Initializes Supabase after the first frame, then mounts the real app tree.
class _SupabaseBootstrapApp extends StatefulWidget {
  const _SupabaseBootstrapApp();

  @override
  State<_SupabaseBootstrapApp> createState() => _SupabaseBootstrapAppState();
}

class _SupabaseBootstrapAppState extends State<_SupabaseBootstrapApp> {
  bool _ready = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initSupabase();
  }

  Future<void> _initSupabase() async {
    try {
       await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
      StartupTiming.mark('supabase_ready');
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e, st) {
      debugPrint('Supabase.initialize failed: $e\n$st');
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppColors.surface,
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Could not start the app (backend init failed).\n\n'
                '$_error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: Scaffold(
          backgroundColor: AppColors.surface,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Starting…',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) {
        final auth = AuthProvider();
        scheduleMicrotask(() => unawaited(auth.init()));
        return auth;
      },
      child: const AttendanceApp(),
    );
  }
}

class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.settings_input_component_outlined, size: 44),
                SizedBox(height: 12),
                Text(
                  'Supabase configuration is missing.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  'Set SUPABASE_URL and SUPABASE_ANON_KEY with --dart-define, or keep the internal defaults for local use.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AttendanceApp extends StatefulWidget {
  const AttendanceApp({super.key});

  @override
  State<AttendanceApp> createState() => _AttendanceAppState();
}

class _AttendanceAppState extends State<AttendanceApp> {
  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        StartupTiming.mark('first_frame');
        StartupTiming.reportDeltas();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'myRekod',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, child) {
        if (!kIsWeb) return child ?? const SizedBox.shrink();
        return ColoredBox(
          color: AppColors.surface,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final loading = context.select<AuthProvider, bool>((a) => a.loading);

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Recovery session must not open the dashboard — set password first.
    final recovery =
        context.select<AuthProvider, bool>((a) => a.passwordRecoveryPending);
    if (recovery) return const SetNewPasswordScreen();

    final loggedIn = context.select<AuthProvider, bool>((a) => a.isLoggedIn);
    if (!loggedIn) return const LoginScreen();

    final isAdmin = context.select<AuthProvider, bool>((a) => a.isAdmin);
    return isAdmin ? const AdminShell() : const EmployeeShell();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../services/session_profile_cache.dart';
import '../services/supabase_service.dart';
import '../startup_timing.dart';
import '../utils/auth_link_bootstrap.dart';
import '../utils/auth_redirect.dart';
import '../utils/web_url_cleanup.dart';

class AuthProvider extends ChangeNotifier {
  /// `flutter run --dart-define=ATTENDANCE_SKIP_PROFILE_CACHE=true` forces a
  /// network profile fetch on every cold start (baseline for startup timing).
  static const bool _skipProfileCache = bool.fromEnvironment(
    'ATTENDANCE_SKIP_PROFILE_CACHE',
    defaultValue: false,
  );

  AppUser? _user;
  bool _loading = true;
  bool _passwordRecoveryPending = false;
  String? _loginBanner;
  bool _loginBannerIsError = false;
  bool _completingPasswordReset = false;
  StreamSubscription<AuthState>? _authSub;

  AppUser? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get passwordRecoveryPending => _passwordRecoveryPending;
  String? get loginBanner => _loginBanner;
  bool get loginBannerIsError => _loginBannerIsError;
  bool get completingPasswordReset => _completingPasswordReset;

  /// One-shot banner for LoginScreen (success or link error).
  String? takeLoginBanner() {
    final m = _loginBanner;
    if (m == null) return null;
    _loginBanner = null;
    return m;
  }

  void _enterPasswordRecovery() {
    if (_passwordRecoveryPending) return;
    _passwordRecoveryPending = true;
    // Drop any failed-link banner — recovery session is valid now.
    _loginBanner = null;
    _loginBannerIsError = false;
    clearAuthCallbackFromUrl();
    notifyListeners();
  }

  bool get _isRecoveryCallback =>
      AuthLinkBootstrap.recoveryHint || AuthRedirect.isPasswordRecoveryUrl();

  /// Waits for PKCE / recovery session after an email reset link.
  ///
  /// Supabase often finishes `?code=` exchange shortly *after* initialize;
  /// failing immediately was showing "Could not open the reset link" too early.
  Future<bool> _awaitRecoverySession({
    required Completer<void> gate,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (_passwordRecoveryPending || SupabaseService.currentAuthUser != null) {
      return true;
    }

    // Poll in case the session lands without another auth event.
    final poll = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (SupabaseService.currentAuthUser != null && !gate.isCompleted) {
        gate.complete();
      }
    });

    try {
      await gate.future.timeout(timeout);
      return _passwordRecoveryPending ||
          SupabaseService.currentAuthUser != null;
    } on TimeoutException {
      return _passwordRecoveryPending ||
          SupabaseService.currentAuthUser != null;
    } finally {
      poll.cancel();
    }
  }

  Future<void> init() async {
    if (kDebugMode) StartupTiming.mark('auth_init_start');

    _authSub?.cancel();
    _authSub = null;

    if (kDebugMode && _skipProfileCache) {
      debugPrint(
        '[Startup] ATTENDANCE_SKIP_PROFILE_CACHE=true — network profile path',
      );
    }

    // Hard failure from Supabase redirect (?error=otp_expired…).
    final bootError = AuthLinkBootstrap.linkError;
    if (bootError != null && bootError.isNotEmpty) {
      _loginBanner = bootError;
      _loginBannerIsError = true;
    }

    final recoveryAwaiting =
        AuthLinkBootstrap.recoveryHint && bootError == null;
    Completer<void>? recoveryGate;
    if (recoveryAwaiting) {
      recoveryGate = Completer<void>();
    }

    void signalRecoveryReady() {
      final g = recoveryGate;
      if (g != null && !g.isCompleted) g.complete();
    }

    // Listen before waiting so we don't miss passwordRecovery / signedIn.
    _authSub = SupabaseService.client.auth.onAuthStateChange.listen((
      event,
    ) async {
      switch (event.event) {
        case AuthChangeEvent.passwordRecovery:
          _enterPasswordRecovery();
          signalRecoveryReady();
          break;
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.userUpdated:
          if (_passwordRecoveryPending || _completingPasswordReset) {
            // Stay on set-password UI; ignore profile routing until done.
            return;
          }
          // Use bootstrap hint too — SDK may clear ?passwordReset=1 from the URL.
          if (_isRecoveryCallback) {
            _enterPasswordRecovery();
            signalRecoveryReady();
            return;
          }
          final fresh = await SupabaseService.getCurrentUserProfile();
          final previous = _user;
          _user = fresh;
          if (_user != null) {
            await SessionProfileCache.save(_user!);
          } else {
            await SessionProfileCache.clear();
          }
          if (!_sameVisibleProfile(previous, _user)) {
            notifyListeners();
          }
          break;
        case AuthChangeEvent.tokenRefreshed:
          if (_passwordRecoveryPending || _completingPasswordReset) return;
          // Token silently refreshed — user identity unchanged.
          // Only fetch profile (and notify) if we somehow have no user yet.
          if (_user != null) return;
          _user = await SupabaseService.getCurrentUserProfile();
          if (_user != null) await SessionProfileCache.save(_user!);
          notifyListeners();
          break;
        case AuthChangeEvent.signedOut:
          final hadUser = _user != null;
          final hadRecovery = _passwordRecoveryPending;
          _user = null;
          _passwordRecoveryPending = false;
          await SessionProfileCache.clear();
          if (hadUser || hadRecovery) notifyListeners();
          break;
        default:
          break;
      }
    });

    var sessionUser = SupabaseService.currentAuthUser;
    var usedCache = false;

    if (recoveryAwaiting) {
      if (sessionUser != null) {
        _enterPasswordRecovery();
        signalRecoveryReady();
      } else {
        final ok = await _awaitRecoverySession(gate: recoveryGate!);
        sessionUser = SupabaseService.currentAuthUser;
        if (ok) {
          if (!_passwordRecoveryPending) _enterPasswordRecovery();
        } else if (_loginBanner == null) {
          _loginBanner =
              'Could not open the reset link. Request a new one from Forgot password.';
          _loginBannerIsError = true;
        }
      }
    } else if (AuthLinkBootstrap.recoveryHint && sessionUser != null) {
      // Boot error present but a session somehow exists — prefer recovery UI.
      _enterPasswordRecovery();
    }

    if (sessionUser != null && !_passwordRecoveryPending) {
      AppUser? resolved;
      if (!_skipProfileCache) {
        resolved = await SessionProfileCache.loadIfMatches(sessionUser.id);
      }
      if (resolved != null) {
        _user = resolved;
        usedCache = true;
      } else {
        _user = await SupabaseService.getCurrentUserProfile();
        if (_user != null) {
          await SessionProfileCache.save(_user!);
        }
      }
    } else if (sessionUser != null && _passwordRecoveryPending) {
      // Do not open the shell; stay on set-password screen.
      _user = null;
      await SessionProfileCache.clear();
    } else {
      _user = null;
      await SessionProfileCache.clear();
    }

    _loading = false;
    notifyListeners();

    if (kDebugMode) {
      if (_passwordRecoveryPending) {
        StartupTiming.mark('auth_interactive_guest');
      } else if (usedCache) {
        StartupTiming.mark('auth_interactive_cached');
      } else if (sessionUser != null) {
        StartupTiming.mark('auth_interactive_network');
      } else {
        StartupTiming.mark('auth_interactive_guest');
      }
      StartupTiming.reportAuthPath(
        hadSession: sessionUser != null && !_passwordRecoveryPending,
        usedCache: usedCache,
        backgroundRefreshScheduled:
            sessionUser != null && usedCache && !_passwordRecoveryPending,
      );
    }

    if (sessionUser != null && usedCache && !_passwordRecoveryPending) {
      unawaited(_refreshCachedProfile(sessionUser.id));
    }
  }

  Future<void> _refreshCachedProfile(String sessionId) async {
    final fresh = await SupabaseService.getCurrentUserProfile();
    if (SupabaseService.currentAuthUser?.id != sessionId) return;
    if (fresh == null) {
      _user = null;
      await SessionProfileCache.clear();
      notifyListeners();
      if (kDebugMode) StartupTiming.mark('auth_profile_refresh_done');
      return;
    }
    final previous = _user;
    _user = fresh;
    await SessionProfileCache.save(fresh);
    if (!_sameVisibleProfile(previous, fresh)) {
      notifyListeners();
    }
    if (kDebugMode) StartupTiming.mark('auth_profile_refresh_done');
  }

  static bool _sameVisibleProfile(AppUser? a, AppUser? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.id == b.id &&
        a.role == b.role &&
        a.name == b.name &&
        a.email == b.email &&
        a.username == b.username &&
        a.phone == b.phone &&
        a.jobTitle == b.jobTitle &&
        a.department == b.department &&
        a.employeeCode == b.employeeCode;
  }

  /// [identifier] is **username** or **email** (if it contains `@`).
  Future<String?> signIn(String identifier, String password) async {
    try {
      await SupabaseService.signInWithIdentifier(identifier, password);
      _user = await SupabaseService.getCurrentUserProfile();
      if (_user == null) {
        await SupabaseService.signOut();
        return 'Signed in but your profile was not found. Contact HR or IT.';
      }
      await SessionProfileCache.save(_user!);
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      final msg = e.message.trim();
      if (msg.isEmpty) return 'Invalid username or password';
      final lower = msg.toLowerCase();
      if (lower.contains('email not confirmed') ||
          lower.contains('not confirmed')) {
        return 'Confirm your email first (check inbox), then try again.';
      }
      return msg;
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('socketexception') ||
          s.contains('failed host lookup') ||
          s.contains('network is unreachable') ||
          s.contains('failed to fetch') ||
          s.contains('connection refused')) {
        return 'No internet connection. Check Wi‑Fi or data and try again.';
      }
      if (s.contains('invalid username or password')) {
        return 'Invalid username or password';
      }
      return 'Invalid username or password';
    }
  }

  /// Returns `null` on success, or an error / info message string.
  Future<String?> signUp({
    required String email,
    required String username,
    required String password,
  }) async {
    final norm = SupabaseService.normalizeUsername(username);
    if (norm.length < 3) {
      return 'Username must be at least 3 characters';
    }
    try {
      final available = await SupabaseService.isUsernameAvailable(norm);
      if (!available) {
        return 'Username is already taken';
      }
      final res = await SupabaseService.registerAccount(
        email: email,
        password: password,
        normalizedUsername: norm,
        displayName: norm,
      );
      if (res.session != null) {
        _user = await SupabaseService.getCurrentUserProfile();
        if (_user != null) await SessionProfileCache.save(_user!);
        notifyListeners();
        return null;
      }
      return 'Account created. Confirm your email if required, then sign in.';
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('User already registered')) {
        return 'An account with this email already exists';
      }
      if (msg.contains('username required')) {
        return 'Registration failed. Update the app or database trigger.';
      }
      if (msg.contains('429') || msg.toLowerCase().contains('too many')) {
        return 'Too many sign-up attempts. Wait a few minutes, then try once.';
      }
      return 'Sign up failed. Check your details and try again.';
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      return 'Enter a valid email address';
    }
    try {
      await SupabaseService.sendPasswordResetEmail(
        trimmed,
        redirectTo: AuthRedirect.passwordResetRedirectUrl(),
      );
      return null;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('429') || msg.contains('too many')) {
        return 'Too many reset attempts. Wait a few minutes, then try once.';
      }
      return 'Could not send reset email. Try again.';
    }
  }

  /// Completes email-link recovery: set password, end session, show login.
  Future<String?> completePasswordRecovery(String newPassword) async {
    if (!_passwordRecoveryPending) {
      return 'Reset session expired. Request a new reset email.';
    }
    if (newPassword.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (SupabaseService.currentAuthUser == null) {
      _passwordRecoveryPending = false;
      notifyListeners();
      return 'Reset session expired. Request a new reset email.';
    }

    _completingPasswordReset = true;
    try {
      await SupabaseService.updatePassword(newPassword);
      await SessionProfileCache.clear();
      _user = null;
      _passwordRecoveryPending = false;
      _loginBanner = 'Password updated. Sign in with your new password.';
      _loginBannerIsError = false;
      try {
        await SupabaseService.signOut();
      } catch (_) {
        // Local clear is enough to return to login.
      }
      clearAuthCallbackFromUrl();
      notifyListeners();
      return null;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('same_password') || msg.contains('same password')) {
        return 'Choose a password different from your current one.';
      }
      if (msg.contains('session') || msg.contains('jwt') || msg.contains('401')) {
        _passwordRecoveryPending = false;
        notifyListeners();
        return 'Reset session expired. Request a new reset email.';
      }
      return 'Could not update password. Try again.';
    } finally {
      _completingPasswordReset = false;
    }
  }

  /// Leaves recovery without changing the password.
  Future<void> cancelPasswordRecovery() async {
    if (!_passwordRecoveryPending && SupabaseService.currentAuthUser == null) {
      return;
    }
    _completingPasswordReset = true;
    try {
      _passwordRecoveryPending = false;
      _user = null;
      await SessionProfileCache.clear();
      try {
        await SupabaseService.signOut();
      } catch (_) {}
      clearAuthCallbackFromUrl();
      notifyListeners();
    } finally {
      _completingPasswordReset = false;
    }
  }

  Future<String?> updateProfile({required String name, String? phone}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Name cannot be empty';
    try {
      _user = await SupabaseService.updateCurrentUserProfile(
        name: trimmed,
        phone: phone,
      );
      if (_user != null) await SessionProfileCache.save(_user!);
      notifyListeners();
      return null;
    } catch (_) {
      return 'Could not update profile';
    }
  }

  Future<String?> updateEmployeeProfileFull({
    required String name,
    required String phone,
    required String address,
    required String maritalStatus,
    required DateTime? dateOfBirth,
    required String icNumber,
    required String jobTitle,
    required String department,
    required String employeeCode,
    required String epfNumber,
    required String socsoNumber,
    required String bankName,
    required String bankAccountNumber,
    required String educationLevel,
    required String educationInstitution,
    required String emergencyContactName,
    required String emergencyContactRelationship,
    required String emergencyContactPhone,
    required DateTime employmentStartDate,
  }) async {
    try {
      _user = await SupabaseService.updateEmployeeSelfServiceProfile(
        name: name,
        phone: phone,
        address: address,
        maritalStatus: maritalStatus,
        dateOfBirth: dateOfBirth,
        icNumber: icNumber,
        jobTitle: jobTitle,
        department: department,
        employeeCode: employeeCode,
        epfNumber: epfNumber,
        socsoNumber: socsoNumber,
        bankName: bankName,
        bankAccountNumber: bankAccountNumber,
        educationLevel: educationLevel,
        educationInstitution: educationInstitution,
        emergencyContactName: emergencyContactName,
        emergencyContactRelationship: emergencyContactRelationship,
        emergencyContactPhone: emergencyContactPhone,
        employmentStartDate: employmentStartDate,
      );
      if (_user != null) await SessionProfileCache.save(_user!);
      notifyListeners();
      return null;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('users_employee_code_unique')) {
        return 'Employee ID is already used. Choose another.';
      }
      return 'Could not save profile. Check your connection.';
    }
  }

  Future<void> refreshProfile() async {
    if (SupabaseService.currentUserId == null) return;
    final fresh = await SupabaseService.getCurrentUserProfile();
    _user = fresh;
    if (_user != null) await SessionProfileCache.save(_user!);
    notifyListeners();
  }

  // Keep old name as alias so nothing else breaks.
  Future<String?> updateProfileName(String name) => updateProfile(name: name);

  Future<String?> changePassword(String newPassword) async {
    if (newPassword.length < 6) return 'Password must be at least 6 characters';
    if (_passwordRecoveryPending) {
      return completePasswordRecovery(newPassword);
    }
    try {
      await SupabaseService.updatePassword(newPassword);
      return null;
    } catch (_) {
      return 'Could not change password';
    }
  }

  Future<void> signOut() async {
    await SessionProfileCache.clear();
    await SupabaseService.signOut();
    _user = null;
    _passwordRecoveryPending = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

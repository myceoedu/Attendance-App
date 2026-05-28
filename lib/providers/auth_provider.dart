import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../services/session_profile_cache.dart';
import '../services/supabase_service.dart';
import '../startup_timing.dart';

class AuthProvider extends ChangeNotifier {
  /// `flutter run --dart-define=ATTENDANCE_SKIP_PROFILE_CACHE=true` forces a
  /// network profile fetch on every cold start (baseline for startup timing).
  static const bool _skipProfileCache = bool.fromEnvironment(
    'ATTENDANCE_SKIP_PROFILE_CACHE',
    defaultValue: false,
  );

  AppUser? _user;
  bool _loading = true;
  StreamSubscription<AuthState>? _authSub;

  AppUser? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;

  Future<void> init() async {
    if (kDebugMode) StartupTiming.mark('auth_init_start');

    _authSub?.cancel();
    _authSub = null;

    if (kDebugMode && _skipProfileCache) {
      debugPrint(
        '[Startup] ATTENDANCE_SKIP_PROFILE_CACHE=true — network profile path',
      );
    }

    final session = SupabaseService.currentAuthUser;
    var usedCache = false;

    if (session != null) {
      AppUser? resolved;
      if (!_skipProfileCache) {
        resolved = await SessionProfileCache.loadIfMatches(session.id);
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
    } else {
      _user = null;
      await SessionProfileCache.clear();
    }

    _loading = false;
    notifyListeners();

    if (kDebugMode) {
      if (usedCache) {
        StartupTiming.mark('auth_interactive_cached');
      } else if (session != null) {
        StartupTiming.mark('auth_interactive_network');
      } else {
        StartupTiming.mark('auth_interactive_guest');
      }
      StartupTiming.reportAuthPath(
        hadSession: session != null,
        usedCache: usedCache,
        backgroundRefreshScheduled: session != null && usedCache,
      );
    }

    _authSub = SupabaseService.client.auth.onAuthStateChange.listen((event) async {
      switch (event.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.userUpdated:
        case AuthChangeEvent.passwordRecovery:
          _user = await SupabaseService.getCurrentUserProfile();
          if (_user != null) {
            await SessionProfileCache.save(_user!);
          } else {
            await SessionProfileCache.clear();
          }
          break;
        case AuthChangeEvent.tokenRefreshed:
          if (_user == null) {
            _user = await SupabaseService.getCurrentUserProfile();
            if (_user != null) await SessionProfileCache.save(_user!);
          }
          break;
        case AuthChangeEvent.signedOut:
          _user = null;
          await SessionProfileCache.clear();
          break;
        default:
          break;
      }
      notifyListeners();
    });

    if (session != null && usedCache) {
      unawaited(_refreshCachedProfile(session.id));
    }
  }

  Future<void> _refreshCachedProfile(String sessionId) async {
    final fresh = await SupabaseService.getCurrentUserProfile();
    if (SupabaseService.currentAuthUser?.id != sessionId) return;
    if (fresh == null) {
      _user = null;
      await SessionProfileCache.clear();
    } else {
      _user = fresh;
      await SessionProfileCache.save(fresh);
    }
    notifyListeners();
    if (kDebugMode) StartupTiming.mark('auth_profile_refresh_done');
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
        displayName: username.trim(),
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
      return 'Sign up failed. Check your details and try again.';
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      return 'Enter a valid email address';
    }
    try {
      await SupabaseService.sendPasswordResetEmail(trimmed);
      return null;
    } catch (_) {
      return 'Could not send reset email. Try again.';
    }
  }

  Future<String?> updateProfile({
    required String name,
    String? phone,
  }) async {
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
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

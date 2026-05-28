import 'dart:async';
import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/attendance.dart';
import '../models/employee_calendar_day.dart';
import '../models/leave_request.dart';
import '../models/leave_audit_log.dart';
import '../models/annual_leave_summary.dart';
import '../models/expense_claim.dart';
import '../models/claim_attachment.dart';
import '../models/company_announcement.dart';
import '../models/monthly_attendance_summary.dart';
import '../models/payroll_history_entry.dart';
import '../models/payroll_item.dart';
import '../models/payroll_run.dart';
import '../models/payroll_salary_setting.dart';
import '../models/payroll_statutory_config.dart';
import '../utils/app_time.dart';
import 'payroll_engine.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  // ──────────────────────────────────────────────
  // AUTH
  // ──────────────────────────────────────────────

  static Future<AuthResponse> signIn(String email, String password) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  /// Normalizes username for storage / lookup (lowercase, trimmed).
  static String normalizeUsername(String raw) => raw.trim().toLowerCase();

  /// Login with **email** (if [identifier] contains `@`) or **username** (RPC → email).
  static Future<AuthResponse> signInWithIdentifier(
    String identifier,
    String password,
  ) async {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) {
      throw Exception('Enter your username or email');
    }
    final email = trimmed.contains('@')
        ? trimmed
        : await getEmailForLogin(trimmed);
    if (email == null || email.isEmpty) {
      throw Exception('Invalid username or password');
    }
    return client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<String?> getEmailForLogin(String username) async {
    final res = await client.rpc(
      'get_email_for_login',
      params: {'p_username': username},
    );
    if (res == null) return null;
    return res as String?;
  }

  static Future<bool> isUsernameAvailable(String username) async {
    final res = await client.rpc(
      'is_username_available',
      params: {'p_username': username},
    );
    if (res is bool) return res;
    return false;
  }

  static Future<AuthResponse> registerAccount({
    required String email,
    required String password,
    required String normalizedUsername,
    String? displayName,
  }) {
    final name = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : normalizedUsername;
    return client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'username': normalizedUsername, 'name': name},
    );
  }

  static Future<void> signOut() => client.auth.signOut();

  static Future<void> sendPasswordResetEmail(String email) {
    return client.auth.resetPasswordForEmail(email.trim());
  }

  static Future<void> updatePassword(String newPassword) {
    return client.auth.updateUser(UserAttributes(password: newPassword));
  }

  static User? get currentAuthUser => client.auth.currentUser;
  static String? get currentUserId => currentAuthUser?.id;

  static const _appUserSelect =
      'id,username,name,email,role,phone,created_at,employment_start_date,'
      'annual_leave_entitlement_override,address,marital_status,date_of_birth,'
      'ic_number,job_title,department,employee_code,epf_number,socso_number,'
      'bank_name,bank_account_number,education_level,education_institution,'
      'emergency_contact_name,emergency_contact_relationship,'
      'emergency_contact_phone';

  static const _employeeCacheTtl = Duration(seconds: 45);
  static List<AppUser>? _employeesCache;
  static DateTime? _employeesCacheAt;

  static void _invalidateEmployeesCache() {
    _employeesCache = null;
    _employeesCacheAt = null;
  }

  // ──────────────────────────────────────────────
  // USER PROFILE
  // ──────────────────────────────────────────────

  static Future<AppUser?> getCurrentUserProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;

    final data = await client
        .from('users')
        .select(_appUserSelect)
        .eq('id', uid)
        .maybeSingle();
    if (data == null) return null;
    return AppUser.fromMap(data);
  }

  static Future<List<AppUser>> getAllEmployees({
    bool forceRefresh = false,
  }) async {
    final cached = _employeesCache;
    final cachedAt = _employeesCacheAt;
    if (!forceRefresh && cached != null && cachedAt != null) {
      final fresh = DateTime.now().difference(cachedAt) < _employeeCacheTtl;
      if (fresh) return List<AppUser>.unmodifiable(cached);
    }

    final data = await client
        .from('users')
        .select(_appUserSelect)
        .eq('role', 'employee')
        .order('name');
    final employees = data.map<AppUser>((e) => AppUser.fromMap(e)).toList();
    _employeesCache = employees;
    _employeesCacheAt = DateTime.now();
    return List<AppUser>.unmodifiable(employees);
  }

  static Future<List<AppUser>> getAllUsers() async {
    final data = await client
        .from('users')
        .select(_appUserSelect)
        .order('name');
    return data.map<AppUser>((e) => AppUser.fromMap(e)).toList();
  }

  static Future<AppUser?> getUserById(String userId) async {
    final data = await client
        .from('users')
        .select(_appUserSelect)
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return AppUser.fromMap(data);
  }

  static Future<AppUser> updateCurrentUserProfile({
    required String name,
    String? phone,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not signed in');

    await client.auth.updateUser(UserAttributes(data: {'name': name.trim()}));

    final updates = <String, dynamic>{'name': name.trim()};
    // Allow clearing phone by passing empty string.
    if (phone != null) {
      updates['phone'] = phone.trim().isEmpty ? null : phone.trim();
    }

    final data = await client
        .from('users')
        .update(updates)
        .eq('id', uid)
        .select(_appUserSelect)
        .single();
    _invalidateEmployeesCache();
    return AppUser.fromMap(data);
  }

  /// Full employee self-service profile (editable columns on `users`).
  static Future<AppUser> updateEmployeeSelfServiceProfile({
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
    final uid = currentUserId;
    if (uid == null) throw Exception('Not signed in');

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw Exception('Name is required');

    await client.auth.updateUser(UserAttributes(data: {'name': trimmedName}));

    String? nil(String v) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    final updates = <String, dynamic>{
      'name': trimmedName,
      'phone': nil(phone),
      'address': nil(address),
      'marital_status': nil(maritalStatus),
      'date_of_birth': dateOfBirth == null ? null : _dateString(dateOfBirth),
      'ic_number': nil(icNumber),
      'job_title': nil(jobTitle),
      'department': nil(department),
      'employee_code': nil(employeeCode),
      'epf_number': nil(epfNumber),
      'socso_number': nil(socsoNumber),
      'bank_name': nil(bankName),
      'bank_account_number': nil(bankAccountNumber),
      'education_level': nil(educationLevel),
      'education_institution': nil(educationInstitution),
      'emergency_contact_name': nil(emergencyContactName),
      'emergency_contact_relationship': nil(emergencyContactRelationship),
      'emergency_contact_phone': nil(emergencyContactPhone),
      'employment_start_date': _dateString(employmentStartDate),
    };

    final data = await client
        .from('users')
        .update(updates)
        .eq('id', uid)
        .select(_appUserSelect)
        .single();
    _invalidateEmployeesCache();
    return AppUser.fromMap(data);
  }

  /// Admin updates another user’s `users` row (no Auth email change).
  /// Requires RLS policy allowing admins to update any profile.
  static Future<AppUser> updateEmployeeAsAdmin({
    required String userId,
    required String name,
    required String role,
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
    required DateTime? employmentStartDate,
    double? entitlementOverride,
    bool clearEntitlementOverride = false,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw Exception('Name is required');
    if (role != 'admin' && role != 'employee') {
      throw Exception('Invalid role');
    }

    String? nil(String v) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    final updates = <String, dynamic>{
      'name': trimmedName,
      'role': role,
      'phone': nil(phone),
      'address': nil(address),
      'marital_status': nil(maritalStatus),
      'date_of_birth': dateOfBirth == null ? null : _dateString(dateOfBirth),
      'ic_number': nil(icNumber),
      'job_title': nil(jobTitle),
      'department': nil(department),
      'employee_code': nil(employeeCode),
      'epf_number': nil(epfNumber),
      'socso_number': nil(socsoNumber),
      'bank_name': nil(bankName),
      'bank_account_number': nil(bankAccountNumber),
      'education_level': nil(educationLevel),
      'education_institution': nil(educationInstitution),
      'emergency_contact_name': nil(emergencyContactName),
      'emergency_contact_relationship': nil(emergencyContactRelationship),
      'emergency_contact_phone': nil(emergencyContactPhone),
      'employment_start_date': employmentStartDate == null
          ? null
          : _dateString(employmentStartDate),
    };

    if (clearEntitlementOverride) {
      updates['annual_leave_entitlement_override'] = null;
    } else if (entitlementOverride != null) {
      updates['annual_leave_entitlement_override'] = entitlementOverride;
    }

    final data = await client
        .from('users')
        .update(updates)
        .eq('id', userId)
        .select(_appUserSelect)
        .single();
    _invalidateEmployeesCache();
    return AppUser.fromMap(data);
  }

  /// HR fields; requires admin ([users_protect_hr_fields] trigger).
  ///
  /// [clearEntitlementOverride] true clears [annual_leave_entitlement_override]
  /// so tiered entitlement applies. Otherwise [entitlementOverride] sets manual days.
  static Future<AppUser> updateEmployeeAnnualLeaveConfig({
    required String userId,
    DateTime? employmentStart,
    double? entitlementOverride,
    bool clearEntitlementOverride = false,
  }) async {
    final updates = <String, dynamic>{};
    if (employmentStart != null) {
      updates['employment_start_date'] = _dateString(employmentStart);
    }
    if (clearEntitlementOverride) {
      updates['annual_leave_entitlement_override'] = null;
    } else if (entitlementOverride != null) {
      updates['annual_leave_entitlement_override'] = entitlementOverride;
    }
    if (updates.isEmpty) {
      final row = await client
          .from('users')
          .select(_appUserSelect)
          .eq('id', userId)
          .single();
      return AppUser.fromMap(row);
    }
    final data = await client
        .from('users')
        .update(updates)
        .eq('id', userId)
        .select(_appUserSelect)
        .single();
    _invalidateEmployeesCache();
    return AppUser.fromMap(data);
  }

  static AnnualLeaveSummary? _parseAnnualLeaveSummaryRpc(dynamic res) {
    if (res is Map<String, dynamic>) {
      return AnnualLeaveSummary.fromRpc(res);
    }
    if (res is List && res.isNotEmpty && res.first is Map<String, dynamic>) {
      return AnnualLeaveSummary.fromRpc(res.first as Map<String, dynamic>);
    }
    return null;
  }

  /// Leave year entitlement vs usage (calendar [year], default Malaysia calendar year).
  static Future<AnnualLeaveSummary?> getAnnualLeaveSummary(
    String userId, {
    int? year,
  }) async {
    final y = year ?? AppTime.malaysiaNow().year;
    final res = await client.rpc(
      'get_annual_leave_summary',
      params: {'p_user_id': userId, 'p_year': y},
    );
    return _parseAnnualLeaveSummaryRpc(res);
  }

  /// Admin-only batch summaries for roster chips.
  static Future<Map<String, AnnualLeaveSummary>> getAnnualLeaveSummariesBatch(
    List<String> userIds,
    int year,
  ) async {
    if (userIds.isEmpty) return {};
    final res = await client.rpc(
      'get_annual_leave_summaries_batch',
      params: {'p_user_ids': userIds.toList(), 'p_year': year},
    );
    final out = <String, AnnualLeaveSummary>{};
    if (res is List) {
      for (final row in res) {
        if (row is Map<String, dynamic>) {
          final uid = row['user_id'] as String?;
          if (uid != null && uid.isNotEmpty) {
            out[uid] = AnnualLeaveSummary.fromRpc(row);
          }
        }
      }
    }
    return out;
  }

  /// Overlap days between [start]–[end] and calendar [year], matching SQL
  /// [annual_leave_overlap_days].
  static int annualDaysInLeaveYear(DateTime start, DateTime end, int year) {
    final yearStart = DateTime(year, 1, 1);
    final yearEnd = DateTime(year, 12, 31);
    final dStart = DateTime(start.year, start.month, start.day);
    final dEnd = DateTime(end.year, end.month, end.day);
    final effStart = dStart.isBefore(yearStart) ? yearStart : dStart;
    final effEnd = dEnd.isAfter(yearEnd) ? yearEnd : dEnd;
    if (effEnd.isBefore(effStart)) return 0;
    return effEnd.difference(effStart).inDays + 1;
  }

  // ──────────────────────────────────────────────
  // ATTENDANCE
  // ──────────────────────────────────────────────

  /// Narrow select for punch + today row (no joined `users`).
  static const _attendanceRowSelect =
      'id,user_id,clock_in_time,clock_out_time,date,status,location';
  static const _attendanceWithUserSelect =
      'id,user_id,clock_in_time,clock_out_time,date,status,location,users(name)';

  static bool _isTransientPunchError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('clientexception') ||
        s.contains('connection reset') ||
        s.contains('connection refused') ||
        s.contains('connection aborted') ||
        s.contains('failed host lookup') ||
        s.contains('network is unreachable') ||
        s.contains('handshakeexception') ||
        s.contains('timed out') ||
        s.contains('timeoutexception') ||
        s.contains('server busy') ||
        s.contains('503') ||
        s.contains('502') ||
        s.contains('504');
  }

  static bool _isUniqueAttendanceViolation(PostgrestException e) {
    final c = e.code;
    if (c == '23505') return true;
    final m = e.message.toLowerCase();
    return m.contains('unique') && m.contains('violat');
  }

  static Future<T> _withTransientRetry<T>(Future<T> Function() action) async {
    const delays = <Duration>[
      Duration(milliseconds: 320),
      Duration(milliseconds: 700),
      Duration(milliseconds: 1300),
      Duration(milliseconds: 2200),
    ];
    Object? lastError;
    for (var attempt = 0; attempt < delays.length; attempt++) {
      try {
        return await action();
      } catch (e) {
        lastError = e;
        if (!_isTransientPunchError(e) || attempt == delays.length - 1) {
          rethrow;
        }
        await Future<void>.delayed(delays[attempt]);
      }
    }
    throw lastError!;
  }

  static Future<Attendance?> getTodayAttendance(String userId) async {
    final today = _todayString();
    final data = await client
        .from('attendance')
        .select(_attendanceRowSelect)
        .eq('user_id', userId)
        .eq('date', today)
        .maybeSingle();
    if (data == null) return null;
    return Attendance.fromMap(data);
  }

  static Future<LeaveRequest?> getApprovedLeaveForDate(
    String userId,
    DateTime date,
  ) async {
    final dateStr = _dateString(date);
    final data = await client
        .from('leave_requests')
        .select(_leaveListSelect)
        .eq('user_id', userId)
        .eq('status', 'approved')
        .lte('start_date', dateStr)
        .gte('end_date', dateStr)
        .not('leave_type', 'in', '("annual_half_am","annual_half_pm")')
        .order('start_date')
        .limit(1);
    if (data.isEmpty) return null;
    return LeaveRequest.fromMap(data.first);
  }

  static Future<bool> hasApprovedLeaveForDate(
    String userId,
    DateTime date,
  ) async {
    final leave = await getApprovedLeaveForDate(userId, date);
    return leave != null;
  }

  static Future<Attendance> _clockInOnce(
    String userId, {
    String? location,
  }) async {
    // Try the server-side RPC first (enforces approved-leave check atomically).
    // If the function hasn't been deployed yet, fall back to a client-side check.
    try {
      final data = await client.rpc(
        'clock_in_if_allowed',
        params: {'p_user_id': userId, 'p_location': location},
      );
      if (data is Map<String, dynamic>) {
        return Attendance.fromMap(data);
      }
      if (data is Map) {
        return Attendance.fromMap(Map<String, dynamic>.from(data));
      }
      throw Exception('Unexpected clock_in_if_allowed response shape');
    } on PostgrestException catch (e) {
      // PGRST202 = function not found in schema cache (SQL not deployed yet).
      if (e.code != 'PGRST202') rethrow;
    }

    // Fallback: check approved leave client-side, then insert directly.
    final today = AppTime.malaysiaNow();
    final hasLeave = await hasApprovedLeaveForDate(userId, today);
    if (hasLeave) {
      throw Exception('Approved leave already covers today');
    }
    final now = DateTime.now().toUtc();
    final todayStr = _todayString();
    try {
      final data = await client
          .from('attendance')
          .insert({
            'user_id': userId,
            'clock_in_time': now.toIso8601String(),
            'date': todayStr,
            'status': 'in_progress',
            'location': location,
          })
          .select(_attendanceRowSelect)
          .single();
      return Attendance.fromMap(data);
    } on PostgrestException catch (e) {
      if (_isUniqueAttendanceViolation(e)) {
        final existing = await getTodayAttendance(userId);
        if (existing != null) return existing;
      }
      rethrow;
    }
  }

  /// Clock-in with transient network retries and duplicate-day reconciliation.
  static Future<Attendance> clockIn(String userId, {String? location}) async {
    return _withTransientRetry(() async {
      try {
        return await _clockInOnce(userId, location: location);
      } on PostgrestException catch (e) {
        if (_isUniqueAttendanceViolation(e)) {
          final existing = await getTodayAttendance(userId);
          if (existing != null) return existing;
        }
        rethrow;
      }
    });
  }

  static Future<Attendance> _clockOutOnce(String attendanceId) async {
    final now = DateTime.now().toUtc();
    final data = await client
        .from('attendance')
        .update({
          'clock_out_time': now.toIso8601String(),
          'status': 'completed',
        })
        .eq('id', attendanceId)
        .select(_attendanceRowSelect)
        .single();
    return Attendance.fromMap(data);
  }

  static Future<Attendance> clockOut(String attendanceId) async {
    return _withTransientRetry(() => _clockOutOnce(attendanceId));
  }

  static Future<List<Attendance>> getAttendanceHistory(String userId) async {
    final data = await client
        .from('attendance')
        .select(_attendanceRowSelect)
        .eq('user_id', userId)
        .order('date', ascending: false)
        .limit(60);
    return data.map<Attendance>((e) => Attendance.fromMap(e)).toList();
  }

  /// Filterable log for the signed-in employee. [fromDate] / [toDate] are
  /// calendar dates (stored `date` column). Uses [offset] + [limit] for
  /// keyset-friendly pagination (order: `date` desc, `id` desc).
  /// [statusEquals] when set filters server-side (`all` ignored).
  static Future<List<Attendance>> getMyAttendanceLog(
    String userId, {
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 50,
    int offset = 0,
    String? statusEquals,
  }) async {
    var query = client
        .from('attendance')
        .select(_attendanceRowSelect)
        .eq('user_id', userId);
    if (fromDate != null) {
      query = query.gte('date', _dateString(fromDate));
    }
    if (toDate != null) {
      query = query.lte('date', _dateString(toDate));
    }
    if (statusEquals != null &&
        statusEquals.isNotEmpty &&
        statusEquals != 'all') {
      query = query.eq('status', statusEquals);
    }
    final start = offset;
    final end = offset + limit - 1;
    final data = await query
        .order('date', ascending: false)
        .order('id', ascending: false)
        .range(start, end);
    return data.map<Attendance>((e) => Attendance.fromMap(e)).toList();
  }

  static Future<List<Attendance>> getTodayAllAttendance() async {
    final today = _todayString();
    final data = await client
        .from('attendance')
        .select(_attendanceWithUserSelect)
        .eq('date', today)
        .order('clock_in_time');
    return data.map<Attendance>((e) => Attendance.fromMap(e)).toList();
  }

  static Future<List<Attendance>> getAttendanceByMonth(DateTime month) async {
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1);
    final data = await client
        .from('attendance')
        .select(_attendanceWithUserSelect)
        .gte('date', _dateString(monthStart))
        .lt('date', _dateString(monthEnd))
        .order('date', ascending: false)
        .order('clock_in_time');
    return data.map<Attendance>((e) => Attendance.fromMap(e)).toList();
  }

  static Future<List<Attendance>> _getAttendanceRowsByMonth(
    DateTime month,
  ) async {
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1);
    final data = await client
        .from('attendance')
        .select(_attendanceRowSelect)
        .gte('date', _dateString(monthStart))
        .lt('date', _dateString(monthEnd))
        .order('date', ascending: false)
        .order('clock_in_time');
    return data.map<Attendance>((e) => Attendance.fromMap(e)).toList();
  }

  static Future<List<Attendance>> getEmployeeAttendanceByMonth(
    String userId,
    DateTime month,
  ) async {
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1);
    final data = await client
        .from('attendance')
        .select(_attendanceRowSelect)
        .eq('user_id', userId)
        .gte('date', _dateString(monthStart))
        .lt('date', _dateString(monthEnd))
        .order('date')
        .order('id');
    return data.map<Attendance>((e) => Attendance.fromMap(e)).toList();
  }

  // ──────────────────────────────────────────────
  // LEAVE REQUESTS
  // ──────────────────────────────────────────────

  /// List projection without `users` join (employee self lists).
  static const _leaveListSelect =
      'id,user_id,leave_type,start_date,end_date,reason,status,admin_comment,attachment_path,created_at';
  static const _leaveWithUserSelect =
      'id,user_id,leave_type,start_date,end_date,reason,status,admin_comment,'
      'attachment_path,created_at,users(name)';

  static const _leaveAttachmentsBucket = 'leave-attachments';
  static const _maxAttachmentBytes = 5 * 1024 * 1024; // 5 MB
  static const _allowedAttachmentExt = {
    '.pdf',
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  };

  /// Uploads MC / supporting document. Path format: `{userId}/{timestamp}_{filename}`.
  static Future<String> uploadLeaveAttachment({
    required String userId,
    required PlatformFile file,
  }) async {
    final name = file.name.trim();
    if (name.isEmpty) throw Exception('Invalid file name');

    final ext = _fileExtensionLower(name);
    if (ext == null || !_allowedAttachmentExt.contains(ext)) {
      throw Exception('Use PDF, JPG, PNG, or WebP only');
    }

    final safe = _sanitizeFileName(name);
    final objectPath = '$userId/${DateTime.now().millisecondsSinceEpoch}_$safe';

    if (file.bytes != null) {
      if (file.bytes!.length > _maxAttachmentBytes) {
        throw Exception('File too large (max 5 MB)');
      }
      await client.storage
          .from(_leaveAttachmentsBucket)
          .uploadBinary(
            objectPath,
            file.bytes!,
            fileOptions: const FileOptions(upsert: false),
          );
    } else if (file.path != null) {
      final f = File(file.path!);
      final len = await f.length();
      if (len > _maxAttachmentBytes) {
        throw Exception('File too large (max 5 MB)');
      }
      await client.storage
          .from(_leaveAttachmentsBucket)
          .upload(objectPath, f, fileOptions: const FileOptions(upsert: false));
    } else {
      throw Exception('Could not read the file. Pick again.');
    }

    return objectPath;
  }

  /// Temporary signed URL so the user or admin can open the attachment in a browser.
  static Future<String> getLeaveAttachmentSignedUrl(
    String storagePath, {
    int expiresInSeconds = 3600,
  }) {
    return client.storage
        .from(_leaveAttachmentsBucket)
        .createSignedUrl(storagePath, expiresInSeconds);
  }

  static String? _fileExtensionLower(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return null;
    return name.substring(i).toLowerCase();
  }

  static String _sanitizeFileName(String name) {
    final base = name.replaceAll('\\', '/').split('/').last;
    return base.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  static Future<LeaveRequest> applyLeave({
    required String userId,
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    String? attachmentPath,
  }) async {
    final data = await client
        .from('leave_requests')
        .insert({
          'user_id': userId,
          'leave_type': leaveType,
          'start_date': _dateString(startDate),
          'end_date': _dateString(endDate),
          'reason': reason,
          'status': 'pending',
          if (attachmentPath != null && attachmentPath.isNotEmpty)
            'attachment_path': attachmentPath,
        })
        .select(_leaveListSelect)
        .single();
    return LeaveRequest.fromMap(data);
  }

  static Future<List<LeaveRequest>> getMyLeaveRequests(
    String userId, {
    int limit = 400,
  }) async {
    final data = await client
        .from('leave_requests')
        .select(_leaveListSelect)
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return data.map<LeaveRequest>((e) => LeaveRequest.fromMap(e)).toList();
  }

  /// Returns the first approved leave covering [today] for [userId], or null.
  /// Far lighter than [getMyLeaveRequests] — sends only a 1-row date-filtered
  /// query instead of up to 400 rows.
  static Future<LeaveRequest?> getApprovedLeaveForToday(
    String userId,
    DateTime today,
  ) async {
    final dateStr = _dateString(today);
    final data = await client
        .from('leave_requests')
        .select(_leaveListSelect)
        .eq('user_id', userId)
        .eq('status', 'approved')
        .lte('start_date', dateStr)
        .gte('end_date', dateStr)
        .limit(1);
    if (data.isEmpty) return null;
    return LeaveRequest.fromMap(data.first);
  }

  /// Count of pending leave requests for [userId].
  static Future<int> getPendingLeaveCountForUser(String userId) async {
    final res = await client
        .from('leave_requests')
        .select()
        .eq('user_id', userId)
        .eq('status', 'pending')
        .count(CountOption.exact);
    return res.count;
  }

  /// Paginated leave history with optional type + status filters.
  static Future<List<LeaveRequest>> getMyLeaveRequestsPage(
    String userId, {
    required int offset,
    required int limit,
    required List<String> leaveTypes,
    String? statusEquals,
  }) async {
    var q = client
        .from('leave_requests')
        .select(_leaveListSelect)
        .eq('user_id', userId);
    if (leaveTypes.length == 1) {
      q = q.eq('leave_type', leaveTypes.first);
    } else if (leaveTypes.length > 1) {
      q = q.inFilter('leave_type', leaveTypes);
    }
    if (statusEquals != null &&
        statusEquals.isNotEmpty &&
        statusEquals != 'all') {
      q = q.eq('status', statusEquals);
    }
    final start = offset;
    final end = offset + limit - 1;
    final data = await q
        .order('created_at', ascending: false)
        .range(start, end);
    return data.map<LeaveRequest>((e) => LeaveRequest.fromMap(e)).toList();
  }

  /// Returns pending or approved leave requests for [userId] that overlap
  /// [startDate]...[endDate]. Used to show an inline conflict warning before
  /// the user submits a new request.
  static Future<List<LeaveRequest>> getOverlappingLeaves({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startStr = _dateString(startDate);
    final endStr = _dateString(endDate);
    final data = await client
        .from('leave_requests')
        .select(_leaveListSelect)
        .eq('user_id', userId)
        .inFilter('status', ['pending', 'approved'])
        .lte('start_date', endStr)
        .gte('end_date', startStr)
        .order('start_date');
    return data.map<LeaveRequest>((e) => LeaveRequest.fromMap(e)).toList();
  }

  // ──────────────────────────────────────────────
  // EXPENSE CLAIMS
  // ──────────────────────────────────────────────

  static const _claimAttachmentsBucket = 'claim-attachments';
  static const _claimSelect =
      'id,user_id,title,description,category,amount,currency,expense_date,'
      'status,admin_comment,created_at';
  static const _claimAttachmentSelect =
      'id,claim_id,storage_path,original_name,byte_size,content_type,created_at';
  static const _claimWithAttachmentsSelect =
      'id,user_id,title,description,category,amount,currency,expense_date,'
      'status,admin_comment,created_at,'
      'claim_attachments(id,claim_id,storage_path,original_name,byte_size,content_type,created_at)';
  static const _claimWithUserAndAttachmentsSelect =
      'id,user_id,title,description,category,amount,currency,expense_date,'
      'status,admin_comment,created_at,users(name),'
      'claim_attachments(id,claim_id,storage_path,original_name,byte_size,content_type,created_at)';
  static const maxClaimFilesPerSubmit = 8;
  static const maxClaimAttachmentBytes = 10 * 1024 * 1024; // 10 MB
  static const allowedClaimAttachmentExt = {
    '.pdf',
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.doc',
    '.docx',
    '.xls',
    '.xlsx',
    '.csv',
    '.txt',
    '.zip',
  };

  /// Validates one picked file (size + extension). Throws [Exception] with a
  /// plain message if invalid.
  static void validateClaimFile(PlatformFile file) {
    final name = file.name.trim();
    if (name.isEmpty) throw Exception('Invalid file name');

    final ext = _fileExtensionLower(name);
    if (ext == null || !allowedClaimAttachmentExt.contains(ext)) {
      throw Exception(
        'Unsupported file type. Use PDF, images, Office docs, CSV, TXT, or ZIP.',
      );
    }

    final len = file.size;
    if (file.bytes != null) {
      if (file.bytes!.length > maxClaimAttachmentBytes) {
        throw Exception('Each file must be 10 MB or smaller');
      }
    } else if (len > 0 && len > maxClaimAttachmentBytes) {
      throw Exception('Each file must be 10 MB or smaller');
    }
    if (file.bytes == null && file.path == null) {
      throw Exception('Could not read the file. Pick again with data enabled.');
    }
    if (file.path != null && file.bytes == null) {
      // Size from picker may be 0 on some platforms — actual check happens in upload.
    }
  }

  static Future<String> uploadClaimAttachment({
    required String userId,
    required String claimId,
    required PlatformFile file,
  }) async {
    validateClaimFile(file);

    final name = file.name.trim();
    final safe = _sanitizeFileName(name);
    final objectPath =
        '$userId/$claimId/${DateTime.now().millisecondsSinceEpoch}_$safe';

    if (file.bytes != null) {
      if (file.bytes!.length > maxClaimAttachmentBytes) {
        throw Exception('Each file must be 10 MB or smaller');
      }
      await client.storage
          .from(_claimAttachmentsBucket)
          .uploadBinary(
            objectPath,
            file.bytes!,
            fileOptions: const FileOptions(upsert: false),
          );
    } else if (file.path != null) {
      final f = File(file.path!);
      final fileLen = await f.length();
      if (fileLen > maxClaimAttachmentBytes) {
        throw Exception('Each file must be 10 MB or smaller');
      }
      await client.storage
          .from(_claimAttachmentsBucket)
          .upload(objectPath, f, fileOptions: const FileOptions(upsert: false));
    } else {
      throw Exception('Could not read the file. Pick again.');
    }

    return objectPath;
  }

  static Future<String> getClaimAttachmentSignedUrl(
    String storagePath, {
    int expiresInSeconds = 3600,
  }) {
    return client.storage
        .from(_claimAttachmentsBucket)
        .createSignedUrl(storagePath, expiresInSeconds);
  }

  static Future<ExpenseClaim> createExpenseClaim({
    required String userId,
    required String title,
    required String description,
    required String category,
    required double amount,
    String currency = 'MYR',
    required DateTime expenseDate,
  }) async {
    final data = await client
        .from('expense_claims')
        .insert({
          'user_id': userId,
          'title': title.trim(),
          'description': description.trim(),
          'category': category,
          'amount': amount,
          'currency': currency.trim().toUpperCase(),
          'expense_date': _dateString(expenseDate),
          'status': 'pending',
        })
        .select(_claimSelect)
        .single();
    return ExpenseClaim.fromMap(data);
  }

  static Future<ClaimAttachment> insertClaimAttachmentRow({
    required String claimId,
    required String storagePath,
    required String originalName,
    int? byteSize,
    String? contentType,
  }) async {
    final data = await client
        .from('claim_attachments')
        .insert({
          'claim_id': claimId,
          'storage_path': storagePath,
          'original_name': originalName.trim().isEmpty
              ? 'attachment'
              : originalName.trim(),
          if (byteSize != null) 'byte_size': byteSize,
          if (contentType != null && contentType.isNotEmpty)
            'content_type': contentType,
        })
        .select(_claimAttachmentSelect)
        .single();
    return ClaimAttachment.fromMap(data);
  }

  /// Creates the claim, uploads every file, and inserts attachment rows.
  /// On any failure, uploaded objects are removed and the claim row is deleted.
  static Future<ExpenseClaim> submitExpenseClaimWithFiles({
    required String userId,
    required String title,
    required String description,
    required String category,
    required double amount,
    String currency = 'MYR',
    required DateTime expenseDate,
    required List<PlatformFile> files,
  }) async {
    if (files.isEmpty) {
      throw Exception('Add at least one receipt or supporting document');
    }
    if (files.length > maxClaimFilesPerSubmit) {
      throw Exception('Too many files (maximum $maxClaimFilesPerSubmit)');
    }
    for (final f in files) {
      validateClaimFile(f);
    }

    ExpenseClaim? claim;
    final uploadedPaths = <String>[];
    try {
      claim = await createExpenseClaim(
        userId: userId,
        title: title,
        description: description,
        category: category,
        amount: amount,
        currency: currency,
        expenseDate: expenseDate,
      );
      final cid = claim.id;

      // Upload all attachments in parallel then insert their DB rows.
      final paths = await Future.wait(
        files.map((file) => uploadClaimAttachment(
          userId: userId,
          claimId: cid,
          file: file,
        )),
      );
      uploadedPaths.addAll(paths);
      await Future.wait(
        List.generate(files.length, (i) => insertClaimAttachmentRow(
          claimId: cid,
          storagePath: paths[i],
          originalName: files[i].name,
          byteSize: files[i].size > 0 ? files[i].size : null,
        )),
      );

      final detail = await getExpenseClaimById(cid);
      if (detail == null) throw Exception('Could not load submitted claim');
      return detail;
    } catch (e) {
      for (final p in uploadedPaths.reversed) {
        try {
          await client.storage.from(_claimAttachmentsBucket).remove([p]);
        } catch (_) {}
      }
      if (claim != null) {
        try {
          await client.from('expense_claims').delete().eq('id', claim.id);
        } catch (_) {}
      }
      rethrow;
    }
  }

  static Future<List<ExpenseClaim>> getMyExpenseClaims(String userId) async {
    final data = await client
        .from('expense_claims')
        .select(_claimSelect)
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return data.map<ExpenseClaim>((e) => ExpenseClaim.fromMap(e)).toList();
  }

  static Future<ExpenseClaim?> getExpenseClaimById(String claimId) async {
    final data = await client
        .from('expense_claims')
        .select(_claimWithAttachmentsSelect)
        .eq('id', claimId)
        .maybeSingle();
    if (data == null) return null;
    final m = Map<String, dynamic>.from(data);
    final att = m['claim_attachments'];
    if (att is List) {
      att.sort((a, b) {
        final ma = a as Map<String, dynamic>;
        final mb = b as Map<String, dynamic>;
        return (ma['created_at'] as String).compareTo(
          mb['created_at'] as String,
        );
      });
    }
    return ExpenseClaim.fromMap(m);
  }

  static Future<List<ExpenseClaim>> getAllExpenseClaims() async {
    final data = await client
        .from('expense_claims')
        .select(_claimWithUserAndAttachmentsSelect)
        .order('created_at', ascending: false);
    return data.map<ExpenseClaim>((row) {
      final m = Map<String, dynamic>.from(row);
      final att = m['claim_attachments'];
      if (att is List) {
        att.sort((a, b) {
          final ma = a as Map<String, dynamic>;
          final mb = b as Map<String, dynamic>;
          return (ma['created_at'] as String).compareTo(
            mb['created_at'] as String,
          );
        });
      }
      return ExpenseClaim.fromMap(m);
    }).toList();
  }

  static Future<int> getPendingExpenseClaimCount() async {
    final res = await client
        .from('expense_claims')
        .select()
        .eq('status', 'pending')
        .count(CountOption.exact);
    return res.count;
  }

  static Future<void> updateExpenseClaimStatus({
    required String claimId,
    required String status,
    String? adminComment,
  }) async {
    await client
        .from('expense_claims')
        .update({'status': status, 'admin_comment': adminComment})
        .eq('id', claimId);
  }

  static Future<List<LeaveRequest>> getAllLeaveRequests() async {
    final data = await client
        .from('leave_requests')
        .select(_leaveWithUserSelect)
        .order('created_at', ascending: false);
    return data.map<LeaveRequest>((e) => LeaveRequest.fromMap(e)).toList();
  }

  static Future<List<LeaveRequest>> getPendingLeaveRequests({
    int limit = 100,
  }) async {
    final data = await client
        .from('leave_requests')
        .select(_leaveWithUserSelect)
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(limit);
    return data.map<LeaveRequest>((e) => LeaveRequest.fromMap(e)).toList();
  }

  static Future<int> getPendingLeaveRequestCount() async {
    final res = await client
        .from('leave_requests')
        .select()
        .eq('status', 'pending')
        .count(CountOption.exact);
    return res.count;
  }

  static Future<List<LeaveRequest>> getApprovedLeavesByMonth(
    DateTime month,
  ) async {
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1);
    final lastDay = monthEnd.subtract(const Duration(days: 1));
    final data = await client
        .from('leave_requests')
        .select(_leaveWithUserSelect)
        .eq('status', 'approved')
        .lte('start_date', _dateString(lastDay))
        .gte('end_date', _dateString(monthStart))
        .order('start_date');
    return data.map<LeaveRequest>((e) => LeaveRequest.fromMap(e)).toList();
  }

  static Future<List<LeaveRequest>> _getApprovedLeaveRowsByMonth(
    DateTime month,
  ) async {
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1);
    final lastDay = monthEnd.subtract(const Duration(days: 1));
    final data = await client
        .from('leave_requests')
        .select(_leaveListSelect)
        .eq('status', 'approved')
        .lte('start_date', _dateString(lastDay))
        .gte('end_date', _dateString(monthStart))
        .order('start_date');
    return data.map<LeaveRequest>((e) => LeaveRequest.fromMap(e)).toList();
  }

  static Future<List<LeaveRequest>> getEmployeeApprovedLeavesByMonth(
    String userId,
    DateTime month,
  ) async {
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1);
    final lastDay = monthEnd.subtract(const Duration(days: 1));
    final data = await client
        .from('leave_requests')
        .select(_leaveListSelect)
        .eq('user_id', userId)
        .eq('status', 'approved')
        .lte('start_date', _dateString(lastDay))
        .gte('end_date', _dateString(monthStart))
        .order('start_date');
    return data.map<LeaveRequest>((e) => LeaveRequest.fromMap(e)).toList();
  }

  static Future<List<MonthlyAttendanceSummary>> getMonthlyAttendanceSummaries(
    DateTime month,
  ) async {
    final results = await Future.wait([
      getAllEmployees(),
      _getAttendanceRowsByMonth(month),
      _getApprovedLeaveRowsByMonth(month),
    ]);

    final employees = results[0] as List<AppUser>;
    final records = results[1] as List<Attendance>;
    final approvedLeaves = results[2] as List<LeaveRequest>;

    final byUserAttendance = <String, List<Attendance>>{};
    for (final record in records) {
      byUserAttendance.putIfAbsent(record.userId, () => []).add(record);
    }

    final approvedLeaveDays = <String, int>{};
    for (final leave in approvedLeaves) {
      approvedLeaveDays.update(
        leave.userId,
        (value) =>
            value + _overlapDaysInMonth(leave.startDate, leave.endDate, month),
        ifAbsent: () =>
            _overlapDaysInMonth(leave.startDate, leave.endDate, month),
      );
    }

    final summaries = employees.map((employee) {
      final employeeRecords = List<Attendance>.from(
        byUserAttendance[employee.id] ?? <Attendance>[],
      );
      employeeRecords.sort((a, b) => b.date.compareTo(a.date));
      var completedAttendanceDays = 0;
      var openAttendanceDays = 0;
      DateTime? lastDate;

      for (final record in employeeRecords) {
        if (record.status == 'completed') {
          completedAttendanceDays += 1;
        } else if (record.status == 'in_progress') {
          openAttendanceDays += 1;
        }

        if (lastDate == null || record.date.isAfter(lastDate)) {
          lastDate = record.date;
        }
      }

      return MonthlyAttendanceSummary(
        employeeId: employee.id,
        employeeName: employee.name,
        username: employee.username,
        email: employee.email,
        totalAttendanceRecords: employeeRecords.length,
        completedAttendanceDays: completedAttendanceDays,
        openAttendanceDays: openAttendanceDays,
        approvedLeaveDays: approvedLeaveDays[employee.id] ?? 0,
        lastAttendanceDate: lastDate,
      );
    }).toList();

    summaries.sort((a, b) {
      if (a.hasNoAttendance != b.hasNoAttendance) {
        return a.hasNoAttendance ? 1 : -1;
      }
      final attendanceCompare = b.completedAttendanceDays.compareTo(
        a.completedAttendanceDays,
      );
      if (attendanceCompare != 0) return attendanceCompare;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return summaries;
  }

  static Future<EmployeeMonthlyCalendarData> getEmployeeMonthlyCalendar(
    String employeeId,
    DateTime month,
  ) async {
    final normalizedMonth = DateTime(month.year, month.month);
    final results = await Future.wait([
      getEmployeeAttendanceByMonth(employeeId, normalizedMonth),
      getEmployeeApprovedLeavesByMonth(employeeId, normalizedMonth),
    ]);
    final attendanceRecords = results[0] as List<Attendance>;
    final approvedLeaves = results[1] as List<LeaveRequest>;

    final attendanceByDate = <String, List<Attendance>>{};
    for (final record in attendanceRecords) {
      final key = _dateString(record.date);
      attendanceByDate.putIfAbsent(key, () => []).add(record);
    }

    final leaveByDate = <String, LeaveRequest>{};
    for (final leave in approvedLeaves) {
      final effectiveStart = DateTime(
        leave.startDate.year,
        leave.startDate.month,
        leave.startDate.day,
      );
      final effectiveEnd = DateTime(
        leave.endDate.year,
        leave.endDate.month,
        leave.endDate.day,
      );
      for (
        var date = effectiveStart;
        !date.isAfter(effectiveEnd);
        date = date.add(const Duration(days: 1))
      ) {
        if (date.year != normalizedMonth.year ||
            date.month != normalizedMonth.month) {
          continue;
        }
        leaveByDate.putIfAbsent(_dateString(date), () => leave);
      }
    }

    final daysInMonth = DateTime(
      normalizedMonth.year,
      normalizedMonth.month + 1,
      0,
    ).day;
    final todayKey = _todayString();

    final days = List<EmployeeCalendarDay>.generate(daysInMonth, (index) {
      final date = DateTime(
        normalizedMonth.year,
        normalizedMonth.month,
        index + 1,
      );
      final key = _dateString(date);
      return EmployeeCalendarDay(
        date: date,
        attendanceRecords: List<Attendance>.from(
          attendanceByDate[key] ?? const [],
        ),
        approvedLeave: leaveByDate[key],
        isToday: key == todayKey,
      );
    });

    return EmployeeMonthlyCalendarData(month: normalizedMonth, days: days);
  }

  // ──────────────────────────────────────────────
  // NOTIFICATIONS
  // ──────────────────────────────────────────────

  static const _notificationSelect =
      'id,user_id,title,body,type,related_leave_request_id,is_read,created_at';

  static Future<List<AppNotification>> getMyNotifications(String userId) async {
    final data = await client
        .from('app_notifications')
        .select(_notificationSelect)
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100);
    return data
        .map<AppNotification>((e) => AppNotification.fromMap(e))
        .toList();
  }

  static Future<int> getUnreadNotificationCount(String userId) async {
    final res = await client
        .from('app_notifications')
        .select()
        .eq('user_id', userId)
        .eq('is_read', false)
        .count(CountOption.exact);
    return res.count;
  }

  static Future<void> markNotificationRead(String notificationId) async {
    await client
        .from('app_notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  static Future<void> markAllNotificationsRead(String userId) async {
    await client
        .from('app_notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  // ──────────────────────────────────────────────
  // COMPANY ANNOUNCEMENTS (admin-authored, all read)
  // ──────────────────────────────────────────────

  static Future<List<CompanyAnnouncement>> getCompanyAnnouncements({
    int limit = 100,
  }) async {
    final data = await client
        .from('company_announcements')
        .select('id,title,body,created_at,created_by, users(name)')
        .order('created_at', ascending: false)
        .limit(limit);
    return data
        .map<CompanyAnnouncement>(
          (e) =>
              CompanyAnnouncement.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  static Future<int> getCompanyAnnouncementCountAfter(
    DateTime? afterUtc,
  ) async {
    var query = client.from('company_announcements').select();
    if (afterUtc != null) {
      query = query.gt('created_at', afterUtc.toUtc().toIso8601String());
    }
    final res = await query.count(CountOption.exact);
    return res.count;
  }

  static Future<CompanyAnnouncement> createCompanyAnnouncement({
    required String title,
    required String body,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not signed in');
    final t = title.trim();
    final b = body.trim();
    if (t.isEmpty) throw Exception('Title is required');
    if (b.isEmpty) throw Exception('Message is required');
    final row = await client
        .from('company_announcements')
        .insert({'title': t, 'body': b, 'created_by': uid})
        .select('id,title,body,created_at,created_by, users(name)')
        .single();
    return CompanyAnnouncement.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<void> deleteCompanyAnnouncement(String id) async {
    await client.from('company_announcements').delete().eq('id', id);
  }

  // ──────────────────────────────────────────────
  // PAYROLL (single company: admin full access; employees read own payslips)
  // ──────────────────────────────────────────────

  static const _payrollStatutorySelect =
      'id,label,effective_from,epf_employee_pct,epf_employer_pct,epf_salary_ceiling,'
      'socso_employee_pct,socso_employer_pct,eis_employee_pct,eis_employer_pct,'
      'ot_hourly_multiplier,standard_hours_per_day,created_at';
  static const _payrollSalarySelect =
      'user_id,staff_id,department,position,employment_status,basic_salary,fixed_allowance,'
      'monthly_commission,monthly_incentive,monthly_increment,ot_eligible,compensation_type,epf_category,'
      'socso_category,eis_eligible,payment_method,bank_name,'
      'bank_account_number,payroll_status,updated_at';
  static const _payrollRunSelect =
      'id,period_year,period_month,status,statutory_config_id,pay_date,notes,'
      'total_net_pay,total_employer_cost,employee_count,created_by,approved_by,'
      'paid_by,approved_at,paid_at,created_at,updated_at';
  static const _payrollItemSelect =
      'id,payroll_run_id,user_id,employee_name_snapshot,working_weekdays,'
      'present_days,ot_hours,unpaid_leave_days,compensation_type,basic_amount,'
      'allowance_amount,commission_amount,incentive_amount,increment_amount,ot_amount,unpaid_leave_deduction,'
      'epf_employee,epf_employer,socso_employee,socso_employer,eis_employee,'
      'eis_employer,gross_pay,total_deduction,net_salary,calc_note,'
      'created_at,updated_at';
  static const _payrollHistorySelect =
      'id,payroll_run_id,user_id,employee_name_snapshot,working_weekdays,'
      'present_days,ot_hours,unpaid_leave_days,compensation_type,basic_amount,'
      'allowance_amount,commission_amount,incentive_amount,increment_amount,ot_amount,unpaid_leave_deduction,'
      'epf_employee,epf_employer,socso_employee,socso_employer,eis_employee,'
      'eis_employer,gross_pay,total_deduction,net_salary,calc_note,'
      'created_at,updated_at,'
      'payroll_runs(id,period_year,period_month,status,statutory_config_id,'
      'pay_date,notes,total_net_pay,total_employer_cost,employee_count,'
      'created_by,approved_by,paid_by,approved_at,paid_at,created_at,updated_at)';

  static Future<List<PayrollStatutoryConfig>>
  getPayrollStatutoryConfigs() async {
    final data = await client
        .from('payroll_statutory_config')
        .select(_payrollStatutorySelect)
        .order('effective_from', ascending: false)
        .order('created_at', ascending: false);
    return data
        .map<PayrollStatutoryConfig>(
          (e) => PayrollStatutoryConfig.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  static Future<PayrollStatutoryConfig?>
  getLatestPayrollStatutoryConfig() async {
    final data = await client
        .from('payroll_statutory_config')
        .select(_payrollStatutorySelect)
        .order('effective_from', ascending: false)
        .order('created_at', ascending: false)
        .limit(1);
    if ((data as List).isEmpty) return null;
    return PayrollStatutoryConfig.fromMap(
      Map<String, dynamic>.from(data.first as Map),
    );
  }

  static Future<PayrollStatutoryConfig> insertPayrollStatutoryConfig(
    PayrollStatutoryConfig draft,
  ) async {
    final row = await client
        .from('payroll_statutory_config')
        .insert(draft.toUpsertMap())
        .select(_payrollStatutorySelect)
        .single();
    return PayrollStatutoryConfig.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<PayrollStatutoryConfig> updatePayrollStatutoryConfig(
    PayrollStatutoryConfig c,
  ) async {
    final row = await client
        .from('payroll_statutory_config')
        .update(c.toUpsertMap())
        .eq('id', c.id)
        .select(_payrollStatutorySelect)
        .single();
    return PayrollStatutoryConfig.fromMap(Map<String, dynamic>.from(row));
  }

  /// Deletes [id] only when no payroll run still references it.
  static Future<void> deletePayrollStatutoryConfig(String id) async {
    final refs = await client
        .from('payroll_runs')
        .select('id')
        .eq('statutory_config_id', id)
        .limit(1);
    if ((refs as List).isNotEmpty) {
      throw Exception(
        'This rate set is linked to one or more payroll runs and cannot be deleted.',
      );
    }
    await client.from('payroll_statutory_config').delete().eq('id', id);
  }

  /// Returns usage count keyed by statutory config id.
  static Future<Map<String, int>> getPayrollStatutoryUsageCounts() async {
    final rows = await client
        .from('payroll_runs')
        .select('statutory_config_id')
        .not('statutory_config_id', 'is', null);
    final out = <String, int>{};
    for (final raw in rows as List) {
      final map = Map<String, dynamic>.from(raw as Map);
      final id = map['statutory_config_id'] as String?;
      if (id == null || id.isEmpty) continue;
      out.update(id, (v) => v + 1, ifAbsent: () => 1);
    }
    return out;
  }

  /// Reassigns all payroll runs from one statutory config id to another.
  /// Returns number of payroll runs updated.
  static Future<int> reassignPayrollStatutoryUsage({
    required String fromConfigId,
    required String toConfigId,
  }) async {
    if (fromConfigId == toConfigId) return 0;
    final refs = await client
        .from('payroll_runs')
        .select('id')
        .eq('statutory_config_id', fromConfigId);
    final rows = refs as List;
    if (rows.isEmpty) return 0;
    await client
        .from('payroll_runs')
        .update({
          'statutory_config_id': toConfigId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('statutory_config_id', fromConfigId);
    return rows.length;
  }

  static Future<List<PayrollSalarySetting>> getPayrollSalarySettings() async {
    final data = await client
        .from('payroll_salary_settings')
        .select(_payrollSalarySelect)
        .order('updated_at', ascending: false);
    return data
        .map<PayrollSalarySetting>(
          (e) =>
              PayrollSalarySetting.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .where((s) => s.userId.isNotEmpty)
        .toList();
  }

  static Future<PayrollSalarySetting?> getPayrollSalarySetting(
    String userId,
  ) async {
    try {
      final row = await client
          .from('payroll_salary_settings')
          .select(_payrollSalarySelect)
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;
      return PayrollSalarySetting.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  static Future<PayrollSalarySetting> upsertPayrollSalarySetting(
    PayrollSalarySetting s,
  ) async {
    final row = await client
        .from('payroll_salary_settings')
        .upsert({
          ...s.toUpsertMap(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select(_payrollSalarySelect)
        .single();
    return PayrollSalarySetting.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<List<PayrollRun>> getPayrollRuns() async {
    final data = await client
        .from('payroll_runs')
        .select(_payrollRunSelect)
        .order('period_year', ascending: false)
        .order('period_month', ascending: false);
    return data
        .map<PayrollRun>(
          (e) => PayrollRun.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  static Future<PayrollRun?> getPayrollRun(String id) async {
    try {
      final row = await client
          .from('payroll_runs')
          .select(_payrollRunSelect)
          .eq('id', id)
          .single();
      return PayrollRun.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  static Future<PayrollRun?> getPayrollRunForPeriod(int year, int month) async {
    try {
      final row = await client
          .from('payroll_runs')
          .select(_payrollRunSelect)
          .eq('period_year', year)
          .eq('period_month', month)
          .maybeSingle();
      if (row == null) return null;
      return PayrollRun.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  static Future<PayrollRun> createPayrollDraftRun({
    required int year,
    required int month,
    String? statutoryConfigId,
    DateTime? payDate,
  }) async {
    final uid = currentUserId;
    final row = await client
        .from('payroll_runs')
        .insert({
          'period_year': year,
          'period_month': month,
          'status': 'draft',
          'statutory_config_id': statutoryConfigId,
          'pay_date': payDate != null ? _dateString(payDate) : null,
          'created_by': uid,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select(_payrollRunSelect)
        .single();
    return PayrollRun.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<PayrollRun> updatePayrollRun(
    PayrollRun run,
    Map<String, dynamic> patch,
  ) async {
    final row = await client
        .from('payroll_runs')
        .update({
          ...patch,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', run.id)
        .select(_payrollRunSelect)
        .single();
    return PayrollRun.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<List<PayrollItem>> getPayrollItems(String runId) async {
    final data = await client
        .from('payroll_items')
        .select(_payrollItemSelect)
        .eq('payroll_run_id', runId)
        .order('employee_name_snapshot');
    return data
        .map<PayrollItem>(
          (e) => PayrollItem.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  static Future<PayrollItem?> getPayrollItem(String itemId) async {
    try {
      final row = await client
          .from('payroll_items')
          .select(_payrollItemSelect)
          .eq('id', itemId)
          .single();
      return PayrollItem.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  /// Employee self-service: own [PayrollItem]s whose run is **approved** or **paid**
  /// (enforced in Supabase RLS). Newest payroll periods first.
  static Future<List<PayrollHistoryEntry>> getMyPayrollHistory() async {
    final uid = currentUserId;
    if (uid == null) return [];
    final data = await client
        .from('payroll_items')
        .select(_payrollHistorySelect)
        .eq('user_id', uid)
        .order('updated_at', ascending: false);
    final list = data as List<dynamic>;
    final out = <PayrollHistoryEntry>[];
    for (final raw in list) {
      final row = Map<String, dynamic>.from(raw as Map);
      final pr = row.remove('payroll_runs');
      if (pr == null) continue;
      final Map<String, dynamic> runMap;
      if (pr is Map) {
        runMap = Map<String, dynamic>.from(pr);
      } else if (pr is List && pr.isNotEmpty) {
        runMap = Map<String, dynamic>.from(pr.first as Map);
      } else {
        continue;
      }
      out.add(
        PayrollHistoryEntry(
          run: PayrollRun.fromMap(runMap),
          item: PayrollItem.fromMap(row),
        ),
      );
    }
    out.sort((a, b) {
      final y = b.run.periodYear.compareTo(a.run.periodYear);
      return y != 0 ? y : b.run.periodMonth.compareTo(a.run.periodMonth);
    });
    return out;
  }

  /// Pulls attendance + leave, recomputes all line items for [run].
  static Future<void> payrollSyncAndCalculate(PayrollRun run) async {
    if (run.status == 'paid' || run.status == 'cancelled') {
      throw Exception('Cannot recalculate a closed run');
    }
    final allConfigs = await getPayrollStatutoryConfigs();
    PayrollStatutoryConfig? config;
    if (run.statutoryConfigId != null) {
      for (final c in allConfigs) {
        if (c.id == run.statutoryConfigId) {
          config = c;
          break;
        }
      }
    }
    config ??= allConfigs.isNotEmpty ? allConfigs.first : null;
    if (config == null) {
      throw Exception(
        'No statutory configuration. Add one in Payroll settings.',
      );
    }

    final month = DateTime(run.periodYear, run.periodMonth);
    final results = await Future.wait<Object>([
      getAllEmployees(),
      getAttendanceByMonth(month),
      getApprovedLeavesByMonth(month),
      getPayrollSalarySettings(),
    ]);
    final employees = results[0] as List<AppUser>;
    final staff = employees.where((e) => e.role == 'employee').toList();
    final attendanceMonth = results[1] as List<Attendance>;
    final leaves = results[2] as List<LeaveRequest>;
    final salaryRows = results[3] as List<PayrollSalarySetting>;
    final salaryByUser = {for (final s in salaryRows) s.userId: s};
    final leavesByUser = <String, List<LeaveRequest>>{};
    for (final leave in leaves) {
      leavesByUser.putIfAbsent(leave.userId, () => <LeaveRequest>[]).add(leave);
    }

    final wd = PayrollEngine.workingWeekdaysInMonth(month);
    var totalNet = 0.0;
    var totalErCost = 0.0;
    final itemsPayload = <Map<String, dynamic>>[];

    for (final u in staff) {
      final salary = salaryByUser[u.id];
      if (salary == null || !salary.isActive) continue;

      final userLeaves = leavesByUser[u.id] ?? const <LeaveRequest>[];
      final presentDays = PayrollEngine.presentDaysExcludingApprovedLeave(
        userId: u.id,
        month: month,
        attendanceInMonth: attendanceMonth,
        leaves: leaves,
      );
      final unpaidDays = salary.isIntern
          ? PayrollEngine.internLeaveCalendarUnitsFromRequests(
              userId: u.id,
              month: month,
              leaves: userLeaves,
            )
          : PayrollEngine.unpaidLeaveDaysFromRequests(
              userId: u.id,
              month: month,
              leaves: userLeaves,
            );

      final calc = PayrollEngine.compute(
        salary: salary,
        statutory: config,
        workingWeekdays: wd,
        presentDays: presentDays,
        month: month,
        leaves: userLeaves,
        employeeDateOfBirth: u.dateOfBirth,
      );

      totalNet += calc.netSalary;
      totalErCost += calc.epfEmployer + calc.socsoEmployer + calc.eisEmployer;

      itemsPayload.add({
        'payroll_run_id': run.id,
        'user_id': u.id,
        'employee_name_snapshot': u.name.isNotEmpty ? u.name : u.username,
        'working_weekdays': wd,
        'present_days': presentDays,
        'ot_hours': 0,
        'unpaid_leave_days': unpaidDays,
        'compensation_type': salary.compensationType,
        'basic_amount': calc.basicAmount,
        'allowance_amount': calc.allowanceAmount,
        'commission_amount': calc.commissionAmount,
        'incentive_amount': calc.incentiveAmount,
        'increment_amount': calc.incrementAmount,
        'ot_amount': calc.otAmount,
        'unpaid_leave_deduction': calc.unpaidLeaveDeduction,
        'epf_employee': calc.epfEmployee,
        'epf_employer': calc.epfEmployer,
        'socso_employee': calc.socsoEmployee,
        'socso_employer': calc.socsoEmployer,
        'eis_employee': calc.eisEmployee,
        'eis_employer': calc.eisEmployer,
        'gross_pay': calc.grossPay,
        'total_deduction': calc.totalDeduction,
        'net_salary': calc.netSalary,
        'calc_note': calc.calcNote,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }

    if (itemsPayload.isNotEmpty) {
      await client
          .from('payroll_items')
          .upsert(itemsPayload, onConflict: 'payroll_run_id,user_id');
    }

    await client
        .from('payroll_runs')
        .update({
          'status': 'calculated',
          'statutory_config_id': config.id,
          'total_net_pay': totalNet,
          'total_employer_cost': totalErCost,
          'employee_count': itemsPayload.length,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', run.id);
  }

  static Future<PayrollItem> updatePayrollItem(PayrollItem item) async {
    final row = await client
        .from('payroll_items')
        .update({
          ...item.toUpdateAmountsMap(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', item.id)
        .select(_payrollItemSelect)
        .single();
    return PayrollItem.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<void> payrollRecalculateRunTotals(String runId) async {
    final items = await getPayrollItems(runId);
    double net = 0;
    double er = 0;
    for (final i in items) {
      net += i.netSalary;
      er += i.epfEmployer + i.socsoEmployer + i.eisEmployer;
    }
    await client
        .from('payroll_runs')
        .update({
          'total_net_pay': net,
          'total_employer_cost': er,
          'employee_count': items.length,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', runId);
  }

  static Future<PayrollRun> approvePayrollRun(String runId) async {
    final uid = currentUserId;
    final row = await client
        .from('payroll_runs')
        .update({
          'status': 'approved',
          'approved_by': uid,
          'approved_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', runId)
        .select(_payrollRunSelect)
        .single();
    return PayrollRun.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<PayrollRun> markPayrollRunPaid(
    String runId, {
    DateTime? paidAt,
  }) async {
    final uid = currentUserId;
    final row = await client
        .from('payroll_runs')
        .update({
          'status': 'paid',
          'paid_by': uid,
          'paid_at': (paidAt ?? DateTime.now()).toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', runId)
        .select(_payrollRunSelect)
        .single();
    return PayrollRun.fromMap(Map<String, dynamic>.from(row));
  }

  // ──────────────────────────────────────────────
  // AUDIT
  // ──────────────────────────────────────────────

  static const _leaveAuditLogSelect =
      'id,leave_request_id,action,from_status,to_status,comment,actor_user_id,'
      'actor_name,created_at';

  static Future<List<LeaveAuditLog>> getLeaveAuditLogs(
    String leaveRequestId,
  ) async {
    final data = await client
        .from('leave_audit_logs')
        .select(_leaveAuditLogSelect)
        .eq('leave_request_id', leaveRequestId)
        .order('created_at', ascending: false);
    return data.map<LeaveAuditLog>((e) => LeaveAuditLog.fromMap(e)).toList();
  }

  static Future<int> updateLeaveStatus({
    required String leaveId,
    required String status,
    String? adminComment,
  }) async {
    if (status == 'approved') {
      // Try the transactional RPC first (approves + removes conflicting
      // attendance in one step). Falls back to two-step if not deployed.
      try {
        final data = await client.rpc(
          'approve_leave_and_clear_attendance',
          params: {'p_leave_id': leaveId, 'p_admin_comment': adminComment},
        );
        if (data is Map) {
          final count = data['attendance_removed_count'];
          if (count is int) return count;
          if (count is num) return count.toInt();
        }
        return 0;
      } on PostgrestException catch (e) {
        // PGRST202 = function not found — SQL not deployed yet.
        if (e.code != 'PGRST202') rethrow;
      }

      // Fallback: fetch the leave request to get the date range, update
      // the status, then delete conflicting attendance rows separately.
      final leaveRow = await client
          .from('leave_requests')
          .select(_leaveListSelect)
          .eq('id', leaveId)
          .single();
      final leave = LeaveRequest.fromMap(leaveRow);

      await client
          .from('leave_requests')
          .update({'status': 'approved', 'admin_comment': adminComment})
          .eq('id', leaveId);

      // Delete attendance rows within the approved leave date range.
      await client
          .from('attendance')
          .delete()
          .eq('user_id', leave.userId)
          .gte('date', _dateString(leave.startDate))
          .lte('date', _dateString(leave.endDate));

      return 0; // Row count not available without SECURITY DEFINER function.
    }

    await client
        .from('leave_requests')
        .update({'status': status, 'admin_comment': adminComment})
        .eq('id', leaveId);
    return 0;
  }

  // ──────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────

  static String _todayString() => AppTime.malaysiaDateString();

  static int _overlapDaysInMonth(DateTime start, DateTime end, DateTime month) {
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(
      month.year,
      month.month + 1,
    ).subtract(const Duration(days: 1));
    final effectiveStart = start.isAfter(monthStart) ? start : monthStart;
    final effectiveEnd = end.isBefore(monthEnd) ? end : monthEnd;
    if (effectiveEnd.isBefore(effectiveStart)) return 0;
    return effectiveEnd.difference(effectiveStart).inDays + 1;
  }

  static String _dateString(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

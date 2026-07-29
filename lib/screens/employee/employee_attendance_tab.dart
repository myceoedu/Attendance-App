import 'dart:async';
import '../../utils/app_route.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_theme.dart';
import '../../models/attendance.dart';
import '../../models/leave_request.dart';
import '../../providers/auth_provider.dart';
import '../../services/app_realtime.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_time.dart';
import '../../utils/async_load_guard.dart';
import '../../utils/error_messages.dart';
import 'attendance_history_screen.dart';
import 'employee_attendance_log_screen.dart';

/// Clock in / clock out flow for employees.
///
/// State machine
/// -------------
/// * `idle`      → no row for today          → show **Clock In**
/// * `working`   → row exists, clock_out null → show **Clock Out** + elapsed timer
/// * `done`      → clock_out set              → show completion message, buttons disabled
///
/// The UI trusts the server: every successful action replaces `_today`
/// with the row returned by Supabase, and Realtime keeps the state
/// in sync across devices.
class EmployeeAttendanceTab extends StatefulWidget {
  const EmployeeAttendanceTab({super.key});

  @override
  State<EmployeeAttendanceTab> createState() => _EmployeeAttendanceTabState();
}

enum _AttendanceState { blocked, idle, working, done }

class _EmployeeAttendanceTabState extends State<EmployeeAttendanceTab> {
  Attendance? _today;
  LeaveRequest? _todayApprovedLeave;
  bool _loading = true;
  Timer? _ticker;
  Timer? _realtimeDebounce;
  RealtimeChannel? _channel;
  RealtimeChannel? _leaveChannel;
  final _loadGuard = AsyncLoadGuard();
  late final ValueNotifier<DateTime> _now = ValueNotifier<DateTime>(
    AppTime.malaysiaNow(),
  );

  @override
  void initState() {
    super.initState();
    _syncTicker();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
      _attachRealtime();
    });
  }

  @override
  void dispose() {
    _loadGuard.invalidate();
    _ticker?.cancel();
    _realtimeDebounce?.cancel();
    AppRealtime.disposeChannel(_channel);
    AppRealtime.disposeChannel(_leaveChannel);
    _now.dispose();
    super.dispose();
  }

  /// Live clock only while working (1s). Otherwise refresh once a minute.
  void _syncTicker() {
    _ticker?.cancel();
    final working = _state == _AttendanceState.working;
    _ticker = Timer.periodic(
      working ? const Duration(seconds: 1) : const Duration(minutes: 1),
      (_) {
        if (mounted) _now.value = AppTime.malaysiaNow();
      },
    );
  }

  // ──────────────────────────────────────────────
  // Data
  // ──────────────────────────────────────────────

  _AttendanceState get _state {
    if (_todayApprovedLeave != null) return _AttendanceState.blocked;
    if (_today == null) return _AttendanceState.idle;
    if (_today!.clockOutTime != null || _today!.status == 'completed') {
      return _AttendanceState.done;
    }
    return _AttendanceState.working;
  }

  void _attachRealtime() {
    final uid = context.read<AuthProvider>().user?.id;
    if (uid == null) return;
    _channel = AppRealtime.subscribeMyAttendance(
      userId: uid,
      channelSuffix: 'clock',
      onReload: () {
        _realtimeDebounce?.cancel();
        _realtimeDebounce = Timer(const Duration(milliseconds: 400), () {
          if (mounted) _load(showSpinner: false);
        });
      },
    );
    _leaveChannel = AppRealtime.subscribeMyLeaves(
      userId: uid,
      channelSuffix: 'clock',
      onReload: () {
        _realtimeDebounce?.cancel();
        _realtimeDebounce = Timer(const Duration(milliseconds: 400), () {
          if (mounted) _load(showSpinner: false);
        });
      },
    );
  }

  Future<void> _load({bool showSpinner = true}) async {
    final gen = _loadGuard.begin();
    if (showSpinner && mounted) setState(() => _loading = true);
    try {
      final uid = context.read<AuthProvider>().user!.id;
      final results = await Future.wait([
        SupabaseService.getTodayAttendance(uid),
        SupabaseService.getApprovedLeaveForDate(uid, AppTime.malaysiaNow()),
      ]);
      if (!mounted || !_loadGuard.isCurrent(gen)) return;
      setState(() {
        final fetched = results[0] as Attendance?;
        final leave = results[1] as LeaveRequest?;

        if (fetched != null) {
          final cur = _today;
          final staleWhileClockOut =
              cur != null &&
              cur.id == fetched.id &&
              cur.clockOutTime != null &&
              fetched.clockOutTime == null &&
              (cur.status == 'completed' || fetched.status == 'in_progress');
          if (!staleWhileClockOut) {
            _today = fetched;
          }
        } else if (_today == null ||
            !Attendance.isPendingLocalSyncId(_today!.id)) {
          _today = null;
        }

        _todayApprovedLeave = leave;
        _loading = false;
      });
      _now.value = AppTime.malaysiaNow();
      _syncTicker();
    } catch (e) {
      if (!mounted || !_loadGuard.isCurrent(gen)) return;
      setState(() => _loading = false);
      _showError('Failed to load attendance: $e');
    }
  }

  Future<String?> _getLocationWithTimeout(Duration timeout) async {
    try {
      return await _getLocation().timeout(timeout);
    } on TimeoutException {
      return null;
    }
  }

  Future<String?> _getLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 4),
        ),
      );
      return '${pos.latitude},${pos.longitude}';
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────
  // Actions
  // ──────────────────────────────────────────────

  Future<void> _clockIn() async {
    if (_state != _AttendanceState.idle) return;
    final ok = await _confirm(
      title: 'Clock In',
      message: 'Start your workday now?',
      confirmLabel: 'Clock In',
      confirmColor: AppColors.primary,
      icon: Icons.login,
    );
    if (ok != true) return;
    if (!mounted) return;

    final uid = context.read<AuthProvider>().user!.id;
    final nowUtc = DateTime.now().toUtc();
    final cal = AppTime.malaysiaNow();
    final optimistic = Attendance(
      id: '${Attendance.pendingLocalIdPrefix}${nowUtc.microsecondsSinceEpoch}',
      userId: uid,
      clockInTime: nowUtc,
      clockOutTime: null,
      date: DateTime(cal.year, cal.month, cal.day),
      status: 'in_progress',
      location: null,
    );

    setState(() => _today = optimistic);
    _now.value = AppTime.malaysiaNow();
    _syncTicker();
    _showSuccess('Clocked in at ${_fmtTime(nowUtc)}');

    try {
      final location = await _getLocationWithTimeout(
        const Duration(seconds: 5),
      );
      final record = await SupabaseService.clockIn(uid, location: location);
      if (!mounted) return;
      setState(() => _today = record);
      _syncTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() => _today = null);
      _syncTicker();
      _showError(friendlyLeaveError(e));
    }
  }

  Future<void> _clockOut() async {
    if (_state != _AttendanceState.working || _today == null) return;
    if (Attendance.isPendingLocalSyncId(_today!.id)) return;

    final elapsed = _elapsed();
    final ok = await _confirm(
      title: 'Clock Out',
      message:
          'End your workday now?\n\nWorked: ${_fmtDuration(elapsed)}\nThis cannot be undone.',
      confirmLabel: 'Clock Out',
      confirmColor: AppColors.teal,
      icon: Icons.logout,
    );
    if (ok != true) return;
    if (!mounted) return;

    final snapshot = _today!;
    final nowUtc = DateTime.now().toUtc();
    final optimistic = Attendance(
      id: snapshot.id,
      userId: snapshot.userId,
      clockInTime: snapshot.clockInTime,
      clockOutTime: nowUtc,
      date: snapshot.date,
      status: 'completed',
      location: snapshot.location,
    );

    setState(() => _today = optimistic);
    _now.value = AppTime.malaysiaNow();
    _syncTicker();
    _showSuccess('Clocked out at ${_fmtTime(nowUtc)}');

    try {
      final record = await SupabaseService.clockOut(snapshot.id);
      if (!mounted) return;
      setState(() => _today = record);
      _syncTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() => _today = snapshot);
      _syncTicker();
      _showError(friendlyLeaveError(e));
    }
  }

  // ──────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────

  Duration _elapsed([DateTime? now]) {
    final inTime = _today?.clockInTime;
    if (inTime == null) return Duration.zero;
    final end = _today?.clockOutTime ?? (now ?? DateTime.now().toUtc());
    return end.difference(inTime);
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  String _fmtTime(DateTime t) =>
      DateFormat('h:mm a').format(AppTime.toMalaysia(t));

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    required IconData icon,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(icon, color: confirmColor),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Text(message, style: const TextStyle(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: confirmColor),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.success),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
    );
  }

  // ──────────────────────────────────────────────
  // UI
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEEE, d MMMM yyyy');
    final timeFmt = DateFormat('hh:mm:ss a');

    // No nested [Scaffold] — [AppBar] + [Expanded] under surface (avoid
    // [MaterialType.canvas] on web; it can composite as a flat primary tint).
    return SizedBox.expand(
      child: ColoredBox(
        color: AppColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBar(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: AppColors.onBrand,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shadowColor: Colors.transparent,
              systemOverlayStyle: AppChrome.onBrand,
              iconTheme: const IconThemeData(color: AppColors.onBrand),
              titleTextStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.onBrand,
              ),
              title: const Text('Attendance'),
              actions: [
                IconButton(
                  tooltip: 'History',
                  onPressed: () =>
                      pushAppPage(context, const AttendanceHistoryScreen()),
                  icon: const Icon(Icons.history),
                ),
                const SizedBox(width: 4),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _load(showSpinner: true),
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            label: const Text('Refresh'),
                          ),
                        ),
                        ValueListenableBuilder<DateTime>(
                          valueListenable: _now,
                          builder: (context, now, _) {
                            return Text(
                              dateFmt.format(now),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        ValueListenableBuilder<DateTime>(
                          valueListenable: _now,
                          builder: (context, now, _) {
                            return _clockCard(timeFmt, now);
                          },
                        ),
                        const SizedBox(height: 18),
                        _stepIndicator(),
                        const SizedBox(height: 22),
                        _primaryAction(),
                        const SizedBox(height: 20),
                        _attendanceHistoryEntryCard(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clockCard(DateFormat timeFmt, DateTime now) {
    final state = _state;
    final timeNow = timeFmt.format(now);

    final (String label, Color labelFg, Color labelBg) = switch (state) {
      _AttendanceState.blocked => (
        _todayApprovedLeave?.leaveTypeDisplay ?? 'Approved Leave',
        AppColors.leave,
        AppColors.leaveLight.withValues(alpha: 0.92),
      ),
      _AttendanceState.idle => (
        'Not Clocked In',
        AppColors.onBrand,
        Colors.white.withValues(alpha: 0.16),
      ),
      _AttendanceState.working => (
        'Working',
        AppColors.primaryDark,
        AppColors.primaryLight.withValues(alpha: 0.92),
      ),
      _AttendanceState.done => (
        'Done',
        AppColors.success,
        AppColors.successLight.withValues(alpha: 0.92),
      ),
    };

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppGradients.brandPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brandHeaderBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandHeaderShadow,
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            timeNow,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: AppColors.onBrand,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: labelBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: labelFg.withValues(
                  alpha: state == _AttendanceState.idle ? 0.35 : 0.22,
                ),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: labelFg,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _timeBlock(
                  'Clock In',
                  _today?.clockInTime != null
                      ? _fmtTime(_today!.clockInTime!)
                      : '--:--',
                  Icons.login,
                ),
              ),
              Container(
                width: 1,
                height: 42,
                color: AppColors.onBrand.withValues(alpha: 0.22),
              ),
              Expanded(
                child: _timeBlock(
                  'Clock Out',
                  _today?.clockOutTime != null
                      ? _fmtTime(_today!.clockOutTime!)
                      : '--:--',
                  Icons.logout,
                ),
              ),
            ],
          ),
          if (state == _AttendanceState.blocked) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.leaveLight.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.leave.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_busy_outlined,
                    size: 18,
                    color: AppColors.leave,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Approved leave covers today. Clock in is disabled.',
                      style: TextStyle(
                        color: AppColors.leave.withValues(alpha: 0.95),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (state != _AttendanceState.idle) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: AppColors.onBrandSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    state == _AttendanceState.done
                        ? 'Worked: ${_fmtDuration(_elapsed(now.toUtc()))}'
                        : 'Elapsed: ${_fmtDuration(_elapsed(now.toUtc()))}',
                    style: const TextStyle(
                      color: AppColors.onBrand,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeBlock(String label, String time, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.onBrandFaint, size: 18),
        const SizedBox(height: 6),
        Text(
          time,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.onBrand,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.onBrandMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _stepIndicator() {
    final state = _state;
    if (state == _AttendanceState.blocked) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.leaveLight.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.leave.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_busy_outlined, color: AppColors.leave),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${_todayApprovedLeave?.leaveTypeDisplay ?? 'Approved leave'} is active for today.',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final steps = const ['Clock In', 'Working', 'Clock Out'];
    final activeIndex = switch (state) {
      _AttendanceState.blocked => 0,
      _AttendanceState.idle => 0,
      _AttendanceState.working => 1,
      _AttendanceState.done => 2,
    };

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final lineActive = (i ~/ 2) < activeIndex;
          return Expanded(
            child: Container(
              height: 2,
              color: lineActive ? AppColors.primary : AppColors.divider,
            ),
          );
        }
        final idx = i ~/ 2;
        final isActive = idx <= activeIndex;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : Colors.white,
                border: Border.all(
                  color: isActive ? AppColors.primary : AppColors.divider,
                  width: 2,
                ),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${idx + 1}',
                style: TextStyle(
                  color: isActive ? Colors.white : AppColors.textHint,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              steps[idx],
              style: TextStyle(
                fontSize: 10,
                color: isActive ? AppColors.textPrimary : AppColors.textHint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _primaryAction() {
    switch (_state) {
      case _AttendanceState.blocked:
        final leave = _todayApprovedLeave;
        final range = leave == null
            ? ''
            : '${DateFormat('d MMM').format(leave.startDate)} - '
                  '${DateFormat('d MMM yyyy').format(leave.endDate)}';
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.leaveLight.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.leave.withValues(alpha: 0.28)),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, color: AppColors.leave, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Clock in blocked for today',
                    style: TextStyle(
                      color: AppColors.leave,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              if (leave != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${leave.leaveTypeDisplay} approved for $range',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (leave.reason.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    leave.reason.trim(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      case _AttendanceState.idle:
        return _bigButton(
          label: 'Clock In',
          icon: Icons.login,
          color: AppColors.primary,
          onPressed: _clockIn,
        );
      case _AttendanceState.working:
        final pendingIn =
            _today != null && Attendance.isPendingLocalSyncId(_today!.id);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (pendingIn) ...[
              const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(6)),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: AppColors.divider,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Confirming clock in with server…',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
            ],
            _bigButton(
              label: 'Clock Out',
              icon: Icons.logout,
              color: AppColors.teal,
              onPressed: pendingIn ? null : _clockOut,
            ),
          ],
        );
      case _AttendanceState.done:
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 22),
                  SizedBox(width: 8),
                  Text(
                    "You're all done for today!",
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Total worked: ${_fmtDuration(_elapsed())}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _attendanceHistoryEntryCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            pushAppPage(context, const EmployeeAttendanceLogScreen()),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppGradients.brandPanel,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.format_list_bulleted_rounded,
                    color: AppColors.onBrand,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Attendance history',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View past clock-ins and clock-outs. Filter by date and status.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.95,
                          ),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary.withValues(alpha: 0.85),
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bigButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 58,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

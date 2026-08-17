import 'dart:async';
import '../../utils/app_route.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/app_theme.dart';
import '../../models/attendance.dart';
import '../../models/leave_request.dart';
import '../../models/work_site.dart';
import '../../providers/auth_provider.dart';
import '../../services/app_realtime.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_time.dart';
import '../../utils/async_load_guard.dart';
import '../../utils/error_messages.dart';
import '../../utils/geofence.dart';
import '../../widgets/app_confirm_dialog.dart';
import 'attendance_history_screen.dart';
import 'employee_attendance_log_screen.dart';
import 'employee_shell.dart';

const Color _kNavy = Color(0xFF14213D);
const Color _kMuted = Color(0xFF9AA1AD);
const Color _kCardBorder = Color(0xFFE4E6EB);
const Color _kClockSecondary = Color(0xFFC7CCD6);
const Color _kEyebrow = Color(0xFF8B93A3);
const Color _kCoral = Color(0xFFF0997B);
const Color _kStatusGreen = Color(0xFF5DCAA5);
const Color _kDoneBannerBg = Color(0xFFE1F5EE);
const Color _kDoneBannerBorder = Color(0xFFC3ECDD);
const Color _kDoneHeadline = Color(0xFF0F6E56);
const Color _kDoneSubtitle = Color(0xFF3E8B71);

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
  WorkSite? _workSite;
  String? _rangeHint;
  bool _rangeChecking = false;
  bool _clockBusy = false;
  bool _loading = true;
  Timer? _ticker;
  Timer? _realtimeDebounce;
  RealtimeSubscription? _channel;
  RealtimeSubscription? _leaveChannel;
  final _loadGuard = AsyncLoadGuard();
  bool _tabActive = true;
  late final ValueNotifier<DateTime> _now = ValueNotifier<DateTime>(
    AppTime.malaysiaNow(),
  );

  static const int _clockTabIndex = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyTabVisibility(EmployeeTabScope.isActive(context, _clockTabIndex));
      _load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = EmployeeTabScope.isActive(context, _clockTabIndex);
    if (active != _tabActive) {
      _applyTabVisibility(active);
    }
  }

  @override
  void dispose() {
    _loadGuard.invalidate();
    _ticker?.cancel();
    _realtimeDebounce?.cancel();
    AppRealtime.disposeChannel(_channel);
    AppRealtime.disposeChannel(_leaveChannel);
    _channel = null;
    _leaveChannel = null;
    _now.dispose();
    super.dispose();
  }

  void _applyTabVisibility(bool active) {
    _tabActive = active;
    if (active) {
      if (_channel == null) _attachRealtime();
      _now.value = AppTime.malaysiaNow();
      _syncTicker();
    } else {
      _ticker?.cancel();
      _ticker = null;
      _realtimeDebounce?.cancel();
      AppRealtime.disposeChannel(_channel);
      AppRealtime.disposeChannel(_leaveChannel);
      _channel = null;
      _leaveChannel = null;
    }
  }

  /// Live clock while the Clock tab is visible (1s) so seconds stay accurate.
  void _syncTicker() {
    _ticker?.cancel();
    _ticker = null;
    if (!_tabActive || !mounted) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _tabActive) _now.value = AppTime.malaysiaNow();
    });
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
      onReload: () {
        _realtimeDebounce?.cancel();
        _realtimeDebounce = Timer(const Duration(milliseconds: 400), () {
          if (mounted) _load(showSpinner: false);
        });
      },
    );
    _leaveChannel = AppRealtime.subscribeMyLeaves(
      userId: uid,
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
        SupabaseService.getWorkSite(),
      ]);
      if (!mounted || !_loadGuard.isCurrent(gen)) return;
      setState(() {
        final fetched = results[0] as Attendance?;
        final leave = results[1] as LeaveRequest?;
        _workSite = results[2] as WorkSite?;

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
      // One light GPS sample for range hint — never blocks clock UI.
      if (_workSite != null && _workSite!.isActive) {
        unawaited(_refreshRangeHint());
      }
    } catch (e) {
      if (!mounted || !_loadGuard.isCurrent(gen)) return;
      setState(() => _loading = false);
      _showError('Failed to load attendance: $e');
    }
  }

  Future<void> _refreshRangeHint() async {
    final site = _workSite;
    if (site == null || !site.isActive) return;
    if (_rangeChecking) return;
    _rangeChecking = true;
    try {
      final raw = await _getLocationWithTimeout(const Duration(seconds: 4));
      if (!mounted) return;
      if (raw == null) {
        setState(() => _rangeHint = 'Location needed to clock in here');
        return;
      }
      final parsed = Geofence.parseLatLng(raw);
      if (parsed == null) {
        setState(() => _rangeHint = 'Allow location access to clock in');
        return;
      }
      final metres = Geofence.distanceMeters(
        lat1: site.latitude,
        lng1: site.longitude,
        lat2: parsed.lat,
        lng2: parsed.lng,
      );
      final inside = metres <= site.radiusMeters;
      setState(() {
        _rangeHint = inside
            ? 'In range · ${metres.round()} m from ${site.name}'
            : '${metres.round()} m away · must be within ${site.radiusMeters} m';
      });
    } finally {
      _rangeChecking = false;
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
    if (_state != _AttendanceState.idle || _clockBusy) return;
    final ok = await showAppConfirmDialog(
      context: context,
      title: 'Clock in?',
      message: 'Start your workday now?',
      cancelLabel: 'Not now',
      confirmLabel: 'Clock in',
      emphasis: AppConfirmEmphasis.confirm,
    );
    if (ok != true) return;
    if (!mounted) return;

    final uid = context.read<AuthProvider>().user!.id;
    final site = _workSite ?? await SupabaseService.getWorkSite();
    final activeSite = (site != null && site.isActive) ? site : null;

    setState(() => _clockBusy = true);

    try {
      // When geofence is on: require GPS + distance check before any UI change.
      String? location;
      if (activeSite != null) {
        location = await _getLocationWithTimeout(const Duration(seconds: 6));
        if (!mounted) return;
        if (location == null) {
          _showError(
            'Location is required to clock in at ${activeSite.name}. '
            'Allow location access and try again.',
          );
          return;
        }
        final parsed = Geofence.parseLatLng(location);
        if (parsed == null) {
          _showError('Could not read your location. Try again.');
          return;
        }
        final metres = Geofence.distanceMeters(
          lat1: activeSite.latitude,
          lng1: activeSite.longitude,
          lat2: parsed.lat,
          lng2: parsed.lng,
        );
        if (metres > activeSite.radiusMeters) {
          _showError(
            'You are about ${metres.round()} m from ${activeSite.name}. '
            'Clock-in is only allowed within ${activeSite.radiusMeters} m.',
          );
          unawaited(_refreshRangeHint());
          return;
        }
      } else {
        location = await _getLocationWithTimeout(const Duration(seconds: 5));
      }

      if (activeSite == null) {
        // Fast path when geofence is off — keep optimistic UI.
        final nowUtc = DateTime.now().toUtc();
        final cal = AppTime.malaysiaNow();
        final optimistic = Attendance(
          id: '${Attendance.pendingLocalIdPrefix}${nowUtc.microsecondsSinceEpoch}',
          userId: uid,
          clockInTime: nowUtc,
          clockOutTime: null,
          date: DateTime(cal.year, cal.month, cal.day),
          status: 'in_progress',
          location: location,
        );
        setState(() => _today = optimistic);
        _now.value = AppTime.malaysiaNow();
        _syncTicker();
        _showSuccess('Clocked in at ${_fmtTime(nowUtc)}');
      }

      final record = await SupabaseService.clockIn(uid, location: location);
      if (!mounted) return;
      setState(() {
        _today = record;
        _rangeHint = null;
      });
      _now.value = AppTime.malaysiaNow();
      _syncTicker();
      if (activeSite != null && record.clockInTime != null) {
        _showSuccess('Clocked in at ${_fmtTime(record.clockInTime!)}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _today = null);
      _syncTicker();
      _showError(friendlyLeaveError(e));
      unawaited(_refreshRangeHint());
    } finally {
      if (mounted) setState(() => _clockBusy = false);
    }
  }

  Future<void> _clockOut() async {
    if (_state != _AttendanceState.working || _today == null) return;
    if (Attendance.isPendingLocalSyncId(_today!.id)) return;

    final elapsed = _elapsed();
    final ok = await showAppConfirmDialog(
      context: context,
      title: 'Clock out?',
      message:
          'End your workday now?\n\nWorked: ${_fmtDuration(elapsed)}\nThis cannot be undone.',
      cancelLabel: 'Stay clocked in',
      confirmLabel: 'Clock out',
      emphasis: AppConfirmEmphasis.confirm,
      confirmColor: AppColors.teal,
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

  String _firstName(String? fullName) {
    final t = (fullName ?? '').trim();
    if (t.isEmpty) return 'there';
    return t.split(RegExp(r'\s+')).first;
  }

  String _timeOfDayGreeting(DateTime local) {
    final h = local.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _officeName =>
      (_workSite?.name.trim().isNotEmpty == true) ? _workSite!.name.trim() : 'Office';

  String get _shiftLabel {
    // Company workday (MYT): 9:00–18:00.
    return '9:00 AM–6:00 PM';
  }

  bool get _locationVerified =>
      _rangeHint != null && _rangeHint!.startsWith('In range');

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEEE, d MMMM yyyy');
    final userName = context.select<AuthProvider, String?>(
      (a) => a.user?.name,
    );

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
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      children: [
                        ValueListenableBuilder<DateTime>(
                          valueListenable: _now,
                          builder: (context, now, _) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dateFmt.format(now),
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: _kNavy,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_timeOfDayGreeting(now)}, ${_firstName(userName)}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w400,
                                          color: _kMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _load(showSpinner: true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: _kMuted,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 0,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    textStyle: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Refresh'),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        RepaintBoundary(child: _clockCard()),
                        if (_workSite != null) ...[
                          const SizedBox(height: 12),
                          _locationShiftCard(),
                        ],
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

  Widget _locationShiftCard() {
    final verified = _locationVerified;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kCardBorder),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 18,
            color: verified ? _kNavy : _kMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$_officeName · expected shift $_shiftLabel',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: _kMuted,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: verified ? _kStatusGreen : _kCardBorder,
          ),
        ],
      ),
    );
  }

  Widget _clockCard() {
    final state = _state;
    final hasIn = _today?.clockInTime != null;
    final hasOut = _today?.clockOutTime != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: _kNavy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            'CURRENT TIME',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.08 * 12,
              color: _kEyebrow,
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<DateTime>(
            valueListenable: _now,
            builder: (context, now, _) {
              // [_now] is already [AppTime.malaysiaNow] — do not call toMalaysia again.
              final hm = DateFormat('h:mm').format(now);
              final sec = DateFormat('ss').format(now);
              final ap = DateFormat('a').format(now);
              const tabular = [FontFeature.tabularFigures()];
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    hm,
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      fontFeatures: tabular,
                      height: 1,
                    ),
                  ),
                  Text(
                    ':$sec',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w400,
                      color: _kClockSecondary,
                      fontFeatures: tabular,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ap,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      color: _kClockSecondary,
                      fontFeatures: tabular,
                      height: 1,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _statusPill(state),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _timeBlock(
                  'Clock in',
                  hasIn ? _fmtTime(_today!.clockInTime!) : '--:--',
                  Icons.login,
                  filled: hasIn,
                ),
              ),
              Container(
                width: 1,
                height: 42,
                color: AppColors.onBrand.withValues(alpha: 0.22),
              ),
              Expanded(
                child: _timeBlock(
                  'Clock out',
                  hasOut ? _fmtTime(_today!.clockOutTime!) : '--:--',
                  Icons.logout,
                  filled: hasOut,
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
          ] else if (state == _AttendanceState.working) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x265DCAA5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _kStatusGreen.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: _kStatusGreen,
                  ),
                  const SizedBox(width: 6),
                  ValueListenableBuilder<DateTime>(
                    valueListenable: _now,
                    builder: (context, now, _) {
                      return Text(
                        'Elapsed ${_fmtDuration(_elapsed(now.toUtc()))}',
                        style: const TextStyle(
                          color: _kStatusGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusPill(_AttendanceState state) {
    final (String label, Color accent) = switch (state) {
      _AttendanceState.blocked => (
        _todayApprovedLeave?.leaveTypeDisplay ?? 'Approved leave',
        AppColors.leave,
      ),
      _AttendanceState.idle => ('Not clocked in', _kCoral),
      _AttendanceState.working => ('Clocked in', _kStatusGreen),
      _AttendanceState.done => ('Clocked out', _kStatusGreen),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeBlock(
    String label,
    String time,
    IconData icon, {
    required bool filled,
  }) {
    final valueColor =
        filled ? Colors.white : Colors.white.withValues(alpha: 0.45);
    return Column(
      children: [
        Icon(
          icon,
          color: filled
              ? Colors.white.withValues(alpha: 0.72)
              : Colors.white.withValues(alpha: 0.40),
          size: 18,
        ),
        const SizedBox(height: 6),
        Text(
          time,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: valueColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.55),
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

    final steps = const ['Clock in', 'Working', 'Clock out'];
    // How many steps are fully complete (checkmark). Done = all 3.
    final completedCount = switch (state) {
      _AttendanceState.blocked => 0,
      _AttendanceState.idle => 0,
      _AttendanceState.working => 1,
      _AttendanceState.done => 3,
    };
    final currentIdx = state == _AttendanceState.done ? -1 : completedCount;

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final lineIdx = i ~/ 2;
          final lineActive = lineIdx < completedCount ||
              (state == _AttendanceState.done);
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 16),
              color: lineActive ? _kNavy : AppColors.divider,
            ),
          );
        }
        final idx = i ~/ 2;
        final isComplete = idx < completedCount;
        final isCurrent = idx == currentIdx;
        final isFilled = isComplete || isCurrent;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isFilled ? _kNavy : Colors.white,
                border: Border.all(
                  color: isFilled ? _kNavy : AppColors.divider,
                  width: 2,
                ),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: isComplete
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  : Text(
                      '${idx + 1}',
                      style: TextStyle(
                        color: isFilled ? Colors.white : AppColors.textHint,
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
                color: isFilled ? _kNavy : AppColors.textHint,
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
        final fenceOn = _workSite?.isActive == true;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (fenceOn) ...[
              _GeofenceHint(
                hint: _rangeHint,
                checking: _rangeChecking,
                onRefresh: _clockBusy ? null : _refreshRangeHint,
              ),
              const SizedBox(height: 12),
            ],
            _bigButton(
              label: _clockBusy ? 'Clocking in…' : 'Clock In',
              icon: Icons.login,
              color: _kNavy,
              onPressed: _clockBusy ? null : _clockIn,
            ),
            if (_workSite != null) ...[
              const SizedBox(height: 8),
              Text(
                'Your location is verified against $_officeName.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: _kMuted,
                ),
              ),
            ],
          ],
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
                  color: _kNavy,
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
              label: _clockBusy ? 'Clocking out…' : 'Clock out',
              icon: Icons.logout,
              color: _kNavy,
              onPressed: pendingIn || _clockBusy ? null : _clockOut,
            ),
            if (_workSite != null) ...[
              const SizedBox(height: 8),
              Text(
                'Your location is verified against $_officeName.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: _kMuted,
                ),
              ),
            ],
          ],
        );
      case _AttendanceState.done:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: _kDoneBannerBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kDoneBannerBorder),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: _kDoneHeadline,
                size: 28,
              ),
              const SizedBox(height: 8),
              const Text(
                "You're all done for today",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _kDoneHeadline,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total worked: ${_fmtDuration(_elapsed())}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kDoneSubtitle,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
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
        onTap: () => pushAppPage(context, const EmployeeAttendanceLogScreen()),
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

class _GeofenceHint extends StatelessWidget {
  const _GeofenceHint({
    required this.hint,
    required this.checking,
    required this.onRefresh,
  });

  final String? hint;
  final bool checking;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final text = checking
        ? 'Checking distance to office…'
        : (hint ?? 'Office location check is on. Stay in range to clock in.');
    final inRange = hint != null && hint!.startsWith('In range');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onRefresh,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: (inRange ? AppColors.success : AppColors.sky).withValues(
              alpha: 0.08,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (inRange ? AppColors.success : AppColors.sky).withValues(
                alpha: 0.28,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                inRange ? Icons.verified_rounded : Icons.location_on_outlined,
                size: 18,
                color: inRange ? AppColors.success : AppColors.sky,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: AppColors.textPrimary.withValues(alpha: 0.88),
                  ),
                ),
              ),
              if (onRefresh != null)
                Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

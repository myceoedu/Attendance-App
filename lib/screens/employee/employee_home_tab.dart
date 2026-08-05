import 'dart:async';
import '../../utils/app_route.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/attendance.dart';
import '../../models/leave_request.dart';
import '../../providers/auth_provider.dart';
import '../../services/announcement_badge_service.dart';
import '../../services/app_realtime.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_time.dart';
import '../../utils/async_load_guard.dart';
import '../../widgets/employee_quick_access_tile.dart';
import '../../widgets/notification_bell_button.dart';
import '../announcements_screen.dart';
import '../help_support_screen.dart';
import 'attendance_history_screen.dart';
import 'claims_screen.dart';
import 'employee_attendance_log_screen.dart';
import 'employee_payroll_history_screen.dart';
import 'employee_shell.dart';
import 'leave_tab.dart';

/// Employee **Dashboard**.
///
/// Greeting, today-at-a-glance, and HRMS-style quick-access shortcuts.
/// Clock in/out lives in the center Clock tab on the bottom bar.
class EmployeeHomeTab extends StatefulWidget {
  const EmployeeHomeTab({super.key});

  @override
  State<EmployeeHomeTab> createState() => _EmployeeHomeTabState();
}

class _EmployeeHomeTabState extends State<EmployeeHomeTab> {
  Attendance? _today;
  // Narrow: only today's approved leave (replaces the 400-row list).
  LeaveRequest? _todayLeave;
  // Count of user's pending leave requests (HEAD query, zero data transfer).
  int _pendingLeaveCount = 0;
  bool _loading = true;
  int _announcementUnread = 0;

  static final _dateFmt = DateFormat('EEEE, d MMMM yyyy');

  Timer? _realtimeDebounce;
  Timer? _announcementBadgeDebounce;
  RealtimeChannel? _attendanceChannel;
  RealtimeChannel? _leaveChannel;
  RealtimeChannel? _announcementsChannel;
  final _loadGuard = AsyncLoadGuard();

  late final ValueNotifier<DateTime> _clockNow = ValueNotifier<DateTime>(
    AppTime.malaysiaNow(),
  );
  Timer? _clockTicker;
  bool _tabActive = true;
  static const int _homeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyTabVisibility(EmployeeTabScope.isActive(context, _homeTabIndex));
      _load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = EmployeeTabScope.isActive(context, _homeTabIndex);
    if (active != _tabActive) {
      _applyTabVisibility(active);
    }
  }

  void _applyTabVisibility(bool active) {
    _tabActive = active;
    if (active) {
      _startClockTicker();
      if (_attendanceChannel == null) {
        _attachRealtime();
        _attachAnnouncementsRealtime();
      }
      _clockNow.value = AppTime.malaysiaNow();
    } else {
      _clockTicker?.cancel();
      _clockTicker = null;
      _realtimeDebounce?.cancel();
      _announcementBadgeDebounce?.cancel();
      AppRealtime.disposeChannel(_attendanceChannel);
      AppRealtime.disposeChannel(_leaveChannel);
      AppRealtime.disposeChannel(_announcementsChannel);
      _attendanceChannel = null;
      _leaveChannel = null;
      _announcementsChannel = null;
    }
  }

  void _startClockTicker() {
    _clockTicker?.cancel();
    _clockTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _tabActive) _clockNow.value = AppTime.malaysiaNow();
    });
  }

  @override
  void dispose() {
    _loadGuard.invalidate();
    _clockTicker?.cancel();
    _clockNow.dispose();
    _realtimeDebounce?.cancel();
    _announcementBadgeDebounce?.cancel();
    AppRealtime.disposeChannel(_attendanceChannel);
    AppRealtime.disposeChannel(_leaveChannel);
    AppRealtime.disposeChannel(_announcementsChannel);
    super.dispose();
  }

  // ──────────────────────────────────────────────
  // Data
  // ──────────────────────────────────────────────

  void _attachRealtime() {
    final uid = context.read<AuthProvider>().user?.id;
    if (uid == null) return;
    _attendanceChannel = AppRealtime.subscribeMyAttendance(
      userId: uid,
      channelSuffix: 'dashboard',
      onReload: _scheduleReload,
    );
    _leaveChannel = AppRealtime.subscribeMyLeaves(
      userId: uid,
      channelSuffix: 'dashboard',
      onReload: _scheduleReload,
    );
  }

  void _attachAnnouncementsRealtime() {
    _announcementsChannel = AppRealtime.subscribeCompanyAnnouncements(
      channelSuffix: 'employee_home_badge',
      onReload: () {
        _announcementBadgeDebounce?.cancel();
        _announcementBadgeDebounce = Timer(
          const Duration(milliseconds: 400),
          () {
            if (mounted) {
              unawaited(_refreshAnnouncementBadge());
            }
          },
        );
      },
    );
  }

  Future<void> _refreshAnnouncementBadge() async {
    final uid = context.read<AuthProvider>().user?.id;
    if (uid == null) return;
    try {
      final n = await AnnouncementBadgeService.unreadCountForUser(uid);
      if (!mounted || n == _announcementUnread) return;
      setState(() => _announcementUnread = n);
    } catch (_) {
      if (!mounted || _announcementUnread == 0) return;
      setState(() => _announcementUnread = 0);
    }
  }

  void _scheduleReload() {
    if (!_tabActive) return;
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 550), () {
      if (mounted && _tabActive) _load(showSpinner: false);
    });
  }

  Future<void> _load({bool showSpinner = true}) async {
    final gen = _loadGuard.begin();
    if (showSpinner && mounted) setState(() => _loading = true);
    try {
      final uid = context.read<AuthProvider>().user?.id;
      if (uid == null) {
        if (mounted && _loadGuard.isCurrent(gen)) {
          setState(() => _loading = false);
        }
        return;
      }
      final today = AppTime.malaysiaNow();
      // Four parallel, narrow queries — replaces a single 400-row leave fetch.
      final results = await Future.wait<Object?>([
        SupabaseService.getTodayAttendance(uid),
        SupabaseService.getApprovedLeaveForToday(uid, today),
        SupabaseService.getPendingLeaveCountForUser(uid),
        AnnouncementBadgeService.unreadCountForUser(uid),
      ]);
      if (!mounted || !_loadGuard.isCurrent(gen)) return;
      final nextToday = results[0] as Attendance?;
      final nextLeave = results[1] as LeaveRequest?;
      final nextPending = results[2] as int;
      final nextUnread = results[3] as int;
      final unchanged = !showSpinner &&
          !_loading &&
          _sameAttendance(_today, nextToday) &&
          _todayLeave?.id == nextLeave?.id &&
          _pendingLeaveCount == nextPending &&
          _announcementUnread == nextUnread;
      if (unchanged) {
        _clockNow.value = AppTime.malaysiaNow();
        return;
      }
      setState(() {
        _today = nextToday;
        _todayLeave = nextLeave;
        _pendingLeaveCount = nextPending;
        _announcementUnread = nextUnread;
        _loading = false;
      });
      _clockNow.value = AppTime.malaysiaNow();
    } catch (_) {
      if (!mounted || !_loadGuard.isCurrent(gen)) return;
      setState(() => _loading = false);
    }
  }

  bool _sameAttendance(Attendance? a, Attendance? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    return a.id == b.id &&
        a.status == b.status &&
        a.clockInTime == b.clockInTime &&
        a.clockOutTime == b.clockOutTime;
  }

  String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  double _horizontalPadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 600) return 28;
    if (w >= 400) return AppLayout.screenPaddingH;
    return 16;
  }

  String _shiftLabelForNow(DateTime now) {
    final h = now.hour;
    if (h >= 6 && h < 14) return 'Day shift';
    if (h >= 14 && h < 22) return 'Second shift';
    return 'Night shift';
  }

  // ──────────────────────────────────────────────
  // UI
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthProvider, AppUser?>((a) => a.user);
    if (user == null) return const SizedBox.shrink();

    final hPad = _horizontalPadding(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final displayName = user.name.isNotEmpty ? user.name : user.email;

    if (_loading) {
      return const SizedBox.expand(
        child: ColoredBox(
          color: AppColors.surface,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return SizedBox.expand(
      child: ColoredBox(
        color: AppColors.surface,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _load(showSpinner: false),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            cacheExtent: 520,
            padding: EdgeInsets.only(bottom: bottomInset + 32),
            children: [
              // Hero header + attendance card rebuild every minute (clock).
              RepaintBoundary(
                child: ValueListenableBuilder<DateTime>(
                  valueListenable: _clockNow,
                  builder: (context, now, _) =>
                      _heroHeader(displayName, _dateFmt.format(now), now),
                ),
              ),
              // Quick access rebuilds ONLY on data change (_load / realtime).
              RepaintBoundary(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 8),
                  child: _quickAccessSection(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero header + embedded attendance card ──────────────────────────────

  Widget _heroHeader(String name, String dateText, DateTime now) {
    final leave = _todayLeave;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppChrome.onBrand,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F2255), Color(0xFF1A3A8F), Color(0xFF1A56DB)],
            stops: [0.0, 0.48, 1.0],
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Greeting row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Teal avatar badge
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2DD4BF), Color(0xFF0D9488)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x330D9488),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _greeting(now),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.72),
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.55,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.62),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  dateText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Material(
                      type: MaterialType.transparency,
                      child: NotificationBellButton(
                        iconColor: AppColors.onBrand,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Attendance card embedded in the header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: _attendanceEmbeddedCard(now, leave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Attendance card (inside header) ────────────────────────────────────

  Widget _attendanceEmbeddedCard(DateTime now, LeaveRequest? leave) {
    final t = _today;
    final onLeave = leave != null;
    final idle = !onLeave && t == null;
    final working =
        !onLeave &&
        t != null &&
        t.clockOutTime == null &&
        t.status != 'completed';
    final done =
        !onLeave &&
        t != null &&
        (t.clockOutTime != null || t.status == 'completed');

    final Color statusColor = onLeave
        ? AppColors.leave
        : done
        ? AppColors.success
        : working
        ? AppColors.open
        : AppColors.textHint;

    final Color statusBg = onLeave
        ? AppColors.leaveLight
        : done
        ? AppColors.successLight
        : working
        ? AppColors.openLight
        : AppColors.surface;

    final IconData statusIcon = onLeave
        ? Icons.beach_access_rounded
        : done
        ? Icons.check_circle_rounded
        : working
        ? Icons.radio_button_checked
        : Icons.circle_outlined;

    final String statusLabel = done
        ? 'Complete'
        : onLeave
        ? 'On leave'
        : working
        ? 'Working'
        : 'Clock in';

    final String statusMessage = onLeave
        ? 'On approved leave today'
        : idle
        ? 'Please clock in'
        : working
        ? 'You are clocked in'
        : 'All done for today';

    final timeFmt = DateFormat('h:mm a');
    final hasIn = t?.clockInTime != null;
    final hasOut = t?.clockOutTime != null;
    final inDisplay = hasIn
        ? timeFmt.format(AppTime.toMalaysia(t!.clockInTime!))
        : '—';
    final outDisplay = hasOut
        ? timeFmt.format(AppTime.toMalaysia(t!.clockOutTime!))
        : hasIn
        ? 'In progress'
        : '—';

    bool secondary(String v) => v == '—' || v.toLowerCase() == 'in progress';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status-colored top accent strip
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: onLeave
                    ? [AppColors.leave, AppColors.leave.withValues(alpha: 0.55)]
                    : done
                    ? [const Color(0xFF059669), const Color(0xFF34D399)]
                    : working
                    ? [AppColors.primaryDark, AppColors.primary]
                    : [AppColors.border, AppColors.surface],
              ),
            ),
          ),
          // ── Status row ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Tappable status pill → Clock tab
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => EmployeeTabScope.goToTabOf(context, 1),
                    borderRadius: BorderRadius.circular(12),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 17),
                          const SizedBox(width: 5),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color.lerp(
                                statusColor,
                                AppColors.textPrimary,
                                0.18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (!onLeave) ...[
                        const SizedBox(height: 4),
                        _shiftChip(_shiftLabelForNow(now)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.divider.withValues(alpha: 0.8),
          ),
          // ── Clock times row ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _timeColumn(
                    icon: Icons.login_rounded,
                    iconColor: const Color(0xFF059669),
                    label: 'Clock in',
                    value: inDisplay,
                    isSecondary: secondary(inDisplay),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: AppColors.border.withValues(alpha: 0.7),
                ),
                Expanded(
                  child: _timeColumn(
                    icon: Icons.logout_rounded,
                    iconColor: AppColors.primaryDark.withValues(alpha: 0.85),
                    label: 'Clock out',
                    value: outDisplay,
                    isSecondary: secondary(outDisplay),
                  ),
                ),
                // View log button
                const SizedBox(width: 10),
                Material(
                  color: Colors.transparent,
                  child: Tooltip(
                    message: 'Open attendance log',
                    child: InkWell(
                      onTap: () => pushAppPage(
                        context,
                        const EmployeeAttendanceLogScreen(),
                      ),
                      borderRadius: BorderRadius.circular(13),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF0F2255), Color(0xFF1A56DB)],
                          ),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              color: Colors.white.withValues(alpha: 0.96),
                              size: 20,
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Log',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            const Text(
                              'Entries',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeColumn({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isSecondary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary.withValues(alpha: 0.88),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: isSecondary
              ? TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textHint,
                )
              : const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.8,
                  height: 1.1,
                ),
        ),
      ],
    );
  }

  Widget _shiftChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 12,
            color: AppColors.primaryDark.withValues(alpha: 0.82),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  // ── Slim at-a-glance stat strip ─────────────────────────────────────────

  Widget _statStrip() {
    final t = _today;
    final leave = _todayLeave;

    final bool working =
        leave == null &&
        t != null &&
        t.clockOutTime == null &&
        t.status != 'completed';
    final bool done =
        leave == null &&
        t != null &&
        (t.clockOutTime != null || t.status == 'completed');

    final Color attColor = leave != null
        ? AppColors.leave
        : done
        ? AppColors.success
        : working
        ? AppColors.open
        : AppColors.textHint;
    final IconData attIcon = leave != null
        ? Icons.beach_access_rounded
        : done
        ? Icons.check_circle_rounded
        : working
        ? Icons.radio_button_checked
        : Icons.circle_outlined;
    final String attLabel = leave != null
        ? 'On leave'
        : done
        ? 'Complete'
        : working
        ? 'Clocked in'
        : 'Not clocked';

    Widget stat({
      required IconData icon,
      required Color color,
      required String value,
      required String caption,
    }) {
      return Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textHint,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.65)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          stat(
            icon: attIcon,
            color: attColor,
            value: attLabel,
            caption: 'Today',
          ),
          Container(
            width: 1,
            height: 28,
            color: AppColors.border.withValues(alpha: 0.7),
          ),
          stat(
            icon: Icons.event_note_rounded,
            color: _pendingLeaveCount > 0
                ? AppColors.warning
                : AppColors.success,
            value: _pendingLeaveCount == 0
                ? 'None'
                : '$_pendingLeaveCount pending',
            caption: 'Leave',
          ),
          Container(
            width: 1,
            height: 28,
            color: AppColors.border.withValues(alpha: 0.7),
          ),
          stat(
            icon: Icons.campaign_rounded,
            color: _announcementUnread > 0
                ? AppColors.accent
                : AppColors.textHint,
            value: _announcementUnread == 0
                ? 'All read'
                : '$_announcementUnread new',
            caption: 'Notices',
          ),
        ],
      ),
    );
  }

  // ── Quick access section ─────────────────────────────────────────────────

  Widget _quickAccessSection(BuildContext context) {
    const gap = 10.0;
    final tiles = <Widget>[
      EmployeeQuickAccessTile(
        label: 'Leave',
        subLabel: 'Balance & history',
        semanticAction:
            'Opens leave — annual balance, sick leave, and emergency leave.',
        icon: Icons.event_available_rounded,
        accentColor: AppColors.teal,
        onTap: () => pushAppPage(context, const LeaveTab()),
      ),
      EmployeeQuickAccessTile(
        label: 'Claim',
        subLabel: 'Expenses',
        semanticAction: 'Opens expense claims and receipt uploads.',
        icon: Icons.receipt_long_rounded,
        accentColor: AppColors.orange,
        onTap: () => pushAppPage(context, const ClaimsScreen()),
      ),
      EmployeeQuickAccessTile(
        label: 'Payroll',
        subLabel: 'Payslips',
        semanticAction: 'Opens your payslip history and PDF downloads.',
        icon: Icons.payments_rounded,
        accentColor: AppColors.violet,
        onTap: () =>
            pushAppPage(context, const EmployeePayrollHistoryScreen()),
      ),
      EmployeeQuickAccessTile(
        label: 'Notices',
        subLabel: 'Announcements',
        semanticAction: 'Company-wide notices posted by administrators.',
        icon: Icons.campaign_rounded,
        accentColor: AppColors.accent,
        badgeCount: _announcementUnread > 0 ? _announcementUnread : null,
        onTap: () async {
          await pushAppPage(context, const AnnouncementsScreen());
          if (mounted) await _refreshAnnouncementBadge();
        },
      ),
      EmployeeQuickAccessTile(
        label: 'Calendar',
        subLabel: 'Attendance',
        semanticAction: 'Opens your attendance calendar.',
        icon: Icons.calendar_month_rounded,
        accentColor: AppColors.indigo,
        onTap: () => pushAppPage(context, const AttendanceHistoryScreen()),
      ),
      EmployeeQuickAccessTile(
        label: 'Help',
        subLabel: 'HR & IT support',
        semanticAction:
            'Opens help topics, contact HR or IT, and copy diagnostics.',
        icon: Icons.support_agent_rounded,
        accentColor: AppColors.sky,
        onTap: () => pushAppPage(context, const HelpSupportScreen()),
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 720 ? 4 : 3;
        final tileH = (c.maxWidth - gap * (cols - 1)) / cols / 1.02;
        final rows = <Widget>[];
        for (var i = 0; i < tiles.length; i += cols) {
          final slice = tiles.sublist(
            i,
            i + cols > tiles.length ? tiles.length : i + cols,
          );
          rows.add(
            SizedBox(
              height: tileH,
              child: Row(
                children: [
                  for (var j = 0; j < slice.length; j++) ...[
                    if (j > 0) const SizedBox(width: gap),
                    Expanded(child: slice[j]),
                  ],
                  // Pad incomplete last row so tile widths stay even.
                  for (var j = slice.length; j < cols; j++) ...[
                    const SizedBox(width: gap),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          );
          if (i + cols < tiles.length) {
            rows.add(const SizedBox(height: gap));
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statStrip(),
            const SizedBox(height: 16),
            const Row(
              children: [
                Text(
                  'Quick access',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),
                Spacer(),
                Text(
                  '6 tools',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...rows,
          ],
        );
      },
    );
  }
}

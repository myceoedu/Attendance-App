import 'dart:async';

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

  late final ValueNotifier<DateTime> _clockNow = ValueNotifier<DateTime>(
    AppTime.malaysiaNow(),
  );
  late Timer _clockTicker;

  @override
  void initState() {
    super.initState();
    _clockTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _clockNow.value = AppTime.malaysiaNow();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _attachRealtime();
        _attachAnnouncementsRealtime();
      });
    });
  }

  @override
  void dispose() {
    _clockTicker.cancel();
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
      if (!mounted) return;
      setState(() => _announcementUnread = n);
    } catch (_) {
      if (!mounted) return;
      setState(() => _announcementUnread = 0);
    }
  }

  void _scheduleReload() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _load(showSpinner: false);
    });
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner && mounted) setState(() => _loading = true);
    try {
      final uid = context.read<AuthProvider>().user?.id;
      if (uid == null) {
        if (mounted) setState(() => _loading = false);
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
      if (!mounted) return;
      setState(() {
        _today = results[0] as Attendance?;
        _todayLeave = results[1] as LeaveRequest?;
        _pendingLeaveCount = results[2] as int;
        _announcementUnread = results[3] as int;
        _loading = false;
      });
      _clockNow.value = AppTime.malaysiaNow();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
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
      return SizedBox.expand(
        child: ColoredBox(
          color: AppColors.surface,
          child: const Center(child: CircularProgressIndicator()),
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
            padding: EdgeInsets.only(bottom: bottomInset + 32),
            children: [
              // Hero header + attendance card rebuild every minute (clock).
              ValueListenableBuilder<DateTime>(
                valueListenable: _clockNow,
                builder: (context, now, _) => _heroHeader(
                  displayName,
                  _dateFmt.format(now),
                  now,
                ),
              ),
              // Quick access rebuilds ONLY on data change (_load / realtime).
              // It is intentionally outside the ValueListenableBuilder so the
              // stat strip + tile grid are NOT repainted every clock tick.
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 8),
                child: _quickAccessSection(context),
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
            colors: [
              Color(0xFF0F2255),
              Color(0xFF1A3A8F),
              Color(0xFF1A56DB),
            ],
            stops: [0.0, 0.48, 1.0],
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.28),
              blurRadius: 28,
              offset: const Offset(0, 10),
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
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D9488).withValues(
                              alpha: 0.4,
                            ),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.1),
            blurRadius: 12,
            spreadRadius: -4,
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
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const EmployeeAttendanceLogScreen(),
                          ),
                        );
                      },
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
                            colors: [
                              Color(0xFF0F2255),
                              Color(0xFF1A56DB),
                            ],
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
            color: _pendingLeaveCount > 0 ? AppColors.warning : AppColors.success,
            value: _pendingLeaveCount == 0 ? 'None' : '$_pendingLeaveCount pending',
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
            value: _announcementUnread == 0 ? 'All read' : '$_announcementUnread new',
            caption: 'Notices',
          ),
        ],
      ),
    );
  }

  // ── Quick access section ─────────────────────────────────────────────────

  Widget _quickAccessSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        const gap = 10.0;
        // 3 columns on all phones → 6 tiles in 2 rows → fits on one screen
        final crossAxisCount = w >= 720 ? 4 : 3;
        // Slightly taller than wide to fit icon + label comfortably
        const aspect = 1.02;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Slim stat strip (uses stored state — no 'now' needed)
            _statStrip(),
            const SizedBox(height: 16),
            // Section heading — compact single line
            Row(
              children: [
                const Text(
                  'Quick access',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),
                const Spacer(),
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
            GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              childAspectRatio: aspect,
              children: [
                EmployeeQuickAccessTile(
                  label: 'Leave',
                  subLabel: 'Balance & history',
                  semanticAction:
                      'Opens leave — annual balance, sick leave, and emergency leave.',
                  icon: Icons.event_available_rounded,
                  accentColor: AppColors.teal,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LeaveTab(),
                    ),
                  ),
                ),
                EmployeeQuickAccessTile(
                  label: 'Claim',
                  subLabel: 'Expenses',
                  semanticAction: 'Opens expense claims and receipt uploads.',
                  icon: Icons.receipt_long_rounded,
                  accentColor: AppColors.orange,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ClaimsScreen(),
                    ),
                  ),
                ),
                EmployeeQuickAccessTile(
                  label: 'Payroll',
                  subLabel: 'Payslips',
                  semanticAction:
                      'Opens your payslip history and PDF downloads.',
                  icon: Icons.payments_rounded,
                  accentColor: AppColors.violet,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const EmployeePayrollHistoryScreen(),
                    ),
                  ),
                ),
                EmployeeQuickAccessTile(
                  label: 'Notices',
                  subLabel: 'Announcements',
                  semanticAction:
                      'Company-wide notices posted by administrators.',
                  icon: Icons.campaign_rounded,
                  accentColor: AppColors.accent,
                  badgeCount:
                      _announcementUnread > 0 ? _announcementUnread : null,
                  onTap: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const AnnouncementsScreen(),
                      ),
                    );
                    if (mounted) await _refreshAnnouncementBadge();
                  },
                ),
                EmployeeQuickAccessTile(
                  label: 'Calendar',
                  subLabel: 'Attendance',
                  semanticAction: 'Opens your attendance calendar.',
                  icon: Icons.calendar_month_rounded,
                  accentColor: AppColors.indigo,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AttendanceHistoryScreen(),
                    ),
                  ),
                ),
                EmployeeQuickAccessTile(
                  label: 'Help',
                  subLabel: 'HR & IT support',
                  semanticAction:
                      'Opens help topics, contact HR or IT, and copy diagnostics.',
                  icon: Icons.support_agent_rounded,
                  accentColor: AppColors.sky,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HelpSupportScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

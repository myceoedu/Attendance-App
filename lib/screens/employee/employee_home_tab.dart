import 'dart:async';

import 'package:flutter/foundation.dart';
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
import '../../utils/leave_catalog.dart';
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
  List<LeaveRequest> _leaves = [];
  bool _loading = true;
  int _announcementUnread = 0;

  Timer? _realtimeDebounce;
  Timer? _announcementBadgeDebounce;
  RealtimeChannel? _attendanceChannel;
  RealtimeChannel? _leaveChannel;
  RealtimeChannel? _announcementsChannel;

  late final ValueNotifier<DateTime> _clockNow =
      ValueNotifier<DateTime>(AppTime.malaysiaNow());
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
        _announcementBadgeDebounce = Timer(const Duration(milliseconds: 400), () {
          if (mounted) {
            unawaited(_refreshAnnouncementBadge());
          }
        });
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
      final results = await Future.wait<Object?>([
        SupabaseService.getTodayAttendance(uid),
        SupabaseService.getMyLeaveRequests(uid),
        AnnouncementBadgeService.unreadCountForUser(uid),
      ]);
      if (!mounted) return;
      setState(() {
        _today = results[0] as Attendance?;
        _leaves = results[1] as List<LeaveRequest>;
        _announcementUnread = results[2] as int;
        _loading = false;
      });
      _clockNow.value = AppTime.malaysiaNow();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  LeaveRequest? _todayApprovedLeaveAt(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    for (final leave in _leaves) {
      if (leave.status.toLowerCase() != 'approved') continue;
      if (!LeaveCatalog.blocksFullDayClockIn(leave.leaveType)) continue;
      final start = DateTime(
        leave.startDate.year,
        leave.startDate.month,
        leave.startDate.day,
      );
      final end = DateTime(
        leave.endDate.year,
        leave.endDate.month,
        leave.endDate.day,
      );
      if (!today.isBefore(start) && !today.isAfter(end)) {
        return leave;
      }
    }
    return null;
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

  // ──────────────────────────────────────────────
  // UI
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthProvider, AppUser?>((a) => a.user);
    if (user == null) return const SizedBox.shrink();

    final dateFmt = DateFormat('EEEE, d MMMM yyyy');

    if (kDebugMode) {
      debugPrint(
        'EmployeeHomeTab build: loading=$_loading name=${user.name.isNotEmpty ? user.name : user.email}',
      );
    }

    // No nested [Scaffold] — only [EmployeeShell] is a scaffold on this route.
    // [ListView] + [RefreshIndicator] avoids sliver/viewport quirks on some Android
    // emulators that produced a blank or solid-color body while logs showed builds.
    final hPad = _horizontalPadding(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

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
              ValueListenableBuilder<DateTime>(
                valueListenable: _clockNow,
                builder: (context, now, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _heroHeader(
                        user.name.isNotEmpty ? user.name : user.email,
                        dateFmt.format(now),
                        now,
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 0),
                        child: _attendanceSnapshotCard(context, now),
                      ),
                    ],
                  );
                },
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 8),
                child: _quickAccessSection(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroHeader(String name, String dateText, DateTime now) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppChrome.onBrand,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppColors.brandHeaderShadow,
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: -4,
            ),
          ],
        ),
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppGradients.brandHeader,
                    border: Border(
                      bottom: BorderSide(color: AppColors.brandHeaderBorder),
                    ),
                  ),
                ),
              ),
              // Light orbs — draws once per frame, no images / blur filters.
              Positioned(
                right: -36,
                top: -24,
                child: IgnorePointer(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -28,
                top: 56,
                child: IgnorePointer(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppLayout.screenPaddingH,
                    16,
                    AppLayout.screenPaddingH,
                    24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: AppGradients.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.brandAvatarRing,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.22),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                              style: AppTypography.employeeHeroAvatarInitial(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _greeting(now),
                                  style: AppTypography.employeeHeroGreeting(
                                    AppColors.onBrandSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.employeeHeroName(
                                    AppColors.onBrand,
                                  ),
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: AppColors.onBrandFaint,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dateText,
                              style: AppTypography.employeeHeroDate(
                                AppColors.onBrandMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Clock-in / clock-out detail; [leadWithDivider] false when nested in snapshot card.
  Widget _attendanceTimesBody(
    BuildContext context, {
    bool leadWithDivider = true,
  }) {
    final t = _today;
    final timeFmt = DateFormat('h:mm a');
    final w = MediaQuery.sizeOf(context).width;

    final hasIn = t?.clockInTime != null;
    final hasOut = t?.clockOutTime != null;

    final inDisplay =
        hasIn ? timeFmt.format(AppTime.toMalaysia(t!.clockInTime!)) : '—';
    final outDisplay = hasOut
        ? timeFmt.format(AppTime.toMalaysia(t!.clockOutTime!))
        : (hasIn ? 'In progress' : '—');

    bool isSecondaryValue(String v) =>
        v == '—' || v.toLowerCase() == 'in progress';

    Widget timeHalf({
      required IconData icon,
      required Color iconColor,
      required String label,
      required String value,
    }) {
      final secondary = isSecondaryValue(value);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.employeeTimeRowLabel(
                    AppColors.textSecondary.withValues(alpha: 0.88),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: secondary
                ? AppTypography.employeeTimeSecondary()
                : AppTypography.employeeTimeNumeric(w),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leadWithDivider) ...[
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.divider.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.access_time_filled_rounded,
                size: 16,
                color: AppColors.primaryDark.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "Today's times",
              style: AppTypography.employeeSectionHeading(
                AppColors.textPrimary,
              ).copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.22,
                height: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: timeHalf(
                    icon: Icons.login_rounded,
                    iconColor: const Color(0xFF047857),
                    label: 'Clock in',
                    value: inDisplay,
                  ),
                ),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                indent: 4,
                endIndent: 4,
                color: AppColors.border.withValues(alpha: 0.75),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: timeHalf(
                    icon: Icons.logout_rounded,
                    iconColor: AppColors.primaryDark.withValues(alpha: 0.92),
                    label: 'Clock out',
                    value: outDisplay,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Single card: status + log rail, then subtle band for today's times.
  Widget _attendanceSnapshotCard(BuildContext context, DateTime now) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppLayout.cardRadiusLg),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.65),
        ),
        boxShadow: AppElevation.cardOnSurface,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _attendanceStatusBody(now),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.divider.withValues(alpha: 0.65),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppLayout.cardRadiusLg - 1),
            ),
            child: ColoredBox(
              color: Color.lerp(
                AppColors.surface,
                AppColors.primaryLight,
                0.22,
              )!,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: _attendanceTimesBody(
                  context,
                  leadWithDivider: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAccessSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final gap = w >= 400 ? 14.0 : 8.0;
        final aspect = w >= 400 ? 0.92 : 0.88;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary,
                        AppColors.primaryDark,
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tools & links',
                        style: AppTypography.employeeCardOverline(
                          AppColors.textSecondary.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Self-service',
                        style: AppTypography.employeeSectionHeading(
                          AppColors.textPrimary,
                        ).copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.35,
                          height: 1.18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Leave, claims, payroll, notices & calendar',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.38,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.01,
                          color:
                              AppColors.textSecondary.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppLayout.cardRadiusLg),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.08),
                ),
                boxShadow: AppElevation.cardOnSurface,
              ),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                childAspectRatio: aspect,
                children: [
                  EmployeeQuickAccessTile(
                    label: 'Leave',
                    semanticAction:
                        'Opens leave — annual balance, sick leave, and emergency leave.',
                    icon: Icons.event_available_rounded,
                    accentColor: AppColors.teal,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LeaveTab(),
                        ),
                      );
                    },
                  ),
                  EmployeeQuickAccessTile(
                    label: 'Claim',
                    semanticAction:
                        'Opens expense claims and receipt uploads.',
                    icon: Icons.receipt_long_rounded,
                    accentColor: AppColors.orange,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ClaimsScreen(),
                        ),
                      );
                    },
                  ),
                  EmployeeQuickAccessTile(
                    label: 'Payroll',
                    semanticAction:
                        'Opens your payslip history and PDF downloads.',
                    icon: Icons.receipt_long_rounded,
                    accentColor: AppColors.violet,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const EmployeePayrollHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  EmployeeQuickAccessTile(
                    label: 'Announcements',
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
                    label: 'My calendar',
                    semanticAction: 'Opens your attendance calendar.',
                    icon: Icons.calendar_month_rounded,
                    accentColor: AppColors.indigo,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AttendanceHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  EmployeeQuickAccessTile(
                    label: 'Help & support',
                    semanticAction:
                        'Opens help topics, contact HR or IT, and copy diagnostics.',
                    icon: Icons.support_agent_rounded,
                    accentColor: AppColors.sky,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const HelpSupportScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _shiftLabelForNow(DateTime now) {
    final h = now.hour;
    if (h >= 6 && h < 14) return 'Day shift';
    if (h >= 14 && h < 22) return 'Second shift';
    return 'Night shift';
  }

  Widget _corporateShiftChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 15,
            color: AppColors.primaryDark.withValues(alpha: 0.88),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.employeeShiftSecondary(
              AppColors.textPrimary.withValues(alpha: 0.88),
            ).copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.02,
            ),
          ),
        ],
      ),
    );
  }

  /// Full-height right rail (layout pattern: primary block + icon / label stack).
  Widget _attendanceLogSideStrip() {
    return Tooltip(
      message: 'Open attendance log',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EmployeeAttendanceLogScreen(),
              ),
            );
          },
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primaryDark,
                  Color.lerp(AppColors.primaryDark, AppColors.indigo, 0.22)!,
                ],
              ),
            ),
            child: SizedBox(
              width: 62,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      color: Colors.white.withValues(alpha: 0.96),
                      size: 22,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Log',
                      textAlign: TextAlign.center,
                      style: AppTypography.employeeRailPrimaryLabel(),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Entries',
                      textAlign: TextAlign.center,
                      style: AppTypography.employeeRailSecondaryLabel(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _homeSmallActionCircle({
    required Color color,
    required VoidCallback onTap,
    required Widget child,
    double size = 52,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }

  Widget _homeClockDisc({
    required bool onLeave,
    required bool idle,
    required bool working,
    required bool done,
  }) {
    void goClock() => EmployeeTabScope.goToTabOf(context, 1);

    const double core = 50;
    if (onLeave) {
      return _homeSmallActionCircle(
        color: AppColors.leave,
        onTap: goClock,
        child: const Icon(Icons.block_rounded, color: Colors.white, size: 26),
      );
    }
    if (done) {
      return _homeSmallActionCircle(
        color: AppColors.success,
        onTap: goClock,
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
      );
    }

    final Color accent = idle ? const Color(0xFF22C55E) : AppColors.teal;
    return InkWell(
      onTap: goClock,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 76,
        height: 76,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.08),
              ),
            ),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.12),
              ),
            ),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.2),
              ),
            ),
            Container(
              width: core,
              height: core,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                idle ? 'Clock\nIn' : 'Clock\nOut',
                textAlign: TextAlign.center,
                style: AppTypography.employeePrimaryActionLabel().copyWith(
                      fontSize: 13,
                      height: 1.05,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attendanceStatusBody(DateTime now) {
    final t = _today;
    final leave = _todayApprovedLeaveAt(now);

    final onLeave = leave != null;
    final idle = !onLeave && t == null;
    final working = !onLeave &&
        t != null &&
        t.clockOutTime == null &&
        t.status != 'completed';
    final done = !onLeave &&
        t != null &&
        (t.clockOutTime != null || t.status == 'completed');

    final statusMessage = onLeave
        ? 'On approved leave today'
        : idle
            ? 'Please clock in'
            : working
                ? 'You are clocked in'
                : 'All done for today';

    final TextStyle statusStyle = onLeave || working || done
        ? AppTypography.employeeSnapshotHeadline(AppColors.textPrimary)
        : AppTypography.employeeSnapshotHeadline(
            AppColors.textSecondary.withValues(alpha: 0.92),
          ).copyWith(fontWeight: FontWeight.w600);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Color.lerp(Colors.white, AppColors.surface, 0.55)!,
                  ],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _homeClockDisc(
                    onLeave: onLeave,
                    idle: idle,
                    working: working,
                    done: done,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Attendance',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.employeeCardOverline(
                            AppColors.textHint.withValues(alpha: 0.95),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusMessage,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: statusStyle,
                        ),
                        if (!onLeave) ...[
                          const SizedBox(height: 8),
                          _corporateShiftChip(_shiftLabelForNow(now)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _attendanceLogSideStrip(),
        ],
      ),
    );
  }

}

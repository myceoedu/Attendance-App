import 'dart:async';
import '../../utils/app_route.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_theme.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../services/app_realtime.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_time.dart';
import '../../utils/async_load_guard.dart';
import '../../widgets/notification_bell_button.dart';
import 'admin_shell.dart';
import 'admin_announcements_screen.dart';
import 'admin_leave_hub_screen.dart';
import '../help_support_screen.dart';
import 'admin_work_site_screen.dart';
import 'claim_management_screen.dart';
import 'payroll/payroll_hub_screen.dart';

/// Admin **dashboard**: indigo/violet chrome, pulse grid, row-style shortcuts.
class AdminHomeTab extends StatefulWidget {
  const AdminHomeTab({super.key});

  @override
  State<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<AdminHomeTab> {
  bool _loading = true;
  int _employeeCount = 0;
  int _checkedIn = 0;
  int _completed = 0;
  int _pendingLeaveCount = 0;
  int _pendingClaimCount = 0;
  Timer? _realtimeDebounce;
  RealtimeChannel? _attendanceChannel;
  RealtimeChannel? _leaveChannel;
  RealtimeChannel? _claimChannel;
  final _loadGuard = AsyncLoadGuard();

  static final _dateFmt = DateFormat('EEEE, d MMMM yyyy');

  late final ValueNotifier<DateTime> _now = ValueNotifier<DateTime>(
    AppTime.malaysiaNow(),
  );
  Timer? _clockTicker;

  @override
  void initState() {
    super.initState();
    _clockTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _now.value = AppTime.malaysiaNow();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
      _attachRealtime();
    });
  }

  @override
  void dispose() {
    _loadGuard.invalidate();
    _clockTicker?.cancel();
    _realtimeDebounce?.cancel();
    AppRealtime.disposeChannel(_attendanceChannel);
    AppRealtime.disposeChannel(_leaveChannel);
    AppRealtime.disposeChannel(_claimChannel);
    _now.dispose();
    super.dispose();
  }

  void _attachRealtime() {
    _attendanceChannel = AppRealtime.subscribeAdminAttendance(
      channelSuffix: 'home',
      onReload: _onRealtimeEvent,
    );
    _leaveChannel = AppRealtime.subscribeAdminLeaves(
      channelSuffix: 'home',
      onReload: _onRealtimeEvent,
    );
    _claimChannel = AppRealtime.subscribeAdminClaims(
      channelSuffix: 'home',
      onReload: _onRealtimeEvent,
    );
  }

  void _onRealtimeEvent() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 550), () {
      if (mounted) _load(showSpinner: false);
    });
  }

  Future<void> _load({bool showSpinner = true}) async {
    final gen = _loadGuard.begin();
    if (showSpinner && mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getEmployeeCount(),
        SupabaseService.getTodayAttendancePulseCounts(),
        SupabaseService.getPendingLeaveRequestCount(),
        SupabaseService.getPendingExpenseClaimCount(),
      ]);
      if (!mounted || !_loadGuard.isCurrent(gen)) return;
      final pulse = results[1] as ({int checkedIn, int completed});
      final nextEmployees = results[0] as int;
      final nextLeaves = results[2] as int;
      final nextClaims = results[3] as int;
      final unchanged = !showSpinner &&
          !_loading &&
          _employeeCount == nextEmployees &&
          _checkedIn == pulse.checkedIn &&
          _completed == pulse.completed &&
          _pendingLeaveCount == nextLeaves &&
          _pendingClaimCount == nextClaims;
      if (unchanged) {
        _now.value = AppTime.malaysiaNow();
        return;
      }
      setState(() {
        _employeeCount = nextEmployees;
        _checkedIn = pulse.checkedIn;
        _completed = pulse.completed;
        _pendingLeaveCount = nextLeaves;
        _pendingClaimCount = nextClaims;
        _loading = false;
      });
      _now.value = AppTime.malaysiaNow();
    } catch (_) {
      if (!mounted || !_loadGuard.isCurrent(gen)) return;
      setState(() => _loading = false);
    }
  }

  String _greeting(DateTime t) {
    final h = t.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _confirmSignOut() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().signOut();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthProvider, AppUser?>((a) => a.user);
    if (user == null) return const SizedBox.shrink();

    final displayName = user.name.isNotEmpty ? user.name : 'Admin';
    final pendingClaims = _pendingClaimCount;
    final pendingTotal = _pendingLeaveCount + pendingClaims;

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
          onRefresh: () async => _load(showSpinner: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            cacheExtent: 520,
            padding: EdgeInsets.zero,
            children: [
              RepaintBoundary(
                child: ValueListenableBuilder<DateTime>(
                  valueListenable: _now,
                  builder: (context, now, _) {
                    return _heroHeader(
                      displayName,
                      _dateFmt.format(now),
                      now,
                    );
                  },
                ),
              ),
              RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppLayout.screenPaddingH,
                    20,
                    AppLayout.screenPaddingH,
                    0,
                  ),
                  child: _todayPulseCard(
                    teamCount: _employeeCount,
                    checkedIn: _checkedIn,
                    completed: _completed,
                    pendingApprovals: pendingTotal,
                  ),
                ),
              ),
              RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppLayout.screenPaddingH,
                    16,
                    AppLayout.screenPaddingH,
                    36,
                  ),
                  child: _quickAccessSection(
                    context,
                    pendingClaims: pendingClaims,
                    pendingLeaves: _pendingLeaveCount,
                  ),
                ),
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
          gradient: AppGradients.adminBrandHeader,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(28),
          ),
          border: Border(
            bottom: BorderSide(color: AppColors.brandHeaderBorder),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.adminHeaderShadow,
              blurRadius: 16,
              offset: const Offset(0, 10),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -30,
              top: -20,
              child: IgnorePointer(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
            ),
            Positioned(
              left: -40,
              bottom: 8,
              child: IgnorePointer(
                child: Container(
                  width: 100,
                  height: 100,
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
                  18,
                  AppLayout.screenPaddingH,
                  26,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: AppGradients.violet,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.brandAvatarRing,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.violet.withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: AppColors.onBrand,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _greeting(now),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.onBrandSecondary,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onBrand,
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brandChipFill,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: AppColors.brandChipBorder,
                                  ),
                                ),
                                child: const Text(
                                  'ADMINISTRATOR',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.onBrand,
                                    letterSpacing: 1.0,
                                  ),
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
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 18,
                            color: AppColors.onBrand.withValues(alpha: 0.95),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              dateText,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.onBrandMuted.withValues(
                                  alpha: 0.98,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Compact single-row pulse — minimal height, four metrics side by side.
  Widget _todayPulseCard({
    required int teamCount,
    required int checkedIn,
    required int completed,
    required int pendingApprovals,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
            spreadRadius: -3,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _workspaceGradientIcon(
                icon: Icons.query_stats_rounded,
                gradient: AppGradients.violet,
                glowColor: AppColors.violet,
                size: 26,
                iconSize: 13,
                softShadow: true,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Today’s pulse',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.25,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _pulseMiniStat(
                  icon: Icons.groups_rounded,
                  value: '$teamCount',
                  label: 'Team',
                  semanticHint: 'Team size',
                  iconGradient: AppGradients.violet,
                  iconGlowColor: AppColors.violet,
                ),
              ),
              Expanded(
                child: _pulseMiniStat(
                  icon: Icons.login_rounded,
                  value: '$checkedIn',
                  label: 'In',
                  semanticHint: 'Clocked in',
                  iconGradient: AppGradients.sky,
                  iconGlowColor: AppColors.sky,
                ),
              ),
              Expanded(
                child: _pulseMiniStat(
                  icon: Icons.task_alt_rounded,
                  value: '$completed',
                  label: 'Out',
                  semanticHint: 'Clocked out',
                  iconGradient: AppGradients.teal,
                  iconGlowColor: AppColors.teal,
                ),
              ),
              Expanded(
                child: _pulseMiniStat(
                  icon: Icons.notifications_active_rounded,
                  value: '$pendingApprovals',
                  label: 'Action',
                  semanticHint: 'Needs your action',
                  iconGradient: AppGradients.sunset,
                  iconGlowColor: AppColors.orange,
                  emphasize: pendingApprovals > 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pulseMiniStat({
    required IconData icon,
    required String value,
    required String label,
    required String semanticHint,
    required LinearGradient iconGradient,
    required Color iconGlowColor,
    bool emphasize = false,
  }) {
    return Semantics(
      container: true,
      label: '$semanticHint: $value',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: emphasize
              ? Border.all(
                  color: AppColors.orange.withValues(alpha: 0.5),
                  width: 1.5,
                )
              : null,
          color: emphasize
              ? AppColors.warningLight.withValues(alpha: 0.35)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _workspaceGradientIcon(
                icon: icon,
                gradient: iconGradient,
                glowColor: iconGlowColor,
                size: 24,
                iconSize: 12,
                softShadow: true,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: emphasize ? AppColors.orange : AppColors.textPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary.withValues(alpha: 0.88),
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickAccessSection(
    BuildContext context, {
    required int pendingClaims,
    required int pendingLeaves,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ADMIN WORKSPACE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.15,
            color: AppColors.violet.withValues(alpha: 0.88),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Where do you want to go?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.2,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Same layout for every shortcut — tap to open.',
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _bentoActionCard(
                context,
                label: pendingLeaves > 0
                    ? 'Leave ($pendingLeaves)'
                    : 'Leave hub',
                hint: 'Choose how to view leave',
                icon: Icons.beach_access_rounded,
                iconGradient: AppGradients.teal,
                iconGlowColor: AppColors.teal,
                showDot: pendingLeaves > 0,
                onTap: () =>
                    pushAppPage(context, const AdminLeaveHubScreen(), haptic: false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _bentoActionCard(
                context,
                label: 'Payroll',
                hint: 'Salaries, runs & payslips',
                icon: Icons.payments_rounded,
                iconGradient: AppGradients.primary,
                iconGlowColor: AppColors.indigo,
                onTap: () =>
                    pushAppPage(context, const PayrollHubScreen(), haptic: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _bentoActionCard(
                context,
                label: 'Attendance',
                hint: 'Who clocked in / out today',
                icon: Icons.access_time_filled_rounded,
                iconGradient: AppGradients.sky,
                iconGlowColor: AppColors.sky,
                onTap: () => AdminTabScope.goToTabOf(context, 1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _bentoActionCard(
                context,
                label: 'Team',
                hint: 'Employee list & profiles',
                icon: Icons.groups_rounded,
                iconGradient: AppGradients.primary,
                iconGlowColor: AppColors.indigo,
                onTap: () => AdminTabScope.goToTabOf(context, 2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _bentoActionCard(
                context,
                label: pendingClaims > 0 ? 'Claims ($pendingClaims)' : 'Claims',
                hint: 'Approve expense claims',
                icon: Icons.receipt_long_rounded,
                iconGradient: AppGradients.sunset,
                iconGlowColor: AppColors.orange,
                showDot: pendingClaims > 0,
                onTap: () => pushAppPage(
                  context,
                  const ClaimManagementScreen(),
                  haptic: false,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _bentoActionCard(
                context,
                label: 'Announcements',
                hint: 'Company-wide posts',
                icon: Icons.campaign_rounded,
                iconGradient: AppGradients.violet,
                iconGlowColor: AppColors.violet,
                onTap: () => pushAppPage(
                  context,
                  const AdminAnnouncementsScreen(),
                  haptic: false,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _bentoActionCard(
                context,
                label: 'Workplace location',
                hint: 'Clock-in geofence (one site)',
                icon: Icons.location_on_rounded,
                iconGradient: AppGradients.teal,
                iconGlowColor: AppColors.teal,
                onTap: () => pushAppPage(
                  context,
                  const AdminWorkSiteScreen(),
                  haptic: false,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _bentoActionCard(
                context,
                label: 'Help & support',
                hint: 'FAQs, contact HR/IT & diagnostics',
                icon: Icons.support_agent_rounded,
                iconGradient: AppGradients.sky,
                iconGlowColor: AppColors.sky,
                onTap: () => pushAppPage(
                  context,
                  const HelpSupportScreen(adminView: true),
                  haptic: false,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton.icon(
            onPressed: _confirmSignOut,
            icon: Icon(
              Icons.logout_rounded,
              size: 20,
              color: AppColors.danger.withValues(alpha: 0.9),
            ),
            label: Text(
              'Sign out',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.danger.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bentoActionCard(
    BuildContext context, {
    required String label,
    required String hint,
    required IconData icon,
    required LinearGradient iconGradient,
    required Color iconGlowColor,
    required VoidCallback onTap,
    bool showDot = false,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
            boxShadow: AppElevation.cardOnSurface,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                _workspaceGradientIcon(
                  icon: icon,
                  gradient: iconGradient,
                  glowColor: iconGlowColor,
                  size: 48,
                  iconSize: 23,
                  softShadow: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.25,
                                color: AppColors.textPrimary,
                                height: 1.15,
                              ),
                            ),
                          ),
                          if (showDot) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.orange,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.orange.withValues(
                                      alpha: 0.45,
                                    ),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hint,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: AppColors.textHint.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textHint.withValues(alpha: 0.75),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Same visual language as Leave hub: gradient rounded square + white glyph.
  static Widget _workspaceGradientIcon({
    required IconData icon,
    required LinearGradient gradient,
    required Color glowColor,
    double size = 52,
    double? iconSize,
    bool softShadow = false,
  }) {
    final blur = softShadow ? 6.0 : 12.0;
    final off = softShadow ? 2.0 : 4.0;
    final a = softShadow ? 0.22 : 0.35;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: a),
            blurRadius: blur,
            offset: Offset(0, off),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: iconSize ?? size * 0.48),
    );
  }
}

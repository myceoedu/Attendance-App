import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../constants/app_theme.dart';
import '../../models/employee_calendar_day.dart';
import '../../models/leave_request.dart';
import '../../providers/auth_provider.dart';
import '../../services/app_realtime.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_time.dart';
import '../../utils/leave_catalog.dart';
import '../../widgets/status_chip.dart';

// Dashboard-aligned semantic tints for calendar + stats.
const Color _kNavy = Color(0xFF14213D);
const Color _kPageBg = Color(0xFFF5F6F8);
const Color _kBorder = Color(0xFFE4E6EB);
const Color _kMuted = Color(0xFF9AA1AD);
const Color _kWeekendBg = Color(0xFFF5F6F8);
const Color _kOutside = Color(0xFFD2D5DB);
const Color _kPillBg = Color(0xFFE9EBF2);

const Color _kFull = Color(0xFF0F6E56);
const Color _kFullBg = Color(0xFFE3F5EE);
const Color _kHalf = Color(0xFF854F0B);
const Color _kHalfBg = Color(0xFFFAEEDA);
const Color _kLeave = Color(0xFF993C1D);
const Color _kLeaveBg = Color(0xFFFCEBE3);
const Color _kOpen = Color(0xFF185FA5);
const Color _kOpenBg = Color(0xFFE8F1FB);

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  // Shared DateFormats for the month grid.
  static final DateFormat _monthFmt = DateFormat('MMMM yyyy');
  static final DateFormat _dowFmt = DateFormat('EEE');
  static final DateFormat _dayShortFmt = DateFormat('d MMM');
  static final DateFormat _dayLongFmt = DateFormat('d MMM yyyy');
  static final DateFormat _fullDateFmt = DateFormat('EEEE, d MMMM yyyy');
  static final DateFormat _timeFmt = DateFormat('h:mm a');

  DateTime _selectedMonth = _currentMonth();
  final ValueNotifier<DateTime?> _selectedDayN = ValueNotifier<DateTime?>(null);
  EmployeeMonthlyCalendarData? _calendarData;
  bool _loading = true;
  String? _error;

  /// Malaysia calendar date (midnight). Refreshed on each load.
  DateTime _today = _todayInMalaysia();

  static DateTime _currentMonth() {
    final now = AppTime.malaysiaNow();
    return DateTime(now.year, now.month);
  }

  static DateTime _todayInMalaysia() {
    final now = AppTime.malaysiaNow();
    return DateTime(now.year, now.month, now.day);
  }

  Timer? _realtimeDebounce;
  RealtimeSubscription? _attendanceChannel;
  RealtimeSubscription? _leaveChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCalendar();
      _attachRealtime();
    });
  }

  @override
  void dispose() {
    _selectedDayN.dispose();
    _realtimeDebounce?.cancel();
    AppRealtime.disposeChannel(_attendanceChannel);
    AppRealtime.disposeChannel(_leaveChannel);
    super.dispose();
  }

  void _attachRealtime() {
    final uid = context.read<AuthProvider>().user?.id;
    if (uid == null) return;
    _attendanceChannel = AppRealtime.subscribeMyAttendance(
      userId: uid,
      onReload: _scheduleReload,
    );
    _leaveChannel = AppRealtime.subscribeMyLeaves(
      userId: uid,
      onReload: _scheduleReload,
    );
  }

  void _scheduleReload() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _loadCalendar(showSpinner: false);
    });
  }

  Future<void> _loadCalendar({bool showSpinner = true}) async {
    if (showSpinner && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final uid = context.read<AuthProvider>().user!.id;
      final data = await SupabaseService.getEmployeeMonthlyCalendar(
        uid,
        _selectedMonth,
      );
      if (!mounted) return;
      setState(() {
        _calendarData = data;
        _today = _todayInMalaysia();
        final sel = _selectedDayN.value;
        if (sel != null &&
            (sel.year != _selectedMonth.year ||
                sel.month != _selectedMonth.month)) {
          _selectedDayN.value = null;
        }
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load: $e';
      });
    }
  }

  bool get _canMoveForward =>
      _selectedMonth.isBefore(DateTime(_today.year, _today.month));

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
    _selectedDayN.value = null;
    _loadCalendar();
  }

  // ── monthly totals (computed once per loaded month, not per rebuild) ──────
  int get _presentDays => _calendarData?.fullDayPresentCount ?? 0;
  int get _halfDays => _calendarData?.halfDayWorkedCount ?? 0;
  int get _leaveDays => _calendarData?.leaveDayCount ?? 0;
  int get _openRecords => _calendarData?.openDayCount ?? 0;

  EmployeeCalendarDay? _dayDataFor(DateTime d) => _calendarData?.dayFor(d);

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        backgroundColor: _kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: AppChrome.onBrand,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        title: const Text('My attendance'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _kNavy, strokeWidth: 2.4),
            )
          : _error != null
          ? _buildError()
          : RefreshIndicator(
              color: _kNavy,
              onRefresh: () async => _loadCalendar(showSpinner: false),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _buildCalendarCard(),
                  const SizedBox(height: 12),
                  _buildMonthStatsRow(),
                  ValueListenableBuilder<DateTime?>(
                    valueListenable: _selectedDayN,
                    builder: (context, sel, _) {
                      if (sel == null) return const SizedBox.shrink();
                      return Column(
                        children: [
                          const SizedBox(height: 12),
                          _buildDayDetailPanel(sel),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMonthLeaveList(),
                ],
              ),
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _loadCalendar,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  // ── calendar card ─────────────────────────────────────────────────────────
  Widget _buildCalendarCard() {
    final now = _today;
    final monthLabel = _monthFmt.format(_selectedMonth);

    return ValueListenableBuilder<DateTime?>(
      valueListenable: _selectedDayN,
      builder: (context, selectedDay, _) {
        final focusedDay =
            selectedDay ??
            DateTime(_selectedMonth.year, _selectedMonth.month, 1);
        return RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                        color: _kMuted,
                      ),
                      Expanded(
                        child: Text(
                          monthLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _kNavy,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _canMoveForward
                            ? () => _changeMonth(1)
                            : null,
                        icon: Icon(
                          Icons.chevron_right_rounded,
                          color: _canMoveForward ? _kMuted : _kOutside,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
                  child: TableCalendar<EmployeeCalendarDay>(
                    firstDay: DateTime(2023, 1, 1),
                    lastDay: DateTime(now.year, now.month + 1, 0),
                    focusedDay: focusedDay,
                    currentDay: now,
                    headerVisible: false,
                    calendarFormat: CalendarFormat.month,
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Month',
                    },
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    rowHeight: 48,
                    daysOfWeekHeight: 28,
                    sixWeekMonthsEnforced: true,
                    selectedDayPredicate: (day) =>
                        selectedDay != null && isSameDay(day, selectedDay),
                    enabledDayPredicate: (day) =>
                        day.year == _selectedMonth.year &&
                        day.month == _selectedMonth.month,
                    onDaySelected: (sel, _) {
                      if (sel.year != _selectedMonth.year ||
                          sel.month != _selectedMonth.month) {
                        return;
                      }
                      _selectedDayN.value = DateTime(
                        sel.year,
                        sel.month,
                        sel.day,
                      );
                    },
                    calendarBuilders: CalendarBuilders<EmployeeCalendarDay>(
                      defaultBuilder: (ctx, day, _) =>
                          _buildDayCell(day, isSelected: false),
                      todayBuilder: (ctx, day, _) => _buildDayCell(
                        day,
                        isSelected:
                            selectedDay != null && isSameDay(day, selectedDay),
                        isToday: true,
                      ),
                      selectedBuilder: (ctx, day, _) =>
                          _buildDayCell(day, isSelected: true),
                      outsideBuilder: (ctx, day, _) => _buildOutsideCell(day),
                      dowBuilder: (ctx, day) => Center(
                        child: Text(
                          _dowFmt.format(day),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _kMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isWeekend(DateTime day) =>
      day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

  Widget _buildDayCell(
    DateTime day, {
    required bool isSelected,
    bool isToday = false,
  }) {
    final data = _calendarData?.dayFor(day);
    final weekend = _isWeekend(day);

    Color? cellBg;
    Color numColor = _kNavy;
    var weight = FontWeight.w500;

    if (isToday) {
      // Today: navy border only — no status fill (blue reserved for Open).
      cellBg = null;
      numColor = _kNavy;
      weight = FontWeight.w700;
    } else if (weekend) {
      cellBg = _kWeekendBg;
      numColor = _kMuted;
    } else if (data?.hasApprovedLeave == true) {
      cellBg = _kLeaveBg;
      numColor = _kLeave;
      weight = FontWeight.w500;
    } else if (data?.hasOpenAttendance == true) {
      cellBg = _kOpenBg;
      numColor = _kOpen;
      weight = FontWeight.w500;
    } else if (data?.isCountedAsHalfDayWorked == true) {
      cellBg = _kHalfBg;
      numColor = _kHalf;
      weight = FontWeight.w500;
    } else if (data?.isCountedAsFullDayPresent == true ||
        data?.hasCompletedAttendance == true) {
      cellBg = _kFullBg;
      numColor = _kFull;
      weight = FontWeight.w500;
    }

    if (isSelected && !isToday) {
      numColor = _kNavy;
      weight = FontWeight.w700;
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          color: cellBg,
          borderRadius: BorderRadius.circular(6),
          border: isToday
              ? Border.all(color: _kNavy, width: 1.5)
              : (isSelected
                    ? Border.all(color: _kNavy, width: 1.5)
                    : null),
        ),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: weight,
            color: numColor,
          ),
        ),
      ),
    );
  }

  Widget _buildOutsideCell(DateTime day) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Center(
        child: Text(
          '${day.day}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: _kOutside,
          ),
        ),
      ),
    );
  }

  // ── monthly stats (compact) ───────────────────────────────────────────────
  Widget _buildMonthStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          _buildStatChip('$_presentDays', 'Full', _kFull),
          _statDivider(),
          _buildStatChip('$_halfDays', 'Half', _kHalf),
          _statDivider(),
          _buildStatChip('$_leaveDays', 'Leave', _kLeave),
          _statDivider(),
          _buildStatChip('$_openRecords', 'Open', _kOpen),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: _kBorder,
    );
  }

  Widget _buildStatChip(String value, String label, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.1,
              letterSpacing: -0.2,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: _kMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ── selected day detail ───────────────────────────────────────────────────
  Widget _buildDayDetailPanel(DateTime selectedDay) {
    final dayData = _dayDataFor(selectedDay);
    final attendance = dayData?.primaryAttendance;
    final leave = dayData?.approvedLeave;
    final dateLabel = _fullDateFmt.format(selectedDay);

    Color accent;
    IconData accentIcon;
    if (dayData?.hasApprovedLeave == true) {
      accent = AppColors.leave;
      accentIcon = Icons.event_available_outlined;
    } else if (dayData?.hasOpenAttendance == true) {
      accent = AppColors.open;
      accentIcon = Icons.access_time_outlined;
    } else if (dayData?.isCountedAsHalfDayWorked == true) {
      accent = AppColors.orange;
      accentIcon = Icons.timelapse_rounded;
    } else if (dayData?.hasCompletedAttendance == true) {
      accent = AppColors.success;
      accentIcon = Icons.check_circle_outline;
    } else {
      accent = AppColors.textHint;
      accentIcon = Icons.calendar_today_outlined;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Icon(accentIcon, color: accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dayData?.stateLabel ?? 'No record',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (attendance != null) ...[
                  Row(
                    children: [
                      StatusChip.fromStatus(attendance.status),
                      if (attendance.isHalfDayWorked) ...[
                        const SizedBox(width: 8),
                        StatusChip(
                          label: attendance.sessionShortLabel ?? 'Half day',
                          color: AppColors.orange,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  _infoRow(
                    Icons.login_rounded,
                    'Clock in',
                    attendance.clockInTime == null
                        ? '—'
                        : _timeFmt.format(
                            AppTime.toMalaysia(attendance.clockInTime!),
                          ),
                    AppColors.primary,
                  ),
                  _infoRow(
                    Icons.logout_rounded,
                    'Clock out',
                    attendance.clockOutTime == null
                        ? 'Not yet'
                        : _timeFmt.format(
                            AppTime.toMalaysia(attendance.clockOutTime!),
                          ),
                    attendance.clockOutTime == null
                        ? AppColors.open
                        : AppColors.success,
                  ),
                  if (attendance.workedLabel != null)
                    _infoRow(
                      Icons.schedule_rounded,
                      'Worked',
                      attendance.workedLabel!,
                      attendance.isHalfDayWorked
                          ? AppColors.orange
                          : AppColors.textSecondary,
                    ),
                ] else ...[
                  const Text(
                    'No attendance record for this date.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (leave != null) ...[
                  if (attendance != null) const Divider(height: 22),
                  _infoRow(
                    Icons.event_available_outlined,
                    'Leave type',
                    leave.leaveTypeDisplay,
                    AppColors.leave,
                  ),
                  _infoRow(
                    Icons.date_range_outlined,
                    'Date range',
                    '${_dayShortFmt.format(leave.startDate)} – '
                        '${_dayLongFmt.format(leave.endDate)}',
                    AppColors.leave,
                  ),
                ],
                if (attendance == null && leave == null) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'No attendance or approved leave for this date.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── month leave list ──────────────────────────────────────────────────────
  Widget _buildMonthLeaveList() {
    final leaves = _calendarData?.monthLeaves ?? const <LeaveRequest>[];
    final monthLabel = _monthFmt.format(_selectedMonth);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  size: 18,
                  color: _kMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Approved leave · $monthLabel',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _kNavy,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _kPillBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${leaves.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kNavy,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _kBorder),
          if (leaves.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Center(
                child: Text(
                  'No approved leave for this month.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: _kMuted,
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < leaves.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildLeaveItem(leaves[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLeaveItem(LeaveRequest leave) {
    final st = LeaveCatalog.uiStyle(leave.leaveType);
    final typeColor = st.color;
    final typeIcon = st.icon;

    final range =
        '${_dayShortFmt.format(leave.startDate)} – '
        '${_dayLongFmt.format(leave.endDate)}';
    final duration = leave.durationDisplayLabel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(typeIcon, size: 18, color: typeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _tag(leave.leaveTypeDisplay, typeColor),
                    const SizedBox(width: 8),
                    _tag(duration, AppColors.textSecondary),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  range,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (leave.reason.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    leave.reason.trim(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────
  Widget _infoRow(IconData icon, String label, String value, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}


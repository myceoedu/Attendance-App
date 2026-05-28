import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  DateTime _selectedMonth = DateTime(
    AppTime.malaysiaNow().year,
    AppTime.malaysiaNow().month,
  );
  final ValueNotifier<DateTime?> _selectedDayN = ValueNotifier<DateTime?>(null);
  EmployeeMonthlyCalendarData? _calendarData;
  bool _loading = true;
  String? _error;

  Timer? _realtimeDebounce;
  RealtimeChannel? _attendanceChannel;
  RealtimeChannel? _leaveChannel;

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
      channelSuffix: 'history_cal',
      onReload: _scheduleReload,
    );
    _leaveChannel = AppRealtime.subscribeMyLeaves(
      userId: uid,
      channelSuffix: 'history_cal',
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
    if (showSpinner && mounted) setState(() { _loading = true; _error = null; });
    try {
      final uid = context.read<AuthProvider>().user!.id;
      final data = await SupabaseService.getEmployeeMonthlyCalendar(
        uid,
        _selectedMonth,
      );
      if (!mounted) return;
      setState(() {
        _calendarData = data;
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
      setState(() { _loading = false; _error = 'Failed to load: $e'; });
    }
  }

  bool get _canMoveForward {
    final now = AppTime.malaysiaNow();
    return _selectedMonth.isBefore(DateTime(now.year, now.month));
  }

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

  // ── monthly totals ────────────────────────────────────────────────────────
  int get _presentDays =>
      _calendarData?.days.where((d) => d.isCountedAsPresentDay).length ?? 0;
  int get _leaveDays =>
      _calendarData?.days.where((d) => d.hasApprovedLeave).length ?? 0;
  int get _openRecords =>
      _calendarData?.days.where((d) => d.isCountedAsOpenDay).length ?? 0;

  EmployeeCalendarDay? _dayDataFor(DateTime d) {
    if (_calendarData == null) return null;
    return _calendarData!.dayFor(d);
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('My Attendance')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: () async => _loadCalendar(showSpinner: false),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _buildCalendarCard(),
                  const SizedBox(height: 12),
                  _buildMonthStatsRow(),
                  const SizedBox(height: 12),
                  _buildLegend(),
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
    final now = AppTime.malaysiaNow();
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);

    return ValueListenableBuilder<DateTime?>(
      valueListenable: _selectedDayN,
      builder: (context, selectedDay, _) {
        final focusedDay = selectedDay ??
            DateTime(_selectedMonth.year, _selectedMonth.month, 1);
        return RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                        color: AppColors.textPrimary,
                      ),
                      Expanded(
                        child: Text(
                          monthLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed:
                            _canMoveForward ? () => _changeMonth(1) : null,
                        icon: Icon(
                          Icons.chevron_right,
                          color: _canMoveForward
                              ? AppColors.textPrimary
                              : AppColors.textHint,
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
                    rowHeight: 52,
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
                      _selectedDayN.value =
                          DateTime(sel.year, sel.month, sel.day);
                    },
                    calendarBuilders: CalendarBuilders<EmployeeCalendarDay>(
                      defaultBuilder: (ctx, day, _) =>
                          _buildDayCell(day, isSelected: false),
                      todayBuilder: (ctx, day, _) => _buildDayCell(
                        day,
                        isSelected: selectedDay != null &&
                            isSameDay(day, selectedDay),
                        isToday: true,
                      ),
                      selectedBuilder: (ctx, day, _) =>
                          _buildDayCell(day, isSelected: true),
                      outsideBuilder: (ctx, day, _) => _buildOutsideCell(day),
                      dowBuilder: (ctx, day) => Center(
                        child: Text(
                          DateFormat('EEE').format(day),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
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

  Widget _buildDayCell(
    DateTime day, {
    required bool isSelected,
    bool isToday = false,
  }) {
    final normalized = DateTime(day.year, day.month, day.day);
    final data = _calendarData?.dayFor(normalized);
    final now = AppTime.malaysiaNow();
    final isPast = normalized.isBefore(DateTime(now.year, now.month, now.day));

    Color cellBg;
    Color cellBorder;
    Color numColor;

    if (data?.hasApprovedLeave == true) {
      cellBg = AppColors.leaveLight.withValues(alpha: 0.8);
      cellBorder = AppColors.leave.withValues(alpha: 0.45);
      numColor = AppColors.leave;
    } else if (data?.hasOpenAttendance == true) {
      cellBg = AppColors.openLight.withValues(alpha: 0.75);
      cellBorder = AppColors.open.withValues(alpha: 0.45);
      numColor = AppColors.open;
    } else if (data?.hasCompletedAttendance == true) {
      cellBg = AppColors.success.withValues(alpha: 0.22);
      cellBorder = AppColors.success.withValues(alpha: 0.55);
      numColor = AppColors.success;
    } else if (isPast) {
      cellBg = AppColors.surface;
      cellBorder = AppColors.divider;
      numColor = AppColors.textHint;
    } else {
      cellBg = Colors.white;
      cellBorder = AppColors.divider;
      numColor = AppColors.textPrimary;
    }

    if (isSelected) {
      cellBorder = AppColors.primary;
      numColor = AppColors.primaryDark;
    }

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Container(
        padding: EdgeInsets.all(isToday && !isSelected ? 1.5 : 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13.5),
          border: isToday && !isSelected
              ? Border.all(color: AppColors.today, width: 1.6)
              : null,
          boxShadow: isToday && !isSelected
              ? [
                  BoxShadow(
                    color: AppColors.today.withValues(alpha: 0.16),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: cellBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cellBorder, width: isSelected ? 2.0 : 1.0),
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: numColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutsideCell(DateTime day) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Center(
        child: Text(
          '${day.day}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textHint,
          ),
        ),
      ),
    );
  }

  // ── monthly stats row ─────────────────────────────────────────────────────
  Widget _buildMonthStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatChip(
            Icons.check_circle_outline,
            '$_presentDays',
            'Present',
            AppColors.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatChip(
            Icons.event_available_outlined,
            '$_leaveDays',
            'Leave',
            AppColors.leave,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatChip(
            Icons.warning_amber_rounded,
            '$_openRecords',
            'Open',
            AppColors.open,
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── legend ────────────────────────────────────────────────────────────────
  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _LegendSwatch(color: AppColors.success, label: 'Present'),
          _LegendSwatch(color: AppColors.leave, label: 'Leave'),
          _LegendSwatch(color: AppColors.open, label: 'Open'),
          _LegendSwatch(color: AppColors.textHint, label: 'No record'),
        ],
      ),
    );
  }

  // ── selected day detail ───────────────────────────────────────────────────
  Widget _buildDayDetailPanel(DateTime selectedDay) {
    final dayData = _dayDataFor(selectedDay);
    final attendance = dayData?.primaryAttendance;
    final leave = dayData?.approvedLeave;
    final dateLabel = DateFormat('EEEE, d MMMM yyyy').format(selectedDay);

    Color accent;
    IconData accentIcon;
    if (dayData?.hasApprovedLeave == true) {
      accent = AppColors.leave;
      accentIcon = Icons.event_available_outlined;
    } else if (dayData?.hasOpenAttendance == true) {
      accent = AppColors.open;
      accentIcon = Icons.access_time_outlined;
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
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
                  StatusChip.fromStatus(attendance.status),
                  const SizedBox(height: 14),
                  _infoRow(
                    Icons.login_rounded,
                    'Clock in',
                    attendance.clockInTime == null
                        ? '—'
                        : DateFormat('h:mm a').format(
                            AppTime.toMalaysia(attendance.clockInTime!),
                          ),
                    AppColors.primary,
                  ),
                  _infoRow(
                    Icons.logout_rounded,
                    'Clock out',
                    attendance.clockOutTime == null
                        ? 'Not yet'
                        : DateFormat('h:mm a').format(
                            AppTime.toMalaysia(attendance.clockOutTime!),
                          ),
                    attendance.clockOutTime == null
                        ? AppColors.open
                        : AppColors.success,
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
                    '${DateFormat('d MMM').format(leave.startDate)} – '
                        '${DateFormat('d MMM yyyy').format(leave.endDate)}',
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
    final seen = <String>{};
    final leaves = <LeaveRequest>[];
    if (_calendarData != null) {
      for (final day in _calendarData!.days) {
        final leave = day.approvedLeave;
        if (leave != null && seen.add(leave.id)) {
          leaves.add(leave);
        }
      }
    }

    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.leaveLight.withValues(alpha: 0.7),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
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
                    'Approved Leave — $monthLabel',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.leave,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.leave.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${leaves.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.leave,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (leaves.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No approved leave for this month.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: leaves.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (_, i) => _buildLeaveItem(leaves[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildLeaveItem(LeaveRequest leave) {
    final st = LeaveCatalog.uiStyle(leave.leaveType);
    final typeColor = st.color;
    final typeIcon = st.icon;

    final range = '${DateFormat('d MMM').format(leave.startDate)} – '
        '${DateFormat('d MMM yyyy').format(leave.endDate)}';
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
  Widget _infoRow(
    IconData icon,
    String label,
    String value,
    Color iconColor,
  ) {
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

// ── legend swatch ─────────────────────────────────────────────────────────
class _LegendSwatch extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendSwatch({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 20,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.55)),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

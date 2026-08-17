import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../constants/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/employee_calendar_day.dart';
import '../../models/leave_request.dart';
import '../../services/app_realtime.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_time.dart';
import '../../utils/leave_catalog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';

// Same semantic tokens as My Attendance (employee calendar).
const Color _kNavy = Color(0xFF14213D);
const Color _kPageBg = Color(0xFFF5F6F8);
const Color _kBorder = Color(0xFFE4E6EB);
const Color _kMuted = Color(0xFF9AA1AD);
const Color _kEyebrow = Color(0xFF8B93A3);
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

class EmployeeAttendanceCalendarScreen extends StatefulWidget {
  const EmployeeAttendanceCalendarScreen({super.key});

  @override
  State<EmployeeAttendanceCalendarScreen> createState() =>
      _EmployeeAttendanceCalendarScreenState();
}

class _EmployeeAttendanceCalendarScreenState
    extends State<EmployeeAttendanceCalendarScreen> {
  // Shared DateFormats for the month grid.
  static final DateFormat _monthFmt = DateFormat('MMMM yyyy');
  static final DateFormat _dowFmt = DateFormat('EEE');
  static final DateFormat _dayShortFmt = DateFormat('d MMM');
  static final DateFormat _dayLongFmt = DateFormat('d MMM yyyy');
  static final DateFormat _fullDateFmt = DateFormat('EEEE, d MMMM yyyy');
  static final DateFormat _timeFmt = DateFormat('h:mm a');

  DateTime _selectedMonth = _currentMonth();
  final ValueNotifier<DateTime?> _selectedDayN = ValueNotifier<DateTime?>(null);
  List<AppUser> _employees = [];
  String? _selectedEmployeeId;
  AppUser? _selectedEmployee;
  EmployeeMonthlyCalendarData? _calendarData;
  bool _loading = true;
  String? _error;
  Timer? _realtimeDebounce;
  RealtimeSubscription? _attendanceChannel;
  RealtimeSubscription? _leaveChannel;

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

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachRealtime());
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
    _attendanceChannel = AppRealtime.subscribeAdminAttendance(
      onReload: _scheduleReload,
    );
    _leaveChannel = AppRealtime.subscribeAdminLeaves(
      onReload: _scheduleReload,
    );
  }

  void _scheduleReload() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted && _selectedEmployeeId != null) {
        _loadCalendar(showSpinner: false);
      }
    });
  }

  Future<void> _loadEmployees() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final employees = await SupabaseService.getAllEmployees();
      if (!mounted) return;
      final selected =
          _selectedEmployeeId ??
          (employees.isNotEmpty ? employees.first.id : null);
      setState(() {
        _employees = employees;
        _selectedEmployeeId = selected;
        _selectedEmployee = _findEmployee(employees, selected);
      });
      if (selected == null) {
        setState(() => _loading = false);
        return;
      }
      await _loadCalendar(showSpinner: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load employees: $e';
      });
    }
  }

  Future<void> _loadCalendar({bool showSpinner = true}) async {
    final employeeId = _selectedEmployeeId;
    if (employeeId == null) return;
    if (showSpinner && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await SupabaseService.getEmployeeMonthlyCalendar(
        employeeId,
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
        _error = 'Failed to load calendar: $e';
      });
    }
  }

  static AppUser? _findEmployee(List<AppUser> employees, String? id) {
    if (id == null) return null;
    for (final e in employees) {
      if (e.id == id) return e;
    }
    return null;
  }

  EmployeeCalendarDay? _dayDataFor(DateTime d) => _calendarData?.dayFor(d);

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

  void _onEmployeeChanged(String id) {
    if (id == _selectedEmployeeId) return;
    setState(() {
      _selectedEmployeeId = id;
      _selectedEmployee = _findEmployee(_employees, id);
    });
    _selectedDayN.value = null;
    _loadCalendar();
  }

  // ── monthly totals (computed once per loaded month, not per rebuild) ───────
  int get _presentDays => _calendarData?.fullDayPresentCount ?? 0;
  int get _halfDays => _calendarData?.halfDayWorkedCount ?? 0;
  int get _leaveDays => _calendarData?.leaveDayCount ?? 0;
  int get _openRecords => _calendarData?.openDayCount ?? 0;

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _kNavy, size: 22),
        titleTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: _kNavy,
        ),
        title: const Text('Employee calendar'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: ColoredBox(
            color: _kBorder,
            child: SizedBox(height: 1, width: double.infinity),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _kNavy, strokeWidth: 2.4),
            )
          : _error != null
          ? _buildErrorView()
          : _employees.isEmpty
          ? const Center(
              child: EmptyState(
                icon: Icons.people_outline,
                title: 'No employees found',
                subtitle: 'Add an employee account to use the monthly calendar',
              ),
            )
          : RefreshIndicator(
              color: _kNavy,
              onRefresh: () async => _loadCalendar(showSpinner: false),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _buildEmployeeHeader(),
                  const SizedBox(height: 12),
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
                  _buildEmployeeInfoCard(),
                  const SizedBox(height: 12),
                  _buildMonthLeaveList(),
                ],
              ),
            ),
    );
  }

  Widget _buildErrorView() {
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

  // ── employee header card ───────────────────────────────────────────────────
  Widget _buildEmployeeHeader() {
    final employee = _selectedEmployee;
    if (employee == null) return const SizedBox.shrink();
    final label = _employeeLabel(employee);
    final canSwitch = _employees.length > 1;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canSwitch ? _showEmployeePicker : null,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            color: _kNavy,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                child: Text(
                  label.isNotEmpty ? label[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      employee.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: _kEyebrow,
                      ),
                    ),
                  ],
                ),
              ),
              if (canSwitch) ...[
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── employee picker bottom sheet ───────────────────────────────────────────
  void _showEmployeePicker() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select employee',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: _employees.length,
                itemBuilder: (_, i) {
                  final emp = _employees[i];
                  final isSelected = emp.id == _selectedEmployeeId;
                  final lbl = _employeeLabel(emp);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? AppColors.primaryLight
                          : AppColors.surface,
                      child: Text(
                        lbl.isNotEmpty ? lbl[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    title: Text(
                      lbl,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      emp.email,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: AppColors.primary,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _onEmployeeChanged(emp.id);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  // ── monthly stats (compact) ────────────────────────────────────────────────
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

  // ── selected day detail panel ──────────────────────────────────────────────
  Widget _buildDayDetailPanel(DateTime selectedDay) {
    final dayData = _dayDataFor(selectedDay);
    final attendance = dayData?.primaryAttendance;
    final leave = dayData?.approvedLeave;
    final dateLabel = _fullDateFmt.format(selectedDay);

    // Derive accent colour from the day state
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
          // Coloured header band
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

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── attendance section
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
                      if (dayData != null &&
                          dayData.attendanceRecords.length > 1) ...[
                        const SizedBox(width: 8),
                        _tag(
                          '${dayData.attendanceRecords.length} records',
                          AppColors.sky,
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

                // ── leave section
                if (leave != null) ...[
                  if (attendance != null) const Divider(height: 22),
                  if (attendance == null) const SizedBox(height: 0),
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

                // ── no record at all
                if (attendance == null && leave == null) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'No attendance or approved leave recorded for this date.',
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

  // ── employee info card ─────────────────────────────────────────────────────
  Widget _buildEmployeeInfoCard() {
    final employee = _selectedEmployee;
    if (employee == null) return const SizedBox.shrink();
    final label = _employeeLabel(employee);

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
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _kPillBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    size: 16,
                    color: _kNavy,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Employee info',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: _kNavy,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _kBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              children: [
                _infoRow(Icons.person_outline, 'Name', label, _kMuted),
                _infoRow(Icons.email_outlined, 'Email', employee.email, _kMuted),
                if (employee.hasPhone)
                  _infoRow(
                    Icons.phone_outlined,
                    'Phone',
                    employee.phone!,
                    _kMuted,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          size: 16,
                          color: _kMuted,
                        ),
                        const SizedBox(width: 10),
                        const SizedBox(
                          width: 76,
                          child: Text(
                            'Phone',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: _kMuted,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Not provided',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _kMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── month leave list ───────────────────────────────────────────────────────
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
            for (var i = 0; i < leaves.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
              _buildLeaveListItem(leaves[i]),
            ],
        ],
      ),
    );
  }

  Widget _buildLeaveListItem(LeaveRequest leave) {
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
                if (leave.attachmentPath != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      Icon(
                        Icons.attach_file,
                        size: 13,
                        color: AppColors.textHint,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Document attached',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

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
                fontWeight: FontWeight.w500,
                color: _kMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: _kNavy,
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

  String _employeeLabel(AppUser e) {
    if (e.name.trim().isNotEmpty) return e.name.trim();
    if (e.username.trim().isNotEmpty) return e.username.trim();
    return e.email.trim();
  }
}


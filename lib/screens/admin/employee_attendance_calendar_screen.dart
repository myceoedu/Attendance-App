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

class EmployeeAttendanceCalendarScreen extends StatefulWidget {
  const EmployeeAttendanceCalendarScreen({super.key});

  @override
  State<EmployeeAttendanceCalendarScreen> createState() =>
      _EmployeeAttendanceCalendarScreenState();
}

class _EmployeeAttendanceCalendarScreenState
    extends State<EmployeeAttendanceCalendarScreen> {
  // `DateFormat` parses its pattern on construction. The month grid renders up
  // to 42 cells plus 7 weekday labels per rebuild, so these are shared.
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

  /// Midnight today in Malaysia time. Cached because every cell compared
  /// against a freshly computed "now"; refreshed on each load.
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
  int get _presentDays => _calendarData?.presentDayCount ?? 0;
  int get _leaveDays => _calendarData?.leaveDayCount ?? 0;
  int get _openRecords => _calendarData?.openDayCount ?? 0;

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Employee Calendar'),
        actions: [
          if (_employees.length > 1)
            IconButton(
              tooltip: 'Switch employee',
              onPressed: _showEmployeePicker,
              icon: const Icon(Icons.people_outline),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
              onRefresh: () async => _loadCalendar(showSpinner: false),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _buildEmployeeHeader(),
                  const SizedBox(height: 12),
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
    return GestureDetector(
      onTap: _employees.length > 1 ? _showEmployeePicker : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              child: Text(
                label.isNotEmpty ? label[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    employee.email,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            if (_employees.length > 1)
              const Icon(Icons.swap_horiz, color: Colors.white70, size: 22),
          ],
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
                        onPressed: _canMoveForward
                            ? () => _changeMonth(1)
                            : null,
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
    final data = _calendarData?.dayFor(day);
    final isPast = DateTime(day.year, day.month, day.day).isBefore(_today);

    // Priority: approved leave > open record > completed attendance >
    // past-no-record > future (leave wins when both leave and attendance exist).
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

    // Selected day: keep its state bg but add a strong primary border + bolder number.
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
            border: Border.all(
              color: cellBorder,
              width: isSelected ? 2.0 : 1.0,
            ),
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

  // ── monthly stats row ──────────────────────────────────────────────────────
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

  // ── legend ─────────────────────────────────────────────────────────────────
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.badge_outlined, size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Employee Info',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _infoRow(
                  Icons.person_outline,
                  'Name',
                  label,
                  AppColors.primary,
                ),
                _infoRow(
                  Icons.email_outlined,
                  'Email',
                  employee.email,
                  AppColors.primary,
                ),
                // Phone — show value or "Not provided"
                if (employee.hasPhone)
                  _infoRow(
                    Icons.phone_outlined,
                    'Phone',
                    employee.phone!,
                    AppColors.primary,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          size: 16,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 10),
                        const SizedBox(
                          width: 76,
                          child: Text(
                            'Phone',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Not provided',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textHint,
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.leaveLight.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
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
                    'Approved Leave — $monthLabel',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.leave,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
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
            // Already inside a scrollable; building the rows directly avoids a
            // nested viewport that would lay out every row twice.
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

  String _employeeLabel(AppUser e) {
    if (e.name.trim().isNotEmpty) return e.name.trim();
    if (e.username.trim().isNotEmpty) return e.username.trim();
    return e.email.trim();
  }
}

// ── legend swatch ───────────────────────────────────────────────────────────
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

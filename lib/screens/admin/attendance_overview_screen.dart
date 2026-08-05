import 'dart:async';
import '../../utils/app_route.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/app_theme.dart';
import '../../models/attendance.dart';
import '../../services/app_realtime.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_time.dart';
import '../../utils/async_load_guard.dart';
import '../../utils/debouncer.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/empty_state.dart';
import 'admin_shell.dart';
import 'employee_attendance_calendar_screen.dart';
import 'monthly_attendance_screen.dart';

class AttendanceOverviewScreen extends StatefulWidget {
  const AttendanceOverviewScreen({super.key});

  @override
  State<AttendanceOverviewScreen> createState() =>
      _AttendanceOverviewScreenState();
}

class _AttendanceOverviewScreenState extends State<AttendanceOverviewScreen> {
  List<Attendance> _records = [];
  bool _loading = true;
  String? _error;
  Timer? _realtimeDebounce;
  RealtimeChannel? _attendanceChannel;
  final TextEditingController _searchCtrl = TextEditingController();
  final Debouncer _searchDebounce = Debouncer();
  final _loadGuard = AsyncLoadGuard();
  String _statusFilter = 'all';
  bool _tabActive = true;
  static const int _tabIndex = 1;
  static final _timeFmt = DateFormat('h:mm a');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyTabVisibility(AdminTabScope.isActive(context, _tabIndex));
      _load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = AdminTabScope.isActive(context, _tabIndex);
    if (active != _tabActive) {
      _applyTabVisibility(active);
    }
  }

  void _applyTabVisibility(bool active) {
    _tabActive = active;
    if (active) {
      if (_attendanceChannel == null) _attachRealtime();
    } else {
      _realtimeDebounce?.cancel();
      AppRealtime.disposeChannel(_attendanceChannel);
      _attendanceChannel = null;
    }
  }

  @override
  void dispose() {
    _loadGuard.invalidate();
    _searchDebounce.dispose();
    _searchCtrl.dispose();
    _realtimeDebounce?.cancel();
    AppRealtime.disposeChannel(_attendanceChannel);
    super.dispose();
  }

  void _attachRealtime() {
    _attendanceChannel = AppRealtime.subscribeAdminAttendance(
      channelSuffix: 'overview',
      onReload: () {
        if (!_tabActive) return;
        _realtimeDebounce?.cancel();
        _realtimeDebounce = Timer(const Duration(milliseconds: 400), () {
          if (mounted && _tabActive) _load(showSpinner: false);
        });
      },
    );
  }

  Future<void> _load({bool showSpinner = true}) async {
    final gen = _loadGuard.begin();
    if (showSpinner && mounted) setState(() => _loading = true);
    try {
      final data = await SupabaseService.getTodayAllAttendance();
      if (!mounted || !_loadGuard.isCurrent(gen)) return;
      setState(() {
        _records = data;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || !_loadGuard.isCurrent(gen)) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load: $e';
      });
    }
  }

  List<Attendance> get _filteredRecords {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _records.where((record) {
      if (_statusFilter != 'all' && record.status != _statusFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final name = record.userName?.toLowerCase() ?? '';
      return name.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    var completed = 0;
    var inProgress = 0;
    for (final r in _records) {
      if (r.status == 'completed') {
        completed++;
      } else if (r.status == 'in_progress') {
        inProgress++;
      }
    }
    final filteredRecords = _filteredRecords;

    // No nested [Scaffold] — shell already owns one.
    return SizedBox.expand(
      child: ColoredBox(
        color: AppColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBar(
              title: Text(
                'Attendance — ${DateFormat('d MMM').format(AppTime.malaysiaNow())}',
              ),
              actions: [
                IconButton(
                  tooltip: 'Monthly summary',
                  onPressed: () =>
                      pushAppPage(context, const MonthlyAttendanceScreen()),
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
                IconButton(
                  tooltip: 'Employee calendar',
                  onPressed: () => pushAppPage(
                    context,
                    const EmployeeAttendanceCalendarScreen(),
                  ),
                  icon: const Icon(Icons.calendar_view_month_outlined),
                ),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _summaryItem(
                                'Total',
                                '${_records.length}',
                                AppColors.primary,
                              ),
                              _summaryItem(
                                'In Progress',
                                '$inProgress',
                                AppColors.inProgress,
                              ),
                              _summaryItem(
                                'Completed',
                                '$completed',
                                AppColors.success,
                              ),
                            ],
                          ),
                        ),
                        AppFilterBar(
                          searchController: _searchCtrl,
                          onSearchChanged: (_) => _searchDebounce(() {
                            if (mounted) setState(() {});
                          }),
                          searchHint: 'Search employee name',
                          chipOptions: const [
                            AppFilterOption(value: 'all', label: 'All'),
                            AppFilterOption(
                              value: 'in_progress',
                              label: 'In Progress',
                            ),
                            AppFilterOption(
                              value: 'completed',
                              label: 'Completed',
                            ),
                          ],
                          selectedChip: _statusFilter,
                          onChipSelected: (value) {
                            setState(() => _statusFilter = value);
                          },
                        ),
                        Expanded(
                          child: filteredRecords.isEmpty
                              ? const EmptyState(
                                  icon: Icons.access_time,
                                  title: 'No records match the filters',
                                  subtitle: 'Try another employee or status',
                                )
                              : RefreshIndicator(
                                  onRefresh: () async =>
                                      _load(showSpinner: true),
                                  child: ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    addAutomaticKeepAlives: false,
                                    cacheExtent: 400,
                                    itemCount: filteredRecords.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (_, i) {
                                      final r = filteredRecords[i];
                                      final name =
                                          (r.userName?.isNotEmpty == true)
                                          ? r.userName!
                                          : 'Unknown';
                                      return KeyedSubtree(
                                        key: ValueKey<String>(r.id),
                                        child: RepaintBoundary(
                                          child: Container(
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: AppColors.divider,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 20,
                                                  backgroundColor:
                                                      AppColors.primaryLight,
                                                  child: Text(
                                                    name[0].toUpperCase(),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: AppColors.primary,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        name,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'In: ${r.clockInTime != null ? _timeFmt.format(AppTime.toMalaysia(r.clockInTime!)) : '-'}'
                                                        '  •  '
                                                        'Out: ${r.clockOutTime != null ? _timeFmt.format(AppTime.toMalaysia(r.clockOutTime!)) : '-'}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: AppColors
                                                              .textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                StatusChip.fromStatus(r.status),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      children: [
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
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

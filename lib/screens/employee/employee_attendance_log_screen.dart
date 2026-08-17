import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/app_theme.dart';
import '../../models/attendance.dart';
import '../../providers/auth_provider.dart';
import '../../services/app_realtime.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_time.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/status_chip.dart';

/// Chronological attendance log with status and week/month period filters.
class EmployeeAttendanceLogScreen extends StatefulWidget {
  const EmployeeAttendanceLogScreen({super.key});

  @override
  State<EmployeeAttendanceLogScreen> createState() =>
      _EmployeeAttendanceLogScreenState();
}

class _EmployeeAttendanceLogScreenState
    extends State<EmployeeAttendanceLogScreen> {
  static const int _pageSize = 40;
  static final DateFormat _dateFmt = DateFormat('EEE, d MMM yyyy');
  static final DateFormat _timeFmt = DateFormat('h:mm a');
  static final DateFormat _monthFmt = DateFormat('MMMM yyyy');
  static final DateFormat _dayShortFmt = DateFormat('d MMM');
  static final DateFormat _dayLongFmt = DateFormat('d MMM yyyy');

  final List<Attendance> _records = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _nextOffset = 0;
  String? _error;
  String _statusFilter = 'all';
  String _periodKind = 'week';
  DateTime _periodAnchor = AppTime.malaysiaDateOnly();

  Timer? _debounce;
  RealtimeSubscription? _channel;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
      _attachRealtime();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _debounce?.cancel();
    AppRealtime.disposeChannel(_channel);
    super.dispose();
  }

  void _attachRealtime() {
    final uid = context.read<AuthProvider>().user?.id;
    if (uid == null) return;
    _channel = AppRealtime.subscribeMyAttendance(
      userId: uid,
      onReload: () {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 400), () {
          if (mounted) _load(showSpinner: false);
        });
      },
    );
  }

  (DateTime, DateTime) _visibleBounds() {
    final anchor = DateTime(
      _periodAnchor.year,
      _periodAnchor.month,
      _periodAnchor.day,
    );
    if (_periodKind == 'month') {
      return AppTime.monthBoundsContaining(anchor);
    }
    return AppTime.weekBoundsContaining(anchor);
  }

  void _stepPeriod(int delta) {
    setState(() {
      if (_periodKind == 'month') {
        final m = DateTime(_periodAnchor.year, _periodAnchor.month + delta, 1);
        _periodAnchor = DateTime(m.year, m.month, 1);
      } else {
        _periodAnchor = _periodAnchor.add(Duration(days: 7 * delta));
      }
    });
    _load(showSpinner: true);
  }

  void _jumpToToday() {
    setState(() => _periodAnchor = AppTime.malaysiaDateOnly());
    _load(showSpinner: true);
  }

  String _periodSummaryText() {
    final (start, end) = _visibleBounds();
    if (_periodKind == 'month') {
      return _monthFmt.format(start);
    }
    if (start.year == end.year) {
      return '${_dayShortFmt.format(start)} – ${_dayLongFmt.format(end)}';
    }
    return '${_dayLongFmt.format(start)} – ${_dayLongFmt.format(end)}';
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || _loadingMore) return;
    if (!_hasMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 320) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final uid = context.read<AuthProvider>().user!.id;
      final bounds = _visibleBounds();
      final data = await SupabaseService.getMyAttendanceLog(
        uid,
        fromDate: bounds.$1,
        toDate: bounds.$2,
        limit: _pageSize,
        offset: _nextOffset,
        statusEquals: _statusFilter == 'all' ? null : _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _records.addAll(data);
        _nextOffset += data.length;
        _hasMore = data.length >= _pageSize;
        _loadingMore = false;
      });
      _tryFillAttendanceViewport();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _tryFillAttendanceViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (!_hasMore || _loadingMore || _loading) return;
      final pos = _scrollController.position;
      if (pos.maxScrollExtent < 100) {
        _loadMore();
      }
    });
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner && mounted) {
      setState(() {
        _loading = true;
        _hasMore = true;
        _nextOffset = 0;
      });
    }
    try {
      final uid = context.read<AuthProvider>().user!.id;
      final bounds = _visibleBounds();
      final data = await SupabaseService.getMyAttendanceLog(
        uid,
        fromDate: bounds.$1,
        toDate: bounds.$2,
        limit: _pageSize,
        offset: 0,
        statusEquals: _statusFilter == 'all' ? null : _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _records
          ..clear()
          ..addAll(data);
        _nextOffset = data.length;
        _hasMore = data.length >= _pageSize;
        _loading = false;
        _error = null;
      });
      _tryFillAttendanceViewport();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load attendance history. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = _dateFmt;
    final timeFmt = _timeFmt;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Attendance history'),
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AppColors.danger,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => _load(showSpinner: true),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppFilterBar(
                  chipOptions: const [
                    AppFilterOption(value: 'all', label: 'All'),
                    AppFilterOption(value: 'completed', label: 'Completed'),
                    AppFilterOption(value: 'in_progress', label: 'In progress'),
                    AppFilterOption(value: 'present', label: 'Present'),
                  ],
                  selectedChip: _statusFilter,
                  onChipSelected: (v) {
                    setState(() => _statusFilter = v);
                    _load(showSpinner: true);
                  },
                  extraFilters: [
                    const Text(
                      'Period',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment<String>(
                                value: 'week',
                                label: Text('Week'),
                                icon: Icon(Icons.view_week_rounded, size: 18),
                              ),
                              ButtonSegment<String>(
                                value: 'month',
                                label: Text('Month'),
                                icon: Icon(
                                  Icons.calendar_view_month_rounded,
                                  size: 18,
                                ),
                              ),
                            ],
                            selected: {_periodKind},
                            onSelectionChanged: (s) {
                              setState(() => _periodKind = s.first);
                              _load(showSpinner: true);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: _periodKind == 'week'
                                  ? 'Previous week'
                                  : 'Previous month',
                              onPressed: () => _stepPeriod(-1),
                              icon: const Icon(
                                Icons.chevron_left_rounded,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _periodSummaryText(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: _periodKind == 'week'
                                  ? 'Next week'
                                  : 'Next month',
                              onPressed: () => _stepPeriod(1),
                              icon: const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            TextButton(
                              onPressed: _jumpToToday,
                              child: const Text('Today'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _load(showSpinner: false),
                    child: _records.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 48),
                              EmptyState(
                                icon: Icons.event_note_outlined,
                                title: 'No records',
                                subtitle: _statusFilter == 'all'
                                    ? 'No attendance in this week or month. Try another period or clock in from the Clock tab.'
                                    : 'No rows match this status filter.',
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                            addAutomaticKeepAlives: false,
                            cacheExtent: 450,
                            itemCount:
                                _records.length +
                                ((_loadingMore || _hasMore) ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i >= _records.length) {
                                if (_loadingMore) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox(height: 24);
                              }
                              final r = _records[i];
                              return KeyedSubtree(
                                key: ValueKey<String>(r.id),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  // One clipped, bordered layer per row.
                                  // A nested shadow + separate clip + a
                                  // gradient stripe used to be re-rasterised
                                  // for every visible row while scrolling.
                                  child: Material(
                                    color: AppColors.cardBg,
                                    elevation: 0,
                                    clipBehavior: Clip.antiAlias,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: const BorderSide(
                                        color: AppColors.divider,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const ColoredBox(
                                          color: AppColors.primary,
                                          child: SizedBox(width: 5, height: 72),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(14),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        dateFmt.format(r.date),
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          letterSpacing: -0.2,
                                                        ),
                                                      ),
                                                    ),
                                                    StatusChip.fromStatus(
                                                      r.status,
                                                    ),
                                                  ],
                                                ),
                                                if (r.isHalfDayWorked) ...[
                                                  const SizedBox(height: 8),
                                                  Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: StatusChip(
                                                      label:
                                                          r.sessionShortLabel ??
                                                          'Half day',
                                                      color: AppColors.orange,
                                                    ),
                                                  ),
                                                ],
                                                if (r.workedLabel != null) ...[
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Worked: ${r.workedLabel}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: r.isHalfDayWorked
                                                          ? AppColors.orange
                                                          : AppColors
                                                                .textSecondary,
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 12),
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.login_rounded,
                                                      size: 16,
                                                      color: AppColors.primary,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      r.clockInTime != null
                                                          ? timeFmt.format(
                                                              AppTime.toMalaysia(
                                                                r.clockInTime!,
                                                              ),
                                                            )
                                                          : '—',
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 20),
                                                    Icon(
                                                      Icons.logout_rounded,
                                                      size: 16,
                                                      color:
                                                          r.clockOutTime == null
                                                          ? AppColors.open
                                                          : AppColors.success,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      r.clockOutTime != null
                                                          ? timeFmt.format(
                                                              AppTime.toMalaysia(
                                                                r.clockOutTime!,
                                                              ),
                                                            )
                                                          : '—',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            r.clockOutTime ==
                                                                null
                                                            ? AppColors.open
                                                            : AppColors
                                                                  .textPrimary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (r.location != null &&
                                                    r.location!
                                                        .trim()
                                                        .isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.place_outlined,
                                                        size: 14,
                                                        color:
                                                            AppColors.textHint,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          r.location!,
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            color: AppColors
                                                                .textSecondary,
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
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
    );
  }
}

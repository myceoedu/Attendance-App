import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_theme.dart';
import '../../models/monthly_attendance_summary.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_time.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_bar.dart';
import '../../utils/debouncer.dart';

class MonthlyAttendanceScreen extends StatefulWidget {
  const MonthlyAttendanceScreen({super.key});

  @override
  State<MonthlyAttendanceScreen> createState() =>
      _MonthlyAttendanceScreenState();
}

class _MonthlyAttendanceScreenState extends State<MonthlyAttendanceScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Debouncer _searchDebounce = Debouncer();
  DateTime _selectedMonth = DateTime(
    AppTime.malaysiaNow().year,
    AppTime.malaysiaNow().month,
  );
  List<MonthlyAttendanceSummary> _summaries = [];
  bool _loading = true;
  String? _error;
  String _reviewFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner && mounted) setState(() => _loading = true);
    try {
      final data = await SupabaseService.getMonthlyAttendanceSummaries(
        _selectedMonth,
      );
      if (!mounted) return;
      setState(() {
        _summaries = data;
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

  List<MonthlyAttendanceSummary> get _filteredSummaries {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _summaries.where((summary) {
      if (_reviewFilter == 'clean' && !summary.isClean) {
        return false;
      }
      if (_reviewFilter == 'no_attendance' && !summary.hasNoAttendance) {
        return false;
      }
      if (query.isEmpty) return true;
      return summary.displayName.toLowerCase().contains(query) ||
          summary.username.toLowerCase().contains(query) ||
          summary.email.toLowerCase().contains(query);
    }).toList();
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
    _load();
  }

  bool get _canMoveForward {
    final now = AppTime.malaysiaNow();
    final current = DateTime(now.year, now.month);
    return _selectedMonth.isBefore(current);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSummaries;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Monthly Attendance')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => _load(showSpinner: true),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _monthHeader(),
                          const SizedBox(height: 14),
                          AppFilterBar(
                            searchController: _searchCtrl,
                            onSearchChanged: (_) => _searchDebounce(() {
                              if (mounted) setState(() {});
                            }),
                            searchHint: 'Search employee, username, or email',
                            chipOptions: const [
                              AppFilterOption(value: 'all', label: 'All'),
                              AppFilterOption(value: 'clean', label: 'Clean'),
                              AppFilterOption(
                                value: 'no_attendance',
                                label: 'No Attendance',
                              ),
                            ],
                            selectedChip: _reviewFilter,
                            onChipSelected: (value) {
                              setState(() => _reviewFilter = value);
                            },
                            margin: const EdgeInsets.only(top: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
                      sliver: SliverToBoxAdapter(
                        child: EmptyState(
                          icon: Icons.filter_alt_off,
                          title: 'No employees match the filters',
                          subtitle: 'Try another month or review filter',
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => RepaintBoundary(
                          child: _summaryCard(filtered[index]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _monthHeader() {
    final label = DateFormat('MMMM yyyy').format(_selectedMonth);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppGradients.violet,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.violet.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton.filled(
            onPressed: () => _changeMonth(-1),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.18),
            ),
            icon: const Icon(Icons.chevron_left, color: Colors.white),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Monthly attendance review',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filled(
            onPressed: _canMoveForward ? () => _changeMonth(1) : null,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(
                alpha: _canMoveForward ? 0.18 : 0.08,
              ),
            ),
            icon: const Icon(Icons.chevron_right, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(MonthlyAttendanceSummary summary) {
    final lastAttendance = summary.lastAttendanceDate == null
        ? 'No attendance yet'
        : DateFormat('d MMM yyyy').format(summary.lastAttendanceDate!);
    final badgeColor = switch (summary.reviewState) {
      MonthlyAttendanceReviewState.clean => AppColors.success,
      MonthlyAttendanceReviewState.noAttendance => AppColors.textHint,
    };
    final badgeBg = switch (summary.reviewState) {
      MonthlyAttendanceReviewState.clean => AppColors.successLight.withValues(
        alpha: 0.55,
      ),
      MonthlyAttendanceReviewState.noAttendance =>
        AppColors.surfaceAlt.withValues(alpha: 0.85),
    };
    final avatarBg = switch (summary.reviewState) {
      MonthlyAttendanceReviewState.clean => AppColors.primaryLight,
      MonthlyAttendanceReviewState.noAttendance =>
        AppColors.surfaceAlt.withValues(alpha: 0.9),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: summary.hasNoAttendance ? AppColors.border : AppColors.divider,
        ),
        boxShadow: [
          BoxShadow(
            color:
                (summary.hasNoAttendance
                        ? AppColors.textHint
                        : AppColors.primary)
                    .withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: avatarBg,
                child: Text(
                  summary.displayName[0].toUpperCase(),
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  summary.reviewStateLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricPill(
                Icons.calendar_month_outlined,
                '${summary.completedAttendanceDays} completed',
                AppColors.primary,
              ),
              _metricPill(
                Icons.event_available,
                '${summary.approvedLeaveDays} leave (info)',
                AppColors.leave,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Last attendance: $lastAttendance',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../constants/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../utils/leave_catalog.dart';
import '../../models/app_user.dart';
import '../../models/annual_leave_summary.dart';
import '../../models/leave_request.dart';
import '../../models/payroll_salary_setting.dart';
import '../../services/app_realtime.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_time.dart';
import '../../utils/debouncer.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/leave_audit_history_sheet.dart';
import '../../widgets/leave_attachment_link.dart';
import '../../widgets/app_confirm_dialog.dart';

class LeaveManagementScreen extends StatefulWidget {
  const LeaveManagementScreen({super.key, this.initialEmployeeId});

  /// When set (e.g. from [AdminLeaveEmployeePickerScreen]), starts scoped to this user.
  final String? initialEmployeeId;

  @override
  State<LeaveManagementScreen> createState() => _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends State<LeaveManagementScreen> {
  static const _pageSize = 50;
  static final DateFormat _dateFmt = DateFormat('d MMM yyyy');
  static final DateFormat _submittedFmt = DateFormat('d MMM yyyy · HH:mm');

  static final List<DropdownMenuItem<String>> _leaveTypeMenuItems = [
    const DropdownMenuItem(value: 'all', child: Text('All types')),
    ...LeaveCatalog.orderedAllTypes.map(
      (t) => DropdownMenuItem<String>(
        value: t,
        child: Text(
          LeaveCatalog.displayName(t),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  ];

  List<LeaveRequest> _requests = [];
  Map<String, AnnualLeaveSummary> _annualByUserId = {};
  Map<String, PayrollSalarySetting> _payrollByUserId = {};

  /// Cached filter + status counts (updated by [_recomputeDerived]).
  List<LeaveRequest> _visibleRequests = const [];
  int _pendingCount = 0;
  int _approvedCount = 0;
  int _rejectedCount = 0;
  bool _selectedEmployeeHasRequests = false;
  Map<String, String> _employeeNames = const {};
  List<DropdownMenuItem<String>> _employeeMenuItems = const [];

  /// Calendar year for [_annualByUserId] (Malaysia leave year label).
  int _annualSummaryYear = AppTime.malaysiaNow().year;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String _filter = 'all'; // 'all', 'pending', 'approved', 'rejected'
  String _typeFilter = 'all';
  Timer? _realtimeDebounce;
  RealtimeSubscription? _leaveChannel;
  final TextEditingController _searchCtrl = TextEditingController();
  final Debouncer _searchDebounce = Debouncer();

  /// null = all employees.
  String? _selectedEmployeeId;

  /// First successful load only: if there are pending requests, start on Pending.
  bool _didApplyInitialPendingFilter = false;

  /// Open detail cards (per-card rebuild via ValueNotifier).
  final ValueNotifier<Set<String>> _expandedRequestIds =
      ValueNotifier<Set<String>>(const <String>{});

  @override
  void initState() {
    super.initState();
    _selectedEmployeeId = widget.initialEmployeeId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
      _attachRealtime();
    });
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchCtrl.dispose();
    _expandedRequestIds.dispose();
    _realtimeDebounce?.cancel();
    AppRealtime.disposeChannel(_leaveChannel);
    super.dispose();
  }

  void _attachRealtime() {
    _leaveChannel = AppRealtime.subscribeAdminLeaves(
      onReload: () {
        _realtimeDebounce?.cancel();
        _realtimeDebounce = Timer(const Duration(milliseconds: 400), () {
          if (mounted) _load(showSpinner: false);
        });
      },
    );
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner && mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getLeaveRequestsPage(limit: _pageSize),
        SupabaseService.getAllEmployees(),
        SupabaseService.getPayrollSalarySettings(),
      ]);
      final data = results[0] as List<LeaveRequest>;
      final employees = results[1] as List<AppUser>;
      final payroll = results[2] as List<PayrollSalarySetting>;
      if (!mounted) return;

      final year = AppTime.malaysiaNow().year;
      final ids = data.map((e) => e.userId).toSet().toList();
      Map<String, AnnualLeaveSummary> batch = {};
      try {
        batch = await SupabaseService.getAnnualLeaveSummariesBatch(ids, year);
      } catch (_) {
        batch = {};
      }

      setState(() {
        _requests = data;
        _setEmployees(employees);
        _payrollByUserId = {for (final s in payroll) s.userId: s};
        _annualByUserId = batch;
        _annualSummaryYear = year;
        _loading = false;
        _loadingMore = false;
        _hasMore = data.length == _pageSize;
        _error = null;
        if (_selectedEmployeeId != null &&
            !employees.any((e) => e.id == _selectedEmployeeId)) {
          _selectedEmployeeId = null;
        }
        if (!_didApplyInitialPendingFilter) {
          final pendingN = data.where((l) => l.status == 'pending').length;
          if (pendingN > 0) {
            _filter = 'pending';
          }
          _didApplyInitialPendingFilter = true;
        }
        _recomputeDerived();
      });

      final selected = _selectedEmployeeId;
      if (selected != null) {
        await _ensureAnnualSummaryForUser(selected);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load: $e';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = await SupabaseService.getLeaveRequestsPage(
        offset: _requests.length,
        limit: _pageSize,
      );
      if (!mounted) return;
      final ids = next.map((request) => request.userId).toSet().toList();
      Map<String, AnnualLeaveSummary> summaries = {};
      if (ids.isNotEmpty) {
        try {
          summaries = await SupabaseService.getAnnualLeaveSummariesBatch(
            ids,
            _annualSummaryYear,
          );
        } catch (_) {
          // The page is still useful if optional balance summaries fail.
        }
      }
      if (!mounted) return;
      setState(() {
        _requests = [..._requests, ...next];
        _annualByUserId = {..._annualByUserId, ...summaries};
        _hasMore = next.length == _pageSize;
        _loadingMore = false;
        _recomputeDerived();
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _setEmployees(List<AppUser> employees) {
    _employeeNames = {for (final e in employees) e.id: e.name};
    _employeeMenuItems = [
      const DropdownMenuItem(value: 'all', child: Text('Everyone')),
      ...employees.map(
        (e) => DropdownMenuItem(
          value: e.id,
          child: Text(e.name, overflow: TextOverflow.ellipsis),
        ),
      ),
    ];
  }

  String _employeeNameById(String id) => _employeeNames[id] ?? 'Employee';

  bool _userHasAnnualLeave(String userId) {
    final s = _payrollByUserId[userId];
    if (s == null) return true;
    return s.hasAnnualLeave;
  }

  void _toggleDetails(String requestId) {
    final next = Set<String>.of(_expandedRequestIds.value);
    if (!next.remove(requestId)) next.add(requestId);
    _expandedRequestIds.value = next;
  }

  String _emptyStateSubtitle() {
    final id = _selectedEmployeeId;
    if (id == null) return 'No requests match the selected filters';
    if (!_selectedEmployeeHasRequests) {
      return 'No leave requests on file for ${_employeeNameById(id)} yet. '
          'Their annual snapshot is still shown above.';
    }
    return 'No requests for ${_employeeNameById(id)} match these filters. '
        'Try All statuses or another leave type.';
  }

  Future<void> _ensureAnnualSummaryForUser(String userId) async {
    if (!mounted || _annualByUserId.containsKey(userId)) return;
    try {
      final s = await SupabaseService.getAnnualLeaveSummary(
        userId,
        year: _annualSummaryYear,
      );
      if (!mounted || s == null) return;
      setState(() => _annualByUserId[userId] = s);
    } catch (_) {
      // Leave map empty. Panel shows friendly fallback.
    }
  }

  void _recomputeDerived() {
    final query = _searchCtrl.text.trim().toLowerCase();
    final hasQuery = query.isNotEmpty;
    final employeeId = _selectedEmployeeId;
    final statusAll = _filter == 'all';
    final typeAll = _typeFilter == 'all';

    var pending = 0;
    var approved = 0;
    var rejected = 0;
    var employeeHasRequests = false;
    final visible = <LeaveRequest>[];

    for (final request in _requests) {
      if (employeeId != null && request.userId != employeeId) continue;
      employeeHasRequests = true;

      switch (request.status) {
        case 'pending':
          pending++;
        case 'approved':
          approved++;
        case 'rejected':
          rejected++;
      }

      if (!statusAll && request.status != _filter) continue;
      if (!typeAll && request.leaveType != _typeFilter) continue;
      if (hasQuery) {
        final name = request.userName?.toLowerCase() ?? '';
        if (!name.contains(query) &&
            !request.reason.toLowerCase().contains(query) &&
            !request.leaveTypeDisplay.toLowerCase().contains(query)) {
          continue;
        }
      }
      visible.add(request);
    }

    // Pending: oldest first. Others: newest first.
    if (_filter == 'pending') {
      visible.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else {
      visible.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    _visibleRequests = visible;
    _pendingCount = pending;
    _approvedCount = approved;
    _rejectedCount = rejected;
    _selectedEmployeeHasRequests = employeeId == null
        ? _requests.isNotEmpty
        : employeeHasRequests;
  }

  Future<void> _onApproveTapped(LeaveRequest r) async {
    if (LeaveCatalog.consumesAnnual(r.leaveType) &&
        !_userHasAnnualLeave(r.userId)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Annual leave is for permanent and contract staff only.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    if (LeaveCatalog.consumesAnnual(r.leaveType)) {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) =>
            _AnnualApproveSheet(request: r, dateFmt: DateFormat('d MMM yyyy')),
      );
      if (!mounted || ok != true) return;
    }
    await _updateStatus(r, 'approved');
  }

  Future<void> _updateStatus(LeaveRequest req, String status) async {
    String? comment;
    if (status == 'rejected') {
      comment = await _askComment();
      if (comment == null) return;
    }

    try {
      final removedCount = await SupabaseService.updateLeaveStatus(
        leaveId: req.id,
        status: status,
        adminComment: comment,
      );
      if (!mounted) return;
      await _load(showSpinner: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? removedCount > 0
                      ? 'Leave approved. Removed $removedCount attendance record(s).'
                      : 'Leave approved'
                : 'Leave rejected',
          ),
          backgroundColor: status == 'approved'
              ? AppColors.success
              : AppColors.danger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyAdminLeaveError(e)),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// Dialog owns its [TextEditingController] and disposes it in [State.dispose].
  /// Disposing a controller immediately after [showDialog] returns can crash the
  /// framework (`_dependents.isEmpty`) while the route is still unmounting.
  Future<String?> _askComment() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _RejectCommentDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = _dateFmt;
    final submittedFmt = _submittedFmt;
    final filtered = _visibleRequests;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppChrome.onBrand,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          systemOverlayStyle: AppChrome.onBrand,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.onBrand,
          titleSpacing: 16,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Leave inbox',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                _selectedEmployeeId != null
                    ? _employeeNameById(_selectedEmployeeId!)
                    : 'All employees',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onBrandMuted,
                ),
              ),
            ],
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: AppGradients.adminBrandHeader,
              boxShadow: [
                BoxShadow(
                  color: AppColors.adminHeaderShadow,
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                ),
              ],
            ),
          ),
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
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  _buildCompactFilters(),
                  if (!_loading && _error == null) ...[
                    _selectedEmployeeHero(),
                    _leaveStatsPills(),
                  ],
                  Expanded(
                    child: filtered.isEmpty
                        ? EmptyState(
                            icon: Icons.event_note,
                            title: 'No leave requests',
                            subtitle: _emptyStateSubtitle(),
                          )
                        : RefreshIndicator(
                            onRefresh: () async => _load(showSpinner: true),
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                              addAutomaticKeepAlives: false,
                              cacheExtent: 400,
                              itemCount: filtered.length + (_hasMore ? 1 : 0),
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (_, i) {
                                if (i == filtered.length) {
                                  return OutlinedButton(
                                    onPressed: _loadingMore ? null : _loadMore,
                                    child: _loadingMore
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Load older leave requests',
                                          ),
                                  );
                                }
                                final r = filtered[i];
                                return KeyedSubtree(
                                  key: ValueKey<String>(r.id),
                                  child: _adminLeaveRequestCard(
                                    r,
                                    dateFmt,
                                    submittedFmt,
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCompactFilters() {
    final extraFilters = _selectedEmployeeId != null || _typeFilter != 'all';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _searchDebounce(() {
                if (mounted) setState(_recomputeDerived);
              }),
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Search people or reasons',
                hintStyle: TextStyle(
                  color: AppColors.textHint.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: AppColors.textSecondary.withValues(alpha: 0.85),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primaryDark,
                    width: 1.4,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Badge(
            isLabelVisible: extraFilters,
            smallSize: 8,
            backgroundColor: AppColors.primaryDark,
            child: IconButton.filledTonal(
              tooltip: 'Filters',
              onPressed: _openMoreFilters,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.divider),
                minimumSize: const Size(48, 48),
              ),
              icon: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMoreFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                20 + MediaQuery.paddingOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _compactEmployeeDropdown(onChanged: () => setSheet(() {})),
                  const SizedBox(height: 12),
                  _compactLeaveTypeDropdown(onChanged: () => setSheet(() {})),
                  if (_selectedEmployeeId != null || _typeFilter != 'all') ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedEmployeeId = null;
                          _typeFilter = 'all';
                          _recomputeDerived();
                        });
                        setSheet(() {});
                      },
                      child: const Text('Clear filters'),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _compactEmployeeDropdown({VoidCallback? onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_outline_rounded,
            size: 18,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedEmployeeId ?? 'all',
                isExpanded: true,
                icon: Icon(
                  Icons.expand_more_rounded,
                  color: AppColors.textHint.withValues(alpha: 0.95),
                ),
                items: _employeeMenuItems,
                onChanged: (value) async {
                  if (value == null) return;
                  final id = value == 'all' ? null : value;
                  setState(() {
                    _selectedEmployeeId = id;
                    _recomputeDerived();
                  });
                  onChanged?.call();
                  if (id != null) await _ensureAnnualSummaryForUser(id);
                },
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactLeaveTypeDropdown({VoidCallback? onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.style_outlined,
            size: 18,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _typeFilter,
                isExpanded: true,
                icon: Icon(
                  Icons.expand_more_rounded,
                  color: AppColors.textHint.withValues(alpha: 0.95),
                ),
                items: _leaveTypeMenuItems,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _typeFilter = value;
                    _recomputeDerived();
                  });
                  onChanged?.call();
                },
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaveStatsPills() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: _statPill(
              label: 'Pending',
              value: _pendingCount,
              color: AppColors.warning,
              selected: _filter == 'pending',
              onTap: () => _selectStatusFilter('pending'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statPill(
              label: 'Approved',
              value: _approvedCount,
              color: AppColors.success,
              selected: _filter == 'approved',
              onTap: () => _selectStatusFilter('approved'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statPill(
              label: 'Rejected',
              value: _rejectedCount,
              color: AppColors.danger,
              selected: _filter == 'rejected',
              onTap: () => _selectStatusFilter('rejected'),
            ),
          ),
        ],
      ),
    );
  }

  void _selectStatusFilter(String status) {
    setState(() {
      _filter = _filter == status ? 'all' : status;
      _recomputeDerived();
    });
  }

  Widget _statPill({
    required String label,
    required int value,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: selected
                ? Color.alphaBlend(color.withValues(alpha: 0.14), Colors.white)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.5)
                  : AppColors.divider,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? color : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: -0.5,
                  color: selected ? color : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectedEmployeeHero() {
    final id = _selectedEmployeeId;
    if (id == null) return const SizedBox.shrink();
    if (!_userHasAnnualLeave(id)) return const SizedBox.shrink();
    final name = _employeeNameById(id);
    final s = _annualByUserId[id];
    final y = _annualSummaryYear;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.indigoLight.withValues(alpha: 0.42),
              AppColors.violetLight.withValues(alpha: 0.28),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.indigo.withValues(alpha: 0.1)),
        ),
        child: s == null
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white.withValues(alpha: 0.85),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.indigo,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Balance unavailable for $name. Check leave setup.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.indigo,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.35,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Annual leave · $y · Malaysia',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.9,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _fmtLeaveDays(s.remaining),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1,
                              letterSpacing: -0.6,
                              color: AppColors.indigo,
                            ),
                          ),
                          Text(
                            s.remaining == 1 ? 'day left' : 'days left',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.88,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: s.entitlement > 1e-6
                          ? (s.used / s.entitlement).clamp(0.0, 1.0)
                          : null,
                      minHeight: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.5),
                      color: AppColors.indigo,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_fmtLeaveDays(s.used)} / ${_fmtLeaveDays(s.entitlement)} used'
                    ' · ${_fmtLeaveDays(s.pending)} pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _adminLeaveRequestCard(
    LeaveRequest r,
    DateFormat dateFmt,
    DateFormat submittedFmt,
  ) {
    final showEmployeeHeader = _selectedEmployeeId == null;
    final name = showEmployeeHeader
        ? ((r.userName?.isNotEmpty == true) ? r.userName! : 'Employee')
        : '';
    final initial = showEmployeeHeader && name.isNotEmpty
        ? name[0].toUpperCase()
        : '?';
    final hasAttachment =
        r.attachmentPath != null && r.attachmentPath!.isNotEmpty;
    final sameDay =
        r.startDate.year == r.endDate.year &&
        r.startDate.month == r.endDate.month &&
        r.startDate.day == r.endDate.day;
    final dateLine = sameDay
        ? dateFmt.format(r.startDate)
        : '${dateFmt.format(r.startDate)} – ${dateFmt.format(r.endDate)}';

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _toggleDetails(r.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
              child: ValueListenableBuilder<Set<String>>(
                valueListenable: _expandedRequestIds,
                builder: (context, expandedIds, _) {
                  final expanded = expandedIds.contains(r.id);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showEmployeeHeader) ...[
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.primaryLight,
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  showEmployeeHeader
                                      ? name
                                      : r.leaveTypeDisplay,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.25,
                                    height: 1.2,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  showEmployeeHeader
                                      ? '${r.leaveTypeDisplay} · ${r.durationDisplayLabel}'
                                      : r.durationDisplayLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusChip.fromStatus(r.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        dateLine,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        r.reason,
                        maxLines: expanded ? null : 2,
                        overflow: expanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (hasAttachment)
                            TextButton.icon(
                              onPressed: () => openLeaveAttachment(
                                context,
                                r.attachmentPath,
                              ),
                              icon: const Icon(
                                Icons.attach_file_rounded,
                                size: 18,
                              ),
                              label: const Text('Attachment'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primaryDark,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                              ),
                            ),
                          const Spacer(),
                          Icon(
                            expanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            color: AppColors.textHint,
                          ),
                        ],
                      ),
                      if (expanded) ...[
                        Text(
                          'Submitted ${submittedFmt.format(r.createdAt.toLocal())}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textHint,
                          ),
                        ),
                        _employeeAnnualBalancePanel(r.userId, r.leaveType),
                        if (r.adminComment != null &&
                            r.adminComment!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            r.adminComment!,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => showLeaveAuditHistorySheet(
                              context,
                              leaveRequestId: r.id,
                            ),
                            icon: const Icon(Icons.history, size: 16),
                            label: const Text('History'),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
          if (r.status == 'pending')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateStatus(r, 'rejected'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _onApproveTapped(r),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _fmtLeaveDays(double n) =>
      n == n.roundToDouble() ? '${n.round()}' : n.toStringAsFixed(1);

  /// Compact annual snapshot shown when a card is expanded.
  Widget _employeeAnnualBalancePanel(String userId, String requestLeaveType) {
    if (!_userHasAnnualLeave(userId)) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'Annual leave is for permanent and contract staff only.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: AppColors.textHint,
          ),
        ),
      );
    }
    final s = _annualByUserId[userId];
    if (s == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'Annual balance unavailable for this employee.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: AppColors.textHint,
          ),
        ),
      );
    }

    final usesAnnual = LeaveCatalog.consumesAnnual(requestLeaveType);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        usesAnnual
            ? '${_fmtLeaveDays(s.remaining)} days left · '
                  '${_fmtLeaveDays(s.used)} used of ${_fmtLeaveDays(s.entitlement)}'
                  '${s.pending > 0 ? ' · ${_fmtLeaveDays(s.pending)} pending' : ''}'
            : 'Does not use annual balance · '
                  '${_fmtLeaveDays(s.remaining)} days remaining this year',
        style: const TextStyle(
          fontSize: 12.5,
          height: 1.4,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Confirm annual leave approval: dates, duration, and balance reminder (plan Phase 1).
class _AnnualApproveSheet extends StatelessWidget {
  const _AnnualApproveSheet({required this.request, required this.dateFmt});

  final LeaveRequest request;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final name = (request.userName?.isNotEmpty == true)
        ? request.userName!
        : 'Employee';
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Approve annual leave?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${dateFmt.format(request.startDate)} to ${dateFmt.format(request.endDate)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${request.durationDisplayLabel} · '
            '${request.leaveTypeDisplay}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.skyLight.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.sky.withValues(alpha: 0.35)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: AppColors.sky,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'After approval, these days count against their annual '
                    'balance for this year. Expand details on the card to see '
                    'their balance snapshot.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RejectCommentDialog extends StatefulWidget {
  const _RejectCommentDialog();

  @override
  State<_RejectCommentDialog> createState() => _RejectCommentDialogState();
}

class _RejectCommentDialogState extends State<_RejectCommentDialog> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: AppConfirmPanel(
            title: 'Reject this request?',
            message:
                'The employee may see your note. A short explanation helps them understand the decision.',
            body: TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    'Optional: reason shown to the employee (recommended)',
                alignLabelWithHint: true,
              ),
            ),
            cancelLabel: 'Keep',
            confirmLabel: 'Reject',
            emphasis: AppConfirmEmphasis.confirm,
            confirmColor: AppColors.danger,
            onCancel: () => Navigator.pop<String?>(context),
            onConfirm: () => Navigator.pop(context, _controller.text),
          ),
        ),
      ),
    );
  }
}

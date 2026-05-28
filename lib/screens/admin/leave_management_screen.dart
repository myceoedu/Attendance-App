import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../utils/leave_catalog.dart';
import '../../models/app_user.dart';
import '../../models/annual_leave_summary.dart';
import '../../models/leave_request.dart';
import '../../services/app_realtime.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_time.dart';
import '../../utils/debouncer.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/leave_audit_history_sheet.dart';
import '../../widgets/leave_attachment_link.dart';

class LeaveManagementScreen extends StatefulWidget {
  const LeaveManagementScreen({super.key, this.initialEmployeeId});

  /// When set (e.g. from [AdminLeaveEmployeePickerScreen]), starts scoped to this user.
  final String? initialEmployeeId;

  @override
  State<LeaveManagementScreen> createState() => _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends State<LeaveManagementScreen> {
  List<LeaveRequest> _requests = [];
  Map<String, AnnualLeaveSummary> _annualByUserId = {};
  /// Calendar year for [_annualByUserId] (Malaysia leave year label).
  int _annualSummaryYear = AppTime.malaysiaNow().year;
  bool _loading = true;
  String? _error;
  String _filter = 'all'; // 'all', 'pending', 'approved', 'rejected'
  String _typeFilter = 'all';
  Timer? _realtimeDebounce;
  RealtimeChannel? _leaveChannel;
  final TextEditingController _searchCtrl = TextEditingController();
  final Debouncer _searchDebounce = Debouncer();
  List<AppUser> _employees = [];
  /// `null` = all employees; otherwise filter leaves to this user id.
  String? _selectedEmployeeId;
  /// First successful load only: if there are pending requests, start on Pending.
  bool _didApplyInitialPendingFilter = false;
  final Map<String, bool> _requestDetailExpanded = {};

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
    _realtimeDebounce?.cancel();
    AppRealtime.disposeChannel(_leaveChannel);
    super.dispose();
  }

  void _attachRealtime() {
    _leaveChannel = AppRealtime.subscribeAdminLeaves(
      channelSuffix: 'manage',
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
        SupabaseService.getAllLeaveRequests(),
        SupabaseService.getAllEmployees(),
      ]);
      final data = results[0] as List<LeaveRequest>;
      final employees = results[1] as List<AppUser>;
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
        _employees = employees;
        _annualByUserId = batch;
        _annualSummaryYear = year;
        _loading = false;
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

  String _employeeNameById(String id) {
    for (final e in _employees) {
      if (e.id == id) return e.name;
    }
    return 'Employee';
  }

  String _emptyStateSubtitle() {
    final id = _selectedEmployeeId;
    if (id == null) return 'No requests match the selected filters';
    final hasAny = _requests.any((r) => r.userId == id);
    if (!hasAny) {
      return 'No leave requests on file for ${_employeeNameById(id)} yet. '
          'Their annual snapshot is still shown above.';
    }
    return 'No requests for ${_employeeNameById(id)} match these filters — '
        'try All statuses or another leave type.';
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
      // Leave map empty; panel shows friendly fallback.
    }
  }

  List<LeaveRequest> get _requestsForStats {
    final id = _selectedEmployeeId;
    if (id == null) return _requests;
    return _requests.where((r) => r.userId == id).toList();
  }

  List<LeaveRequest> get _filteredSorted {
    final list = _filteredRaw;
    final sorted = List<LeaveRequest>.from(list);
    if (_filter == 'pending') {
      sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else {
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return sorted;
  }

  List<LeaveRequest> get _filteredRaw {
    final query = _searchCtrl.text.trim().toLowerCase();
    final employeeId = _selectedEmployeeId;
    return _requests.where((request) {
      if (employeeId != null && request.userId != employeeId) return false;
      if (_filter != 'all' && request.status != _filter) return false;
      if (_typeFilter != 'all' && request.leaveType != _typeFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final name = request.userName?.toLowerCase() ?? '';
      return name.contains(query) ||
          request.reason.toLowerCase().contains(query) ||
          request.leaveTypeDisplay.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _onApproveTapped(LeaveRequest r) async {
    if (LeaveCatalog.consumesAnnual(r.leaveType)) {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => _AnnualApproveSheet(
          request: r,
          dateFmt: DateFormat('d MMM yyyy'),
        ),
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
    final dateFmt = DateFormat('d MMM yyyy');
    final submittedFmt = DateFormat('d MMM yyyy · HH:mm');
    final filtered = _filteredSorted;
    final statsScope = _requestsForStats;
    final pendingCount =
        statsScope.where((r) => r.status == 'pending').length;

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
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.35,
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
          actions: [
            if (pendingCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.onBrand.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.brandChipBorder),
                    ),
                    child: Text(
                      '$pendingCount pending',
                      style: const TextStyle(
                        color: AppColors.onBrand,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      body: _loading
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
                _buildCompactFilters(),
                if (!_loading && _error == null) ...[
                  _selectedEmployeeHero(),
                  _leaveStatsPills(),
                  _annualBalanceHelpTile(),
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
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                            addAutomaticKeepAlives: false,
                            cacheExtent: 400,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
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
    const statusItems = <(String, String)>[
      ('all', 'All'),
      ('pending', 'Pending'),
      ('approved', 'Approved'),
      ('rejected', 'Rejected'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (_) =>
                _searchDebounce(() {
                  if (mounted) setState(() {});
                }),
            textInputAction: TextInputAction.search,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Search people, reasons, or leave types',
              hintStyle: TextStyle(
                color: AppColors.textHint.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.textPrimary.withValues(alpha: 0.06),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.indigo,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: statusItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final v = statusItems[i];
                final sel = _filter == v.$1;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _filter = v.$1),
                    borderRadius: BorderRadius.circular(999),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.indigo : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color:
                              sel ? AppColors.indigo : AppColors.divider,
                        ),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                  color: AppColors.indigo.withValues(
                                    alpha: 0.18,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          v.$2,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color:
                                sel ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _compactEmployeeDropdown()),
              const SizedBox(width: 8),
              Expanded(child: _compactLeaveTypeDropdown()),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Text(
              _filterContextHint(),
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _filterContextHint() {
    final order = _filter == 'pending'
        ? 'Queue: oldest pending first'
        : 'Sorted: newest first';
    final type = switch (_typeFilter) {
      'all' => null,
      _ => LeaveCatalog.displayName(_typeFilter),
    };
    if (type != null) return '$order · $type';
    return order;
  }

  Widget _compactEmployeeDropdown() {
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
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('Everyone'),
                  ),
                  ..._employees.map(
                    (e) => DropdownMenuItem(
                      value: e.id,
                      child: Text(
                        e.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) async {
                  if (value == null) return;
                  final id = value == 'all' ? null : value;
                  setState(() => _selectedEmployeeId = id);
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

  Widget _compactLeaveTypeDropdown() {
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
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('All types'),
                  ),
                  ...LeaveCatalog.orderedAllTypes.map(
                    (t) => DropdownMenuItem<String>(
                      value: t,
                      child: Text(
                        LeaveCatalog.displayName(t),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _typeFilter = value);
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
    final scope = _requestsForStats;
    final pending = scope.where((r) => r.status == 'pending').length;
    final approved = scope.where((r) => r.status == 'approved').length;
    final rejected = scope.where((r) => r.status == 'rejected').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _statPill(
              label: 'Pending',
              value: pending,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _statPill(
              label: 'Approved',
              value: approved,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _statPill(
              label: 'Rejected',
              value: rejected,
              color: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statPill({
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.1),
          Colors.white,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.35,
              color: color.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: -0.4,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedEmployeeHero() {
    final id = _selectedEmployeeId;
    if (id == null) return const SizedBox.shrink();
    final name = _employeeNameById(id);
    final s = _annualByUserId[id];
    final y = _annualSummaryYear;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
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
          border: Border.all(
            color: AppColors.indigo.withValues(alpha: 0.1),
          ),
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
                      'Balance unavailable for $name — check leave setup.',
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
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.9),
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
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.88),
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

  Widget _annualBalanceHelpTile() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          visualDensity: VisualDensity.compact,
          dense: true,
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 16,
                color: AppColors.sky.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Why annual balance shows on cards',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary.withValues(alpha: 0.88),
                  ),
                ),
              ),
            ],
          ),
          children: [
            Text(
              'Each request can show that employee’s $_annualSummaryYear annual '
              'totals — even for sick or emergency — so you can sanity-check '
              'entitlement while you review.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _adminLeaveTypeAccent(String type) =>
      LeaveCatalog.uiStyle(type).color;

  static IconData _adminLeaveTypeIcon(String type) =>
      LeaveCatalog.uiStyle(type).icon;

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
    final typeAccent = _adminLeaveTypeAccent(r.leaveType);
    final typeIcon = _adminLeaveTypeIcon(r.leaveType);
    final detailsExpanded = _requestDetailExpanded[r.id] ?? false;
    final hasMc = LeaveCatalog.requiresMcAttachment(r.leaveType) &&
        r.attachmentPath != null &&
        r.attachmentPath!.isNotEmpty;

    Widget attachmentRow =
        LeaveAttachmentRow(attachmentPath: r.attachmentPath);
    if (hasMc) {
      attachmentRow = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.pink.withValues(alpha: 0.45)),
          color: AppColors.pinkLight.withValues(alpha: 0.35),
        ),
        child: attachmentRow,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.045),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: typeAccent,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(20),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: typeAccent.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  typeIcon,
                                  size: 22,
                                  color: typeAccent,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.leaveTypeDisplay,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                        height: 1.15,
                                        color: Color.lerp(
                                          typeAccent,
                                          AppColors.textPrimary,
                                          0.38,
                                        ),
                                      ),
                                    ),
                                    if (showEmployeeHeader) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 15,
                                            backgroundColor:
                                                AppColors.primaryLight,
                                            child: Text(
                                              initial,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.primary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              StatusChip.fromStatus(r.status),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 15,
                                color:
                                    AppColors.textSecondary.withValues(alpha: 0.85),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${dateFmt.format(r.startDate)} — '
                                  '${dateFmt.format(r.endDate)} · '
                                  '${r.durationDisplayLabel}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1.35,
                                    color: AppColors.textSecondary
                                        .withValues(alpha: 0.95),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Submitted ${submittedFmt.format(r.createdAt.toLocal())}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHint.withValues(alpha: 0.92),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                            decoration: BoxDecoration(
                              color: typeAccent.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: typeAccent.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.notes_rounded,
                                      size: 14,
                                      color: typeAccent.withValues(alpha: 0.9),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Reason',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.88),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  r.reason,
                                  maxLines: detailsExpanded ? null : 2,
                                  overflow: detailsExpanded
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!detailsExpanded && hasMc) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.attach_file_rounded,
                                  size: 16,
                                  color: AppColors.pink,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'MC / attachment on file — tap Details to open.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1.3,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.pink
                                          .withValues(alpha: 0.92),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => setState(() {
                                _requestDetailExpanded[r.id] =
                                    !detailsExpanded;
                              }),
                              icon: Icon(
                                detailsExpanded
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                                size: 20,
                              ),
                              label: Text(
                                detailsExpanded
                                    ? 'Hide details'
                                    : 'Details',
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.indigo,
                                minimumSize: const Size(0, 44),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                              ),
                            ),
                          ),
                          if (detailsExpanded) ...[
                            _employeeAnnualBalancePanel(
                              r.userId,
                              r.leaveType,
                            ),
                            attachmentRow,
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () => showLeaveAuditHistorySheet(
                                  context,
                                  leaveRequestId: r.id,
                                ),
                                icon: const Icon(Icons.history, size: 16),
                                label: const Text('Audit history'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                            if (r.adminComment != null &&
                                r.adminComment!.isNotEmpty) ...[
                              const Divider(height: 20),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.comment_outlined,
                                    size: 15,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      r.adminComment!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: AppColors.textSecondary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (r.status == 'pending')
              Material(
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _updateStatus(r, 'rejected'),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _onApproveTapped(r),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Approve'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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

  String _fmtLeaveDays(double n) =>
      n == n.roundToDouble() ? '${n.round()}' : n.toStringAsFixed(1);

  /// Annual entitlement snapshot for the employee on this card (all leave types).
  Widget _employeeAnnualBalancePanel(String userId, String requestLeaveType) {
    final s = _annualByUserId[userId];
    final y = _annualSummaryYear;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.sky.withValues(alpha: 0.22),
          ),
        ),
        child: s == null
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Annual balance could not be loaded for this employee. '
                      'Check that annual leave is enabled in Supabase for their account.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.sky.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.savings_outlined,
                          size: 18,
                          color: AppColors.sky,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Annual leave balance',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Leave year $y · Malaysia calendar',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textHint.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (requestLeaveType != 'annual') ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Text(
                        'This request is not annual leave — it does not use the '
                        'remaining days above. The numbers are for context only.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _fmtLeaveDays(s.remaining),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: AppColors.primary,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          s.remaining == 1 ? 'day left' : 'days left',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _balanceMiniPill(
                        Icons.done_all_rounded,
                        '${_fmtLeaveDays(s.used)} used',
                        AppColors.textSecondary,
                      ),
                      _balanceMiniPill(
                        Icons.hourglass_top_rounded,
                        '${_fmtLeaveDays(s.pending)} pending',
                        AppColors.warning,
                      ),
                      _balanceMiniPill(
                        Icons.flag_outlined,
                        '${_fmtLeaveDays(s.entitlement)} entitled',
                        AppColors.sky,
                      ),
                    ],
                  ),
                  if (s.entitlement > 1e-6) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: (s.used / s.entitlement).clamp(0.0, 1.0),
                        minHeight: 7,
                        backgroundColor: AppColors.surface,
                        color: AppColors.sky,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_fmtLeaveDays(s.used)} of ${_fmtLeaveDays(s.entitlement)} entitlement used '
                      '(remaining ${_fmtLeaveDays(s.remaining)})',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHint,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  static Widget _balanceMiniPill(
    IconData icon,
    String text,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

}

/// Confirm annual leave approval: dates, duration, and balance reminder (plan Phase 1).
class _AnnualApproveSheet extends StatelessWidget {
  const _AnnualApproveSheet({
    required this.request,
    required this.dateFmt,
  });

  final LeaveRequest request;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final name =
        (request.userName?.isNotEmpty == true) ? request.userName! : 'Employee';
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
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${dateFmt.format(request.startDate)} — ${dateFmt.format(request.endDate)}',
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
              border:
                  Border.all(color: AppColors.sky.withValues(alpha: 0.35)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 20, color: AppColors.sky),
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Reject this request?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The employee may see your note on this leave request. A short '
            'explanation helps them understand the decision.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText:
                  'Optional: reason shown to the employee (recommended)',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop<String?>(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('Reject leave'),
        ),
      ],
    );
  }
}

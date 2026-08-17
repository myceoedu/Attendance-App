import 'dart:async';
import '../../utils/app_route.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/annual_leave_summary.dart';
import '../../models/leave_request.dart';
import '../../services/app_realtime.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_time.dart';
import '../../utils/async_load_guard.dart';
import '../../utils/leave_catalog.dart';
import '../../utils/error_messages.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/leave_audit_history_sheet.dart';
import '../../widgets/leave_attachment_link.dart';
import '../../widgets/app_confirm_dialog.dart';
import 'apply_leave_screen.dart';

enum _LeaveHomeSection { annual, other }

/// Employee leave home: **Annual** (balance + history incl. half-days) and **Other**
/// (sick, unpaid, statutory, etc.).
class LeaveTab extends StatefulWidget {
  const LeaveTab({super.key});

  @override
  State<LeaveTab> createState() => _LeaveTabState();
}

class _LeaveTabState extends State<LeaveTab> {
  static const int _pageSize = 40;
  static final DateFormat _dateFmt = DateFormat('d MMM yyyy');
  static final DateFormat _submittedFmt = DateFormat('d MMM yyyy · HH:mm');

  List<LeaveRequest> _requests = [];
  int _nextOffset = 0;
  bool _hasMore = true;
  bool _loadingMore = false;

  AnnualLeaveSummary? _summary;
  int _leaveYear = AppTime.malaysiaNow().year;
  bool _loading = true;
  String? _error;
  Timer? _realtimeDebounce;
  RealtimeSubscription? _leaveChannel;
  String _statusFilter = 'all';
  _LeaveHomeSection _section = _LeaveHomeSection.annual;
  String _otherTypeFilter = 'all';
  bool _annualEligible = true;
  String? _deletingId;
  late final ScrollController _listScrollController;
  final _loadGuard = AsyncLoadGuard();
  final ValueNotifier<Set<String>> _expandedRequestIds =
      ValueNotifier<Set<String>>(const <String>{});

  List<String> get _queryLeaveTypes {
    if (_section == _LeaveHomeSection.annual) {
      return const [
        LeaveCatalog.annual,
        LeaveCatalog.annualHalfAm,
        LeaveCatalog.annualHalfPm,
      ];
    }
    if (_otherTypeFilter == 'all') {
      return List<String>.from(LeaveCatalog.orderedOtherTypes);
    }
    return <String>[_otherTypeFilter];
  }

  @override
  void initState() {
    super.initState();
    _listScrollController = ScrollController()..addListener(_onLeaveListScroll);
    _leaveYear = AppTime.malaysiaNow().year;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
      _attachRealtime();
    });
  }

  @override
  void dispose() {
    _loadGuard.invalidate();
    _listScrollController.removeListener(_onLeaveListScroll);
    _listScrollController.dispose();
    _expandedRequestIds.dispose();
    _realtimeDebounce?.cancel();
    AppRealtime.disposeChannel(_leaveChannel);
    super.dispose();
  }

  void _onLeaveListScroll() {
    if (!_listScrollController.hasClients || _loading || _loadingMore) {
      return;
    }
    if (!_hasMore) return;
    final pos = _listScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 380) {
      _loadMoreLeaveRequests();
    }
  }

  void _tryFillLeaveViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_listScrollController.hasClients) return;
      if (!_hasMore || _loadingMore || _loading) return;
      final pos = _listScrollController.position;
      if (pos.maxScrollExtent < 100) {
        _loadMoreLeaveRequests();
      }
    });
  }

  Future<void> _loadMoreLeaveRequests() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final uid = context.read<AuthProvider>().user!.id;
      final page = await SupabaseService.getMyLeaveRequestsPage(
        uid,
        offset: _nextOffset,
        limit: _pageSize,
        leaveTypes: _queryLeaveTypes,
        statusEquals: _statusFilter == 'all' ? null : _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _requests = [..._requests, ...page];
        _nextOffset += page.length;
        _hasMore = page.length >= _pageSize;
        _loadingMore = false;
      });
      _tryFillLeaveViewport();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _reloadLeaveListFromFilters() async {
    if (_loading) return;
    setState(() {
      _requests = [];
      _nextOffset = 0;
      _hasMore = true;
      _loadingMore = false;
      _error = null;
    });
    try {
      final uid = context.read<AuthProvider>().user!.id;
      final page = await SupabaseService.getMyLeaveRequestsPage(
        uid,
        offset: 0,
        limit: _pageSize,
        leaveTypes: _queryLeaveTypes,
        statusEquals: _statusFilter == 'all' ? null : _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _requests = page;
        _nextOffset = page.length;
        _hasMore = page.length >= _pageSize;
      });
      _tryFillLeaveViewport();
    } catch (_) {
      if (!mounted) return;
    }
  }

  void _attachRealtime() {
    final uid = context.read<AuthProvider>().user?.id;
    if (uid == null) return;
    _leaveChannel = AppRealtime.subscribeMyLeaves(
      userId: uid,
      onReload: () {
        _realtimeDebounce?.cancel();
        _realtimeDebounce = Timer(const Duration(milliseconds: 400), () {
          if (mounted) _load(showSpinner: false);
        });
      },
    );
  }

  Future<void> _load({bool showSpinner = true}) async {
    final gen = _loadGuard.begin();
    if (showSpinner && mounted) setState(() => _loading = true);
    try {
      final uid = context.read<AuthProvider>().user!.id;
      final year = AppTime.malaysiaNow().year;
      final eligible = await SupabaseService.userHasAnnualLeave(uid);
      if (!mounted || !_loadGuard.isCurrent(gen)) return;
      if (!eligible) {
        _section = _LeaveHomeSection.other;
      }

      final results = await Future.wait<Object?>([
        if (eligible)
          SupabaseService.getAnnualLeaveSummary(uid, year: year)
        else
          Future<AnnualLeaveSummary?>.value(null),
        SupabaseService.getMyLeaveRequestsPage(
          uid,
          offset: 0,
          limit: _pageSize,
          leaveTypes: _queryLeaveTypes,
          statusEquals: _statusFilter == 'all' ? null : _statusFilter,
        ),
      ]);
      if (!mounted || !_loadGuard.isCurrent(gen)) return;
      final page = results[1] as List<LeaveRequest>;
      setState(() {
        _annualEligible = eligible;
        _summary = results[0] as AnnualLeaveSummary?;
        _leaveYear = year;
        _requests = page;
        _nextOffset = page.length;
        _hasMore = page.length >= _pageSize;
        _loading = false;
        _error = null;
      });
      _tryFillLeaveViewport();
    } catch (e) {
      if (!mounted || !_loadGuard.isCurrent(gen)) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load: $e';
      });
    }
  }

  Future<void> _openApply() async {
    await pushAppPage(
      context,
      _section == _LeaveHomeSection.annual && _annualEligible
          ? const ApplyLeaveScreen(annualOnly: true)
          : const ApplyLeaveScreen(otherLeaveOnly: true),
    );
    if (mounted) _load(showSpinner: true);
  }

  void _toggleDetails(String requestId) {
    final next = Set<String>.of(_expandedRequestIds.value);
    if (!next.remove(requestId)) next.add(requestId);
    _expandedRequestIds.value = next;
  }

  Future<void> _confirmDelete(LeaveRequest r) async {
    if (r.status != 'pending' || _deletingId != null) return;
    final ok = await showAppConfirmDialog(
      context: context,
      title: 'Delete this leave request?',
      message:
          'This removes the request and any attached MC. '
          'You can apply again with the correct dates, reason, or file.',
      cancelLabel: 'Keep',
      confirmLabel: 'Delete',
      emphasis: AppConfirmEmphasis.safe,
      confirmColor: AppColors.danger,
    );
    if (ok == true && mounted) await _deletePending(r);
  }

  Future<void> _deletePending(LeaveRequest r) async {
    if (_deletingId != null) return;
    setState(() => _deletingId = r.id);
    try {
      await SupabaseService.deleteMyPendingLeave(r.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave request deleted. You can apply again.'),
          backgroundColor: AppColors.success,
        ),
      );
      await _load(showSpinner: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyLeaveError(e)),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = _dateFmt;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Leave'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Tooltip(
                message: _section == _LeaveHomeSection.annual && _annualEligible
                    ? 'Apply for annual leave'
                    : 'Apply for leave',
                child: SizedBox(
                  height: 32,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _openApply,
                    icon: const Icon(Icons.add_rounded, size: 14),
                    label: const Text(
                      'Apply',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: AppColors.onBrand,
                      disabledBackgroundColor: AppColors.primaryDark.withValues(
                        alpha: 0.75,
                      ),
                      disabledForegroundColor: AppColors.onBrand,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
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
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => _load(showSpinner: true),
              child: CustomScrollView(
                controller: _listScrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                cacheExtent: 480,
                slivers: [
                  if (_annualEligible)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: SegmentedButton<_LeaveHomeSection>(
                          style: SegmentedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.textPrimary,
                            selectedForegroundColor: AppColors.onBrand,
                            selectedBackgroundColor: AppColors.primaryDark,
                            side: const BorderSide(color: AppColors.divider),
                          ),
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: _LeaveHomeSection.annual,
                              label: Text('Annual'),
                            ),
                            ButtonSegment(
                              value: _LeaveHomeSection.other,
                              label: Text('Other'),
                            ),
                          ],
                          selected: {_section},
                          onSelectionChanged: (next) {
                            setState(() => _section = next.first);
                            if (!_loading) {
                              unawaited(_reloadLeaveListFromFilters());
                            }
                          },
                        ),
                      ),
                    ),
                  if (_annualEligible && _section == _LeaveHomeSection.annual)
                    SliverToBoxAdapter(child: _annualDashboard())
                  else
                    SliverToBoxAdapter(child: _otherLeaveIntroCard()),
                  SliverToBoxAdapter(child: _leaveFilterStrip()),
                  if (_requests.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: EmptyState(
                            icon: _section == _LeaveHomeSection.annual
                                ? Icons.event_available_outlined
                                : Icons.healing_outlined,
                            title: _emptyTitle(),
                            subtitle: _emptySubtitle(),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            if (i >= _requests.length) {
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
                              return const SizedBox(height: 16);
                            }
                            final r = _requests[i];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: i < _requests.length - 1 ? 10 : 0,
                              ),
                              child: KeyedSubtree(
                                key: ValueKey<String>(r.id),
                                child: _leaveRequestTile(r, dateFmt),
                              ),
                            );
                          },
                          childCount:
                              _requests.length +
                              ((_loadingMore || _hasMore) ? 1 : 0),
                          addAutomaticKeepAlives: false,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _leaveFilterStrip() {
    const options = <({String value, String label})>[
      (value: 'all', label: 'All'),
      (value: 'pending', label: 'Pending'),
      (value: 'approved', label: 'Approved'),
      (value: 'rejected', label: 'Rejected'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                ChoiceChip(
                  label: Text(o.label),
                  selected: _statusFilter == o.value,
                  onSelected: (_) {
                    setState(() => _statusFilter = o.value);
                    if (!_loading) unawaited(_reloadLeaveListFromFilters());
                  },
                  selectedColor: AppColors.primaryLight,
                  backgroundColor: Colors.white,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(
                    color: _statusFilter == o.value
                        ? AppColors.primaryDark
                        : AppColors.divider,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    color: _statusFilter == o.value
                        ? AppColors.primaryDark
                        : AppColors.textSecondary,
                    fontWeight: _statusFilter == o.value
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
            ],
          ),
          if (_section == _LeaveHomeSection.other) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey<String>(_otherTypeFilter),
              initialValue: _otherTypeFilter,
              isDense: true,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: 'Leave type',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
              ),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All types')),
                ...LeaveCatalog.orderedOtherTypes.map(
                  (t) => DropdownMenuItem(
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
                setState(() => _otherTypeFilter = value);
                if (!_loading) unawaited(_reloadLeaveListFromFilters());
              },
            ),
          ],
        ],
      ),
    );
  }

  String _emptyTitle() {
    if (!_annualEligible) return 'No leave matches filters';
    if (_section == _LeaveHomeSection.annual) {
      return 'No annual leave matches filters';
    }
    return 'No other leave matches filters';
  }

  String _emptySubtitle() {
    if (_section == _LeaveHomeSection.annual) {
      return 'Try another status filter, or tap Apply to request days off.';
    }
    return 'Change type or status filter, or tap Apply to submit a request.';
  }

  Widget _otherLeaveIntroCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Text(
        _annualEligible
            ? 'Sick, emergency, unpaid, and statutory leave. These do not use your annual balance.'
            : 'Interns use sick, unpaid, and other leave. Annual leave is for permanent and contract staff only.',
        style: const TextStyle(
          fontSize: 13.5,
          height: 1.45,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _leaveRequestTile(LeaveRequest r, DateFormat dateFmt) {
    final submittedFmt = _submittedFmt;
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
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _toggleDetails(r.id),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.leaveTypeDisplay,
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
                                '$dateLine · ${r.durationDisplayLabel}',
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
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (hasAttachment)
                          TextButton.icon(
                            onPressed: () =>
                                openLeaveAttachment(context, r.attachmentPath),
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
                    if (r.status == 'pending') ...[
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _deletingId == r.id
                            ? null
                            : () => _confirmDelete(r),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _deletingId == r.id ? 'Deleting…' : 'Delete request',
                        ),
                      ),
                    ],
                    if (expanded) ...[
                      Text(
                        'Submitted ${submittedFmt.format(r.createdAt.toLocal())}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textHint,
                        ),
                      ),
                      if (r.adminComment != null &&
                          r.adminComment!.isNotEmpty) ...[
                        const SizedBox(height: 8),
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
      ),
    );
  }

  Widget _annualDashboard() {
    final s = _summary;
    final used = s?.used;
    final ent = s?.entitlement;
    final rem = s?.remaining;
    String fmt(double? n) {
      if (n == null) return '—';
      return n == n.roundToDouble() ? '${n.round()}' : n.toString();
    }

    final remStr = fmt(rem);
    final usedStr = fmt(used);
    final entStr = fmt(ent);
    final pendStr = fmt(s?.pending);
    final entVal = ent;
    final usedVal = used ?? 0.0;
    final usedRatio = (entVal != null && entVal > 0)
        ? (usedVal / entVal).clamp(0.0, 1.0)
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leave year $_leaveYear',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                remStr,
                style: const TextStyle(
                  fontSize: 36,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'days left',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (usedRatio != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: usedRatio,
                minHeight: 4,
                backgroundColor: AppColors.divider,
                color: AppColors.primaryDark,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '$usedStr used of $entStr'
            '${s != null && s.pending > 0 ? ' · $pendStr pending' : ''}',
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

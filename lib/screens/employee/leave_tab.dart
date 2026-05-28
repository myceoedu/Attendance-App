import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/annual_leave_summary.dart';
import '../../models/leave_request.dart';
import '../../services/app_realtime.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_time.dart';
import '../../utils/leave_catalog.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/leave_audit_history_sheet.dart';
import '../../widgets/leave_attachment_link.dart';
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

  List<LeaveRequest> _requests = [];
  int _nextOffset = 0;
  bool _hasMore = true;
  bool _loadingMore = false;

  AnnualLeaveSummary? _summary;
  int _leaveYear = AppTime.malaysiaNow().year;
  bool _loading = true;
  String? _error;
  Timer? _realtimeDebounce;
  RealtimeChannel? _leaveChannel;
  String _statusFilter = 'all';
  _LeaveHomeSection _section = _LeaveHomeSection.annual;
  String _otherTypeFilter = 'all';
  late final ScrollController _listScrollController;

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
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachRealtime());
  }

  @override
  void dispose() {
    _listScrollController.removeListener(_onLeaveListScroll);
    _listScrollController.dispose();
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
      channelSuffix: 'tab',
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
      final uid = context.read<AuthProvider>().user!.id;
      final year = AppTime.malaysiaNow().year;

      final results = await Future.wait<Object?>([
        SupabaseService.getAnnualLeaveSummary(uid, year: year),
        SupabaseService.getMyLeaveRequestsPage(
          uid,
          offset: 0,
          limit: _pageSize,
          leaveTypes: _queryLeaveTypes,
          statusEquals: _statusFilter == 'all' ? null : _statusFilter,
        ),
      ]);
      if (!mounted) return;
      final page = results[1] as List<LeaveRequest>;
      setState(() {
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
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load: $e';
      });
    }
  }

  Future<void> _openApply() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _section == _LeaveHomeSection.annual
            ? const ApplyLeaveScreen(annualOnly: true)
            : const ApplyLeaveScreen(otherLeaveOnly: true),
      ),
    );
    if (mounted) _load(showSpinner: true);
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy');

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Leave'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Tooltip(
              message: _section == _LeaveHomeSection.annual
                  ? 'Apply for annual leave'
                  : 'Apply for other leave',
              child: FilledButton.icon(
                onPressed: _loading ? null : _openApply,
                icon: const Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: AppColors.onBrand,
                ),
                label: Text(
                  _section == _LeaveHomeSection.annual
                      ? 'Apply annual'
                      : 'Apply other',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: AppColors.onBrand,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: AppColors.onBrand,
                  disabledBackgroundColor: AppColors.primaryDark.withValues(
                    alpha: 0.45,
                  ),
                  disabledForegroundColor: AppColors.onBrand.withValues(
                    alpha: 0.7,
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.only(
                    left: 8,
                    right: 10,
                    top: 5,
                    bottom: 5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: SegmentedButton<_LeaveHomeSection>(
                                  style: SegmentedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppColors.textPrimary,
                                    selectedForegroundColor: AppColors.onBrand,
                                    selectedBackgroundColor:
                                        AppColors.primaryDark,
                                    side: const BorderSide(
                                      color: AppColors.divider,
                                    ),
                                  ),
                                  showSelectedIcon: false,
                                  segments: const [
                                    ButtonSegment(
                                      value: _LeaveHomeSection.annual,
                                      label: Text('Annual'),
                                      tooltip: 'Annual leave balance & history',
                                      icon: Icon(
                                        Icons.beach_access_rounded,
                                        size: 16,
                                      ),
                                    ),
                                    ButtonSegment(
                                      value: _LeaveHomeSection.other,
                                      label: Text('Other'),
                                      tooltip:
                                          'Sick, unpaid, maternity, marriage, PH, etc.',
                                      icon: Icon(
                                        Icons.folder_shared_rounded,
                                        size: 16,
                                      ),
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
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: _section == _LeaveHomeSection.annual
                                    ? 'Annual leave: dates, reason, optional proof. Days count once approved.'
                                    : 'Other leave: sick MC, emergency, unpaid, statutory — separate from annual balance.',
                                onPressed: () {
                                  showModalBottomSheet<void>(
                                    context: context,
                                    showDragHandle: true,
                                    builder: (ctx) => Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        8,
                                        20,
                                        24,
                                      ),
                                      child: Text(
                                        _section == _LeaveHomeSection.annual
                                            ? 'You submit dates, reason, and optional proof. Days count against your annual balance once approved.'
                                            : 'Other leave uses separate policies (sick MC, unpaid payroll, maternity/paternity/marriage/PH replacement, etc.). These types do not use your annual leave balance.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.45,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary
                                              .withValues(alpha: 0.92),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.info_outline_rounded,
                                  size: 22,
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_section == _LeaveHomeSection.annual)
                    SliverToBoxAdapter(child: _annualDashboard(context))
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
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
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

    Widget statusChip(String value, String label) {
      final selected = _statusFilter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) {
            setState(() => _statusFilter = value);
            if (!_loading) unawaited(_reloadLeaveListFromFilters());
          },
          selectedColor: AppColors.primaryLight,
          backgroundColor: AppColors.surface,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          labelStyle: TextStyle(
            fontSize: 12,
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [for (final o in options) statusChip(o.value, o.label)],
            ),
          ),
          if (_section == _LeaveHomeSection.other) ...[
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              key: ValueKey<String>(_otherTypeFilter),
              initialValue: _otherTypeFilter,
              isDense: true,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Leave type',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
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
    if (_section == _LeaveHomeSection.annual) {
      return 'No annual leave matches filters';
    }
    return 'No other leave matches filters';
  }

  String _emptySubtitle() {
    if (_section == _LeaveHomeSection.annual) {
      return 'Try another status filter, or tap Apply annual to request days off.';
    }
    return 'Change type or status filter, or tap Apply other to submit a request.';
  }

  Widget _otherLeaveIntroCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.divider),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 2,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.tealLight.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: AppColors.teal,
                size: 18,
              ),
            ),
            title: const Text(
              'Other leave policies',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Sick, emergency, unpaid, statutory… tap to expand',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary.withValues(alpha: 0.92),
              ),
            ),
            children: [
              _introBullet(
                Icons.medical_services_rounded,
                AppColors.pink,
                'Sick leave — describe your situation and attach an MC or doctor’s note (required).',
              ),
              const SizedBox(height: 6),
              _introBullet(
                Icons.warning_amber_rounded,
                AppColors.orange,
                'Emergency leave — urgent personal matters; attach proof if you can.',
              ),
              const SizedBox(height: 6),
              _introBullet(
                Icons.payments_outlined,
                AppColors.textSecondary,
                'Unpaid leave — may reduce pay for those days in payroll.',
              ),
              const SizedBox(height: 6),
              _introBullet(
                Icons.family_restroom_rounded,
                AppColors.primary,
                'Maternity, paternity, marriage, PH replacement — clear dates and optional documents.',
              ),
              const SizedBox(height: 8),
              Text(
                'These types do not use your annual leave balance.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: AppColors.textSecondary.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _introBullet(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _leaveRequestTile(LeaveRequest r, DateFormat dateFmt) {
    final accent = _leaveAccent(r.leaveType);
    final submittedFmt = DateFormat('d MMM yyyy · HH:mm');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppLayout.cardRadiusLg),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppElevation.cardOnSurface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppLayout.cardRadiusLg),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _leaveTypeIcon(r.leaveType),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.leaveTypeDisplay,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Submitted ${submittedFmt.format(r.createdAt.toLocal())}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusChip.fromStatus(r.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _detailTag(
                            icon: Icons.calendar_today_outlined,
                            label:
                                '${dateFmt.format(r.startDate)} – ${dateFmt.format(r.endDate)}',
                          ),
                          _detailTag(
                            icon: Icons.timelapse_outlined,
                            label: r.durationDisplayLabel,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Text(
                          r.reason,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      LeaveAttachmentRow(attachmentPath: r.attachmentPath),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => showLeaveAuditHistorySheet(
                            context,
                            leaveRequestId: r.id,
                          ),
                          icon: const Icon(Icons.history, size: 16),
                          label: const Text('History'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 38),
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
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                r.adminComment!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.textSecondary,
                                ),
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
  }

  static Color _leaveAccent(String type) => LeaveCatalog.uiStyle(type).color;

  static Widget _leaveTypeIcon(String type) {
    final st = LeaveCatalog.uiStyle(type);
    final color = st.color;
    final icon = st.icon;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 18, color: Colors.white),
    );
  }

  Widget _annualDashboard(BuildContext context) {
    final s = _summary;
    final used = s?.used;
    final ent = s?.entitlement;
    final usedHeroStr = used == null
        ? '—'
        : used == used.roundToDouble()
        ? '${used.round()}'
        : used.toString();
    final entStr = ent == null
        ? '—'
        : ent == ent.roundToDouble()
        ? '${ent.round()}'
        : ent.toString();

    final rem = s?.remaining;
    final remStr = rem == null
        ? '—'
        : rem == rem.roundToDouble()
        ? '${rem.round()}'
        : rem.toString();
    final pendStr = s?.pending == null
        ? '—'
        : s!.pending == s.pending.roundToDouble()
        ? '${s.pending.round()}'
        : s.pending.toString();

    final entVal = ent;
    final usedVal = used ?? 0.0;
    final usedRatio = (entVal != null && entVal > 0)
        ? (usedVal / entVal).clamp(0.0, 1.0)
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
          boxShadow: AppElevation.cardOnSurface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppGradients.sky,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.sky.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.beach_access_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: usedHeroStr,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.05,
                                color: AppColors.primary,
                              ),
                            ),
                            TextSpan(
                              text: ' / $entStr',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                height: 1.05,
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.88,
                                ),
                              ),
                            ),
                            const TextSpan(
                              text: ' days',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Used / entitlement · Rem $remStr · Pend $pendStr',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.95,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (usedRatio != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: usedRatio,
                  minHeight: 5,
                  backgroundColor: AppColors.surface,
                  color: AppColors.primary,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Leave year $_leaveYear (Malaysia calendar)',
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.textHint.withValues(alpha: 0.95),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailTag({required IconData icon, required String label}) {
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
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

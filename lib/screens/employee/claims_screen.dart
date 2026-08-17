import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/app_theme.dart';
import '../../models/expense_claim.dart';
import '../../providers/auth_provider.dart';
import '../../services/app_realtime.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_route.dart';
import '../../utils/async_load_guard.dart';
import '../../utils/error_messages.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/filter_bar.dart';
import 'claim_detail_screen.dart';
import 'submit_claim_screen.dart';

/// Employee: list expense / reimbursement claims and submit new ones.
class ClaimsScreen extends StatefulWidget {
  const ClaimsScreen({super.key});

  @override
  State<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends State<ClaimsScreen> {
  static const int _pageSize = 40;
  static final NumberFormat _moneyFmt = NumberFormat('#,##0.00');
  static final DateFormat _dateFmt = DateFormat('d MMM yyyy');

  final List<ExpenseClaim> _claims = [];

  /// Cached filtered list (updated by [_recomputeFiltered]).
  List<ExpenseClaim> _visibleClaims = const [];

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String _statusFilter = 'all';
  Timer? _debounce;
  RealtimeSubscription? _channel;
  final _loadGuard = AsyncLoadGuard();
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
    _loadGuard.invalidate();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _debounce?.cancel();
    AppRealtime.disposeChannel(_channel);
    super.dispose();
  }

  void _attachRealtime() {
    final uid = context.read<AuthProvider>().user?.id;
    if (uid == null) return;
    _channel = AppRealtime.subscribeMyClaims(
      userId: uid,
      onReload: () {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 400), () {
          if (mounted) _load(showSpinner: false);
        });
      },
    );
  }

  Future<void> _load({bool showSpinner = true}) async {
    final gen = _loadGuard.begin();
    if (showSpinner && mounted) {
      setState(() {
        _loading = true;
        _hasMore = true;
      });
    }
    try {
      final uid = context.read<AuthProvider>().user!.id;
      final data = await SupabaseService.getMyExpenseClaimsPage(
        uid,
        limit: _pageSize,
      );
      if (!mounted || !_loadGuard.isCurrent(gen)) return;
      setState(() {
        _claims
          ..clear()
          ..addAll(data);
        _hasMore = data.length >= _pageSize;
        _loading = false;
        _loadingMore = false;
        _error = null;
        _recomputeFiltered();
      });
      _fillViewport();
    } catch (e) {
      if (!mounted || !_loadGuard.isCurrent(gen)) return;
      setState(() {
        _loading = false;
        _error = friendlyClaimError(e);
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || _loadingMore) return;
    if (!_hasMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 320) _loadMore();
  }

  void _fillViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (!_hasMore || _loading || _loadingMore) return;
      if (_scrollController.position.maxScrollExtent < 100) _loadMore();
    });
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final gen = _loadGuard.begin();
    try {
      final uid = context.read<AuthProvider>().user!.id;
      final data = await SupabaseService.getMyExpenseClaimsPage(
        uid,
        offset: _claims.length,
        limit: _pageSize,
      );
      if (!mounted || !_loadGuard.isCurrent(gen)) return;
      setState(() {
        _claims.addAll(data);
        _hasMore = data.length >= _pageSize;
        _loadingMore = false;
        _recomputeFiltered();
      });
      _fillViewport();
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _recomputeFiltered() {
    if (_statusFilter == 'all') {
      _visibleClaims = _claims;
      return;
    }
    _visibleClaims = _claims
        .where((c) => c.status == _statusFilter)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final money = _moneyFmt;
    final dateFmt = _dateFmt;
    final filteredClaims = _visibleClaims;
    final showLoadMoreRow = _loadingMore || _hasMore;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Expense claims')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await pushAppPage(context, const SubmitClaimScreen());
          if (mounted) _load(showSpinner: false);
        },
        icon: const Icon(Icons.add),
        label: const Text('New claim'),
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
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => _load(showSpinner: true),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _load(showSpinner: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: AppFilterBar(
                      chipOptions: const [
                        AppFilterOption(value: 'all', label: 'All'),
                        AppFilterOption(value: 'pending', label: 'Pending'),
                        AppFilterOption(value: 'approved', label: 'Approved'),
                        AppFilterOption(value: 'rejected', label: 'Rejected'),
                      ],
                      selectedChip: _statusFilter,
                      onChipSelected: (v) => setState(() {
                        _statusFilter = v;
                        _recomputeFiltered();
                        _fillViewport();
                      }),
                    ),
                  ),
                  Expanded(
                    child: filteredClaims.isEmpty
                        ? ListView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 48),
                              EmptyState(
                                icon: Icons.receipt_long_outlined,
                                title: 'No claims yet',
                                subtitle:
                                    'Submit receipts, invoices, or other documents for reimbursement. Tap “New claim” to get started.',
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                            addAutomaticKeepAlives: false,
                            cacheExtent: 400,
                            itemCount:
                                filteredClaims.length +
                                (showLoadMoreRow ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i >= filteredClaims.length) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  child: Center(
                                    child: _loadingMore
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                );
                              }
                              final c = filteredClaims[i];
                              return KeyedSubtree(
                                key: ValueKey<String>(c.id),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Material(
                                    color: AppColors.cardBg,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: const BorderSide(
                                        color: AppColors.divider,
                                      ),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () async {
                                        final deleted = await pushAppPage<bool>(
                                          context,
                                          ClaimDetailScreen(claimId: c.id),
                                        );
                                        if (deleted == true && mounted) {
                                          _load(showSpinner: false);
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
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
                                                    c.title,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                StatusChip.fromStatus(c.status),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              c.categoryDisplay,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                Text(
                                                  '${c.currency} ${money.format(c.amount)}',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        AppColors.primaryDark,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  'Expense: ${dateFmt.format(c.expenseDate)}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Submitted ${dateFmt.format(c.createdAt)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textHint
                                                    .withValues(alpha: 0.95),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

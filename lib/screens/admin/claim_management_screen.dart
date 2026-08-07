import 'dart:async';
import '../../utils/app_route.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_theme.dart';
import '../../models/expense_claim.dart';
import '../../services/app_realtime.dart';
import '../../services/supabase_service.dart';
import '../../utils/error_messages.dart';
import '../../utils/debouncer.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/status_chip.dart';
import '../employee/claim_detail_screen.dart';

/// Admin: review employee expense claims and attachments.
class ClaimManagementScreen extends StatefulWidget {
  const ClaimManagementScreen({super.key});

  @override
  State<ClaimManagementScreen> createState() => _ClaimManagementScreenState();
}

class _ClaimManagementScreenState extends State<ClaimManagementScreen> {
  static const _pageSize = 50;
  List<ExpenseClaim> _claims = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String _filter = 'all';
  final _searchCtrl = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer();
  Timer? _debounce;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
      _attachRealtime();
    });
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    AppRealtime.disposeChannel(_channel);
    super.dispose();
  }

  void _attachRealtime() {
    _channel = AppRealtime.subscribeAdminClaims(
      channelSuffix: 'manage',
      onReload: () {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 400), () {
          if (mounted) _load(showSpinner: false);
        });
      },
    );
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner && mounted) setState(() => _loading = true);
    try {
      final data = await SupabaseService.getExpenseClaimsPage(limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _claims = data;
        _loading = false;
        _loadingMore = false;
        _hasMore = data.length == _pageSize;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyAdminClaimError(e);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = await SupabaseService.getExpenseClaimsPage(
        offset: _claims.length,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _claims = [..._claims, ...next];
        _hasMore = next.length == _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<ExpenseClaim> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _claims.where((c) {
      if (_filter != 'all' && c.status != _filter) return false;
      if (q.isEmpty) return true;
      final name = c.userName?.toLowerCase() ?? '';
      return name.contains(q) ||
          c.title.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q) ||
          c.categoryDisplay.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _setStatus(ExpenseClaim claim, String status) async {
    String? comment;
    if (status == 'rejected') {
      comment = await showDialog<String>(
        context: context,
        builder: (_) => const _ClaimRejectDialog(),
      );
      if (!mounted) return;
      if (comment == null) return;
    }

    try {
      await SupabaseService.updateExpenseClaimStatus(
        claimId: claim.id,
        status: status,
        adminComment: comment?.trim().isEmpty == true ? null : comment?.trim(),
      );
      if (!mounted) return;
      await _load(showSpinner: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved' ? 'Claim approved' : 'Claim rejected',
          ),
          backgroundColor: status == 'approved'
              ? AppColors.success
              : AppColors.danger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyAdminClaimError(e)),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  String _money(ExpenseClaim c) {
    final sym = switch (c.currency.toUpperCase()) {
      'MYR' => 'RM',
      'USD' => r'$',
      'SGD' => 'S\$',
      _ => c.currency,
    };
    return '$sym ${NumberFormat('#,##0.00').format(c.amount)}';
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy');
    final filteredClaims = _loading || _error != null
        ? const <ExpenseClaim>[]
        : _filtered;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Expense claims')),
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
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppFilterBar(
                  searchController: _searchCtrl,
                  searchHint: 'Employee, title, category…',
                  onSearchChanged: (_) => _searchDebouncer(() {
                    if (mounted) setState(() {});
                  }),
                  chipOptions: const [
                    AppFilterOption(value: 'all', label: 'All'),
                    AppFilterOption(value: 'pending', label: 'Pending'),
                    AppFilterOption(value: 'approved', label: 'Approved'),
                    AppFilterOption(value: 'rejected', label: 'Rejected'),
                  ],
                  selectedChip: _filter,
                  onChipSelected: (v) => setState(() => _filter = v),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _load(showSpinner: true),
                    child: filteredClaims.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 48),
                              EmptyState(
                                icon: Icons.receipt_long_outlined,
                                title: 'No claims match',
                                subtitle:
                                    'Try another filter or search keyword.',
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            addAutomaticKeepAlives: false,
                            cacheExtent: 400,
                            itemCount:
                                filteredClaims.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i == filteredClaims.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: OutlinedButton(
                                    onPressed: _loadingMore ? null : _loadMore,
                                    child: _loadingMore
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Load older claims'),
                                  ),
                                );
                              }
                              final c = filteredClaims[i];
                              final name =
                                  (c.userName != null && c.userName!.isNotEmpty)
                                  ? c.userName!
                                  : 'Employee';
                              return KeyedSubtree(
                                key: ValueKey<String>(c.id),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Material(
                                    color: AppColors.cardBg,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: const BorderSide(
                                        color: AppColors.divider,
                                      ),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () {
                                        pushAppPage(
                                          context,
                                          ClaimDetailScreen(claimId: c.id),
                                        );
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
                                                CircleAvatar(
                                                  radius: 20,
                                                  backgroundColor: AppColors
                                                      .orange
                                                      .withValues(alpha: 0.15),
                                                  foregroundColor:
                                                      AppColors.orange,
                                                  child: Text(
                                                    name[0].toUpperCase(),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
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
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        c.title,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 13.5,
                                                          color: AppColors
                                                              .textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                StatusChip.fromStatus(c.status),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Text(
                                                  _money(c),
                                                  style: const TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        AppColors.primaryDark,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  '${c.attachments.length} file(s)',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Expense ${dateFmt.format(c.expenseDate)} · ${c.categoryDisplay}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textHint,
                                              ),
                                            ),
                                            if (c.status == 'pending') ...[
                                              const SizedBox(height: 14),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: OutlinedButton(
                                                      onPressed: () =>
                                                          _setStatus(
                                                            c,
                                                            'rejected',
                                                          ),
                                                      child: const Text(
                                                        'Reject',
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: FilledButton(
                                                      onPressed: () =>
                                                          _setStatus(
                                                            c,
                                                            'approved',
                                                          ),
                                                      style:
                                                          FilledButton.styleFrom(
                                                            backgroundColor:
                                                                AppColors
                                                                    .success,
                                                          ),
                                                      child: const Text(
                                                        'Approve',
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

class _ClaimRejectDialog extends StatefulWidget {
  const _ClaimRejectDialog();

  @override
  State<_ClaimRejectDialog> createState() => _ClaimRejectDialogState();
}

class _ClaimRejectDialogState extends State<_ClaimRejectDialog> {
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
      title: const Text('Reject claim'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Reason (shown to employee)…',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop<String?>(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}

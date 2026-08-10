import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_theme.dart';
import '../../models/expense_claim.dart';
import '../../services/supabase_service.dart';
import '../../utils/error_messages.dart';
import '../../widgets/claim_attachment_link.dart';
import '../../widgets/status_chip.dart';

/// Full claim view including every uploaded attachment (open via signed URL).
class ClaimDetailScreen extends StatefulWidget {
  const ClaimDetailScreen({super.key, required this.claimId});

  final String claimId;

  @override
  State<ClaimDetailScreen> createState() => _ClaimDetailScreenState();
}

class _ClaimDetailScreenState extends State<ClaimDetailScreen> {
  ExpenseClaim? _claim;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await SupabaseService.getExpenseClaimById(widget.claimId);
      if (!mounted) return;
      if (c == null) {
        setState(() {
          _loading = false;
          _error = 'Claim not found or you do not have access.';
        });
        return;
      }
      setState(() {
        _claim = c;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyClaimError(e);
      });
    }
  }

  String _formatMoney(ExpenseClaim c) {
    final sym = switch (c.currency.toUpperCase()) {
      'MYR' => 'RM',
      'USD' => r'$',
      'SGD' => 'S\$',
      _ => c.currency,
    };
    return '$sym ${NumberFormat('#,##0.00').format(c.amount)}';
  }

  String? _formatBytes(int? b) {
    if (b == null || b <= 0) return null;
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy, h:mm a');

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Claim details'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
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
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _claim!.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusChip.fromStatus(_claim!.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _claim!.categoryDisplay,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: AppGradients.brandPanel,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.brandHeaderBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatMoney(_claim!),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onBrand,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Expense date: ${DateFormat('d MMM yyyy').format(_claim!.expenseDate)}',
                            style: TextStyle(
                              color: AppColors.onBrandSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Submitted ${dateFmt.format(_claim!.createdAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.onBrandMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _claim!.description.isEmpty
                          ? '—'
                          : _claim!.description,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.45,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (_claim!.adminComment != null &&
                        _claim!.adminComment!.trim().isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Admin comment',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _claim!.adminComment!.trim(),
                              style: const TextStyle(height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Row(
                      children: [
                        Icon(Icons.folder_open, size: 22, color: AppColors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Attachments',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_claim!.attachments.length} file(s). Tap to open in your viewer or browser.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_claim!.attachments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No files linked. Contact support if this looks wrong.'),
                      )
                    else
                      for (final a in _claim!.attachments)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => openClaimAttachment(
                                context,
                                a.storagePath,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      iconForClaimFileName(a.originalName),
                                      color: AppColors.primaryDark,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            a.originalName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (_formatBytes(a.byteSize) != null)
                                            Text(
                                              _formatBytes(a.byteSize)!,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.open_in_new,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
    );
  }
}

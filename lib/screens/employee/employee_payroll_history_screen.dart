import 'package:flutter/material.dart';
import '../../utils/app_route.dart';
import 'package:intl/intl.dart';

import '../../constants/app_theme.dart';
import '../../models/payroll_history_entry.dart';
import '../../services/supabase_service.dart';
import '../../widgets/empty_state.dart';
import 'employee_payslip_detail_screen.dart';

/// Employee read-only list of payslips (runs approved or paid by HR).
class EmployeePayrollHistoryScreen extends StatefulWidget {
  const EmployeePayrollHistoryScreen({super.key});

  @override
  State<EmployeePayrollHistoryScreen> createState() =>
      _EmployeePayrollHistoryScreenState();
}

class _EmployeePayrollHistoryScreenState
    extends State<EmployeePayrollHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<PayrollHistoryEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final data = await SupabaseService.getMyPayrollHistory();
      if (!mounted) return;
      setState(() {
        _entries = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Color _statusColor(String s) {
    return switch (s) {
      'paid' => AppColors.success,
      'approved' => AppColors.primary,
      _ => AppColors.textSecondary,
    };
  }

  String _statusLabel(String s) {
    return switch (s) {
      'paid' => 'Paid',
      'approved' => 'Approved',
      _ => s,
    };
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);
    final periodFmt = DateFormat('MMMM yyyy');

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('My payslips'),
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
                        const Icon(Icons.error_outline_rounded,
                            size: 48, color: AppColors.danger),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _entries.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: const [
                            EmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'No payslips yet',
                              subtitle:
                                  'Payslips appear here after payroll is approved '
                                  'for a month you are included in. If you expected '
                                  'a payslip, contact HR.',
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _entries.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final e = _entries[i];
                            final periodDate =
                                DateTime(e.run.periodYear, e.run.periodMonth);
                            final chipColor = _statusColor(e.run.status);
                            return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push<void>(
                                    AppRoute(
                                      builder: (_) =>
                                          EmployeePayslipDetailScreen(
                                        run: e.run,
                                        item: e.item,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor:
                                            chipColor.withValues(alpha: 0.14),
                                        child: Icon(
                                          Icons.description_outlined,
                                          color: chipColor,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              periodFmt.format(periodDate),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Net pay ${money.format(e.item.netSalary)}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: AppColors.textSecondary
                                                    .withValues(alpha: 0.95),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: chipColor
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          _statusLabel(e.run.status),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: chipColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.textHint
                                            .withValues(alpha: 0.85),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}

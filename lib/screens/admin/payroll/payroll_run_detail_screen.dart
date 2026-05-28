import 'package:flutter/material.dart';
import '../../../utils/app_route.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_theme.dart';
import '../../../models/payroll_item.dart';
import '../../../models/payroll_run.dart';
import '../../../services/supabase_service.dart';
import 'payroll_item_detail_screen.dart';

class PayrollRunDetailScreen extends StatefulWidget {
  const PayrollRunDetailScreen({super.key, required this.runId});

  final String runId;

  @override
  State<PayrollRunDetailScreen> createState() => _PayrollRunDetailScreenState();
}

class _PayrollRunDetailScreenState extends State<PayrollRunDetailScreen> {
  bool _loading = true;
  bool _busy = false;
  PayrollRun? _run;
  List<PayrollItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final run = await SupabaseService.getPayrollRun(widget.runId);
      final items = await SupabaseService.getPayrollItems(widget.runId);
      if (!mounted) return;
      setState(() {
        _run = run;
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load run: $e')),
      );
    }
  }

  Future<void> _calculate() async {
    final run = _run;
    if (run == null || _busy) return;
    setState(() => _busy = true);
    try {
      await SupabaseService.payrollSyncAndCalculate(run);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance synced & payroll calculated')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    if (_run == null || _busy) return;
    setState(() => _busy = true);
    try {
      await SupabaseService.approvePayrollRun(widget.runId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approved')));
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _paid() async {
    if (_run == null || _busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as paid?'),
        content: const Text('Confirm that salaries have been disbursed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await SupabaseService.markPayrollRunPaid(widget.runId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked paid')));
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);
    final run = _run;
    if (_loading || run == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payroll run')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final period = DateFormat.yMMMM().format(DateTime(run.periodYear, run.periodMonth));
    final canCalc = run.status != 'paid' && run.status != 'cancelled';
    final canApprove = run.status == 'calculated';
    final canPay = run.status == 'approved';

    final statusFriendly = switch (run.status) {
      'draft' => 'Draft',
      'calculated' => 'Calculated — ready for review',
      'approved' => 'Approved — ready to pay',
      'paid' => 'Paid — closed',
      'cancelled' => 'Cancelled',
      _ => run.status.replaceAll('_', ' '),
    };
    final nextStep = switch (run.status) {
      'draft' =>
        'Pull approved attendance and leave for this month, then run calculation. '
        'Present days on each payslip are clock-in days that are not also on approved leave '
        '(same rule as the employee calendar). Unpaid leave still reduces pay in the engine.',
      'calculated' =>
        'Check each employee line. When figures are correct, approve this run.',
      'approved' =>
        'After salaries are transferred, mark this run as paid to close the period.',
      'paid' => 'No further actions. Historical totals stay in Reports.',
      'cancelled' => 'This period was cancelled.',
      _ => '',
    };

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(period),
        backgroundColor: AppColors.adminNavBackground,
        foregroundColor: AppColors.onBrand,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          statusFriendly,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (nextStep.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      nextStep,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (canCalc) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppColors.primary.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'If you fix attendance or leave in this month, '
                            'tap calculate again so payslips stay accurate.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.95),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (run.totalNetPay != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Total net pay: ${money.format(run.totalNetPay)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (run.totalEmployerCost != null &&
                        run.totalEmployerCost! > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Employer statutory (EPF/KWSP, SOCSO/PERKESO, EIS/SIP): ${money.format(run.totalEmployerCost)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                    Text(
                      'Employees in this run: ${run.employeeCount ?? _items.length}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (canCalc)
              FilledButton.icon(
                onPressed: _busy ? null : _calculate,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.calculate_rounded),
                label: const Text('Sync attendance & calculate payroll'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 46),
                ),
              ),
            if (canApprove) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _approve,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Approve payroll'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.indigo,
                  minimumSize: const Size(double.infinity, 46),
                ),
              ),
            ],
            if (canPay) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _paid,
                icon: const Icon(Icons.paid_rounded),
                label: const Text('Mark as paid'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  minimumSize: const Size(double.infinity, 46),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text('Employees', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 8),
            ..._items.map(
              (e) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(e.employeeNameSnapshot),
                  subtitle: Text('Net ${money.format(e.netSalary)}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await Navigator.of(context).push<void>(
                      AppRoute(
                        builder: (_) => PayrollItemDetailScreen(itemId: e.id, run: run),
                      ),
                    );
                    _load();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

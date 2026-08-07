import 'package:flutter/material.dart';
import '../../../utils/app_route.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_theme.dart';
import '../../../models/payroll_run.dart';
import '../../../services/supabase_service.dart';
import 'payroll_run_detail_screen.dart';

class PayrollRunListScreen extends StatefulWidget {
  const PayrollRunListScreen({super.key});

  @override
  State<PayrollRunListScreen> createState() => _PayrollRunListScreenState();
}

class _PayrollRunListScreenState extends State<PayrollRunListScreen> {
  bool _loading = true;
  List<PayrollRun> _runs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final data = await SupabaseService.getPayrollRuns();
      if (!mounted) return;
      setState(() {
        _runs = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load payroll runs: $e')),
      );
    }
  }

  static String _periodTitle(PayrollRun r) {
    try {
      return DateFormat.yMMMM().format(DateTime(r.periodYear, r.periodMonth));
    } catch (_) {
      return '${r.periodYear}-${r.periodMonth.toString().padLeft(2, '0')}';
    }
  }

  static String _statusLabel(String status) => switch (status) {
    'draft' => 'Draft',
    'calculated' => 'Calculated',
    'approved' => 'Approved',
    'paid' => 'Paid',
    'cancelled' => 'Cancelled',
    _ => status.replaceAll('_', ' '),
  };

  String _subtitle(PayrollRun r) {
    final money = NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);
    final parts = <String>[_statusLabel(r.status)];
    if (r.totalNetPay != null) {
      parts.add('Net ${money.format(r.totalNetPay)}');
    }
    final n = r.employeeCount;
    if (n != null && n > 0) {
      parts.add('$n ${n == 1 ? 'employee' : 'employees'}');
    } else if (r.status == 'draft') {
      parts.add('Run calculate after creation');
    }
    return parts.join(' · ');
  }

  Color _statusColor(String s) => switch (s) {
    'paid' => AppColors.success,
    'approved' => AppColors.indigo,
    'calculated' => AppColors.primary,
    'draft' => AppColors.textHint,
    _ => AppColors.textSecondary,
  };

  Future<void> _newRun() async {
    final now = DateTime.now();
    var selectedMonth = now.month;
    final yCtrl = TextEditingController(text: '${now.year}');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('New payroll period'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: yCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    hintText: 'e.g. 2026',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: selectedMonth,
                  decoration: const InputDecoration(labelText: 'Month'),
                  items: List.generate(12, (i) {
                    final m = i + 1;
                    final label = DateFormat.MMMM().format(DateTime(2000, m));
                    return DropdownMenuItem<int>(value: m, child: Text(label));
                  }),
                  onChanged: (v) {
                    if (v != null) setS(() => selectedMonth = v);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'One run per calendar month. Open it and tap '
                  '“Sync attendance & calculate payroll” when ready.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final y = int.tryParse(yCtrl.text) ?? now.year;
    final m = selectedMonth;
    if (m < 1 || m > 12) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid month')));
      return;
    }
    try {
      final existing = await SupabaseService.getPayrollRunForPeriod(y, m);
      if (existing != null) {
        if (!mounted) return;
        await pushAppPage(context, PayrollRunDetailScreen(runId: existing.id));
        if (mounted) _load();
        return;
      }
      final stat = await SupabaseService.getLatestPayrollStatutoryConfig();
      final run = await SupabaseService.createPayrollDraftRun(
        year: y,
        month: m,
        statutoryConfigId: stat?.id,
      );
      if (!mounted) return;
      await pushAppPage(context, PayrollRunDetailScreen(runId: run.id));
      if (mounted) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Payroll runs'),
        backgroundColor: AppColors.adminNavBackground,
        foregroundColor: AppColors.onBrand,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newRun,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New period'),
        backgroundColor: AppColors.primary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: AppColors.textHint.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Present days on payslips match the calendar: '
                          'clock-in days that are not also approved leave. '
                          'Unpaid leave still reduces pay separately.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.95,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: _runs.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(
                                child: Text(
                                  'No payroll runs yet.\n'
                                  'Tap “New period” to start a month.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                            itemCount: _runs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final r = _runs[i];
                              final accent = _statusColor(r.status);
                              return Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: const BorderSide(
                                      color: AppColors.divider,
                                    ),
                                  ),
                                  title: Text(
                                    _periodTitle(r),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      _subtitle(r),
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.3,
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.95),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: accent.withValues(
                                      alpha: 0.15,
                                    ),
                                    child: Icon(
                                      Icons.folder_rounded,
                                      color: accent,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                  onTap: () async {
                                    await pushAppPage(
                                      context,
                                      PayrollRunDetailScreen(runId: r.id),
                                    );
                                    if (mounted) _load();
                                  },
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

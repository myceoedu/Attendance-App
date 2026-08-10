import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../constants/app_theme.dart';
import '../../../models/payroll_run.dart';
import '../../../services/supabase_service.dart';

/// Summary numbers + CSV text export (Excel can open CSV).
class PayrollReportsScreen extends StatefulWidget {
  const PayrollReportsScreen({super.key});

  @override
  State<PayrollReportsScreen> createState() => _PayrollReportsScreenState();
}

class _PayrollReportsScreenState extends State<PayrollReportsScreen> {
  bool _loading = true;
  List<PayrollRun> _runs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _exportMonthlyCsv(PayrollRun run) async {
    final items = await SupabaseService.getPayrollItems(run.id);
    final buf = StringBuffer()
      ..writeln(
        'name,compensation,basic,allowance,commission,incentive,increment,leave_days,leave_ded,epf_ee,socso_ee,eis_ee,gross,deduction,net,epf_er,socso_er,eis_er',
      );
    String moneyStr(double v) => v.toStringAsFixed(2);
    for (final e in items) {
      buf.writeln(
        '${e.employeeNameSnapshot},${e.compensationType},${moneyStr(e.basicAmount)},${moneyStr(e.allowanceAmount)},${moneyStr(e.commissionAmount)},${moneyStr(e.incentiveAmount)},${moneyStr(e.incrementAmount)},${moneyStr(e.unpaidLeaveDays)},${moneyStr(e.unpaidLeaveDeduction)},${moneyStr(e.epfEmployee)},${moneyStr(e.socsoEmployee)},${moneyStr(e.eisEmployee)},${moneyStr(e.grossPay)},${moneyStr(e.totalDeduction)},${moneyStr(e.netSalary)},${moneyStr(e.epfEmployer)},${moneyStr(e.socsoEmployer)},${moneyStr(e.eisEmployer)}',
      );
    }
    await Share.share(
      buf.toString(),
      subject:
          'payroll_${run.periodYear}_${run.periodMonth.toString().padLeft(2, '0')}.csv',
    );
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: 'RM ', decimalDigits: 0);
    var sumNet = 0.0;
    for (final r in _runs.where((x) => x.status == 'paid' || x.status == 'approved')) {
      sumNet += r.totalNetPay ?? 0;
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Payroll reports'),
        backgroundColor: AppColors.adminNavBackground,
        foregroundColor: AppColors.onBrand,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Open a period export for CSV including compensation type, leave days, and statutory columns per employee.',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Approved / paid net payroll (sum of run totals)', style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(money.format(sumNet), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Export CSV', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ..._runs
                    .where((r) => r.status == 'calculated' || r.status == 'approved' || r.status == 'paid')
                    .map(
                      (r) => ListTile(
                        title: Text(
                          '${r.periodYear}-${r.periodMonth.toString().padLeft(2, '0')} · ${r.status}',
                        ),
                        trailing: const Icon(Icons.ios_share_rounded),
                        onTap: () => _exportMonthlyCsv(r),
                      ),
                    ),
              ],
            ),
    );
  }
}

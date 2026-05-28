import 'package:flutter/material.dart';
import '../../../utils/app_route.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_theme.dart';
import '../../../models/app_user.dart';
import '../../../models/payroll_run.dart';
import '../../../services/supabase_service.dart';
import 'payroll_reports_screen.dart';
import 'payroll_run_list_screen.dart';
import 'payroll_salary_list_screen.dart';
import 'payroll_statutory_screen.dart';

/// Malaysia payroll — single company admin hub (Rippling-style KPIs).
class PayrollHubScreen extends StatefulWidget {
  const PayrollHubScreen({super.key});

  @override
  State<PayrollHubScreen> createState() => _PayrollHubScreenState();
}

class _PayrollHubScreenState extends State<PayrollHubScreen> {
  bool _loading = true;
  List<PayrollRun> _runs = [];
  int _employeeCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getPayrollRuns(),
        SupabaseService.getAllEmployees(),
      ]);
      if (!mounted) return;
      setState(() {
        _runs = results[0] as List<PayrollRun>;
        final emps = results[1] as List<AppUser>;
        _employeeCount = emps.where((e) => e.role == 'employee').length;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  int _countByStatuses(Set<String> s) =>
      _runs.where((r) => s.contains(r.status)).length;

  PayrollRun? _latestPaid() {
    final paid = _runs.where((r) => r.status == 'paid').toList();
    if (paid.isEmpty) return null;
    paid.sort((a, b) {
      final c = b.periodYear.compareTo(a.periodYear);
      return c != 0 ? c : b.periodMonth.compareTo(a.periodMonth);
    });
    return paid.first;
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: 'RM ', decimalDigits: 0);
    final pending = _countByStatuses({'draft', 'calculated'});
    final processed = _countByStatuses({'approved'});
    final paidN = _countByStatuses({'paid'});
    final latest = _latestPaid();
    final monthCost = latest?.totalNetPay;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Payroll'),
        backgroundColor: AppColors.adminNavBackground,
        foregroundColor: AppColors.onBrand,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppLayout.screenPaddingH),
                children: [
                  _compactOverviewCard(
                    money: money,
                    employeeCount: _employeeCount,
                    pending: pending,
                    processed: processed,
                    paidN: paidN,
                    latestPaid: latest,
                    lastNetPay: monthCost,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Quick actions',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _actionTile(
                    context,
                    icon: Icons.payments_rounded,
                    title: 'Payroll runs',
                    subtitle: 'Create period, calculate, approve, mark paid',
                    onTap: () async {
                      await Navigator.of(context).push<void>(
                        AppRoute(
                          builder: (_) => const PayrollRunListScreen(),
                        ),
                      );
                      _load();
                    },
                  ),
                  _actionTile(
                    context,
                    icon: Icons.account_balance_rounded,
                    title: 'Employee salaries',
                    subtitle: 'Basic pay, allowances, bank & statutory flags',
                    onTap: () async {
                      await Navigator.of(context).push<void>(
                        AppRoute(
                          builder: (_) => const PayrollSalaryListScreen(),
                        ),
                      );
                      _load();
                    },
                  ),
                  _actionTile(
                    context,
                    icon: Icons.gavel_rounded,
                    title: 'Statutory rates',
                    subtitle: 'EPF, SOCSO, EIS — effective-dated',
                    onTap: () async {
                      await Navigator.of(context).push<void>(
                        AppRoute(
                          builder: (_) => const PayrollStatutoryScreen(),
                        ),
                      );
                    },
                  ),
                  _actionTile(
                    context,
                    icon: Icons.assessment_rounded,
                    title: 'Reports',
                    subtitle: 'Liabilities, totals, export',
                    onTap: () {
                      Navigator.of(context).push<void>(
                        AppRoute(
                          builder: (_) => const PayrollReportsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  /// Single dense card: header + 2×2 mini KPIs + last paid strip.
  Widget _compactOverviewCard({
    required NumberFormat money,
    required int employeeCount,
    required int pending,
    required int processed,
    required int paidN,
    required PayrollRun? latestPaid,
    required double? lastNetPay,
  }) {
    const statutoryHint =
        'Payroll uses Malaysia EPF/KWSP, SOCSO/PERKESO, and EIS/SIP wage-band and threshold rules. Statutory rate sets still choose the default for new runs and hold non-table settings.';

    Widget miniKpi({
      required IconData icon,
      required Color color,
      required String value,
      required String label,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.85)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color.withValues(alpha: 0.95)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.35,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: AppColors.textSecondary.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final periodLabel = latestPaid != null
        ? '${latestPaid.periodYear}-${latestPaid.periodMonth.toString().padLeft(2, '0')}'
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.35,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Tooltip(
                message: statutoryHint,
                triggerMode: TooltipTriggerMode.tap,
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: AppColors.textHint.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: miniKpi(
                  icon: Icons.groups_rounded,
                  color: AppColors.primary,
                  value: '$employeeCount',
                  label: 'Employees',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: miniKpi(
                  icon: Icons.hourglass_top_rounded,
                  color: AppColors.warning,
                  value: '$pending',
                  label: 'Pending',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: miniKpi(
                  icon: Icons.fact_check_rounded,
                  color: AppColors.indigo,
                  value: '$processed',
                  label: 'Approved',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: miniKpi(
                  icon: Icons.paid_rounded,
                  color: AppColors.success,
                  value: '$paidN',
                  label: 'Paid',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.divider.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 18,
                color: AppColors.primary.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      latestPaid != null
                          ? 'Last paid period${periodLabel != null ? ' · $periodLabel' : ''}'
                          : 'Last paid net',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastNetPay != null ? money.format(lastNetPay) : '—',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
              boxShadow: AppElevation.cardOnSurface,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textHint.withValues(alpha: 0.8),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

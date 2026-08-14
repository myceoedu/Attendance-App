import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_theme.dart';
import '../../../models/payroll_item.dart';
import '../../../models/payroll_run.dart';
import '../../../services/payroll_engine.dart';
import '../../../services/payroll_payslip_pdf.dart';
import '../../../services/supabase_service.dart';

class PayrollItemDetailScreen extends StatefulWidget {
  const PayrollItemDetailScreen({
    super.key,
    required this.itemId,
    required this.run,
  });

  final String itemId;
  final PayrollRun run;

  @override
  State<PayrollItemDetailScreen> createState() => _PayrollItemDetailScreenState();
}

class _PayrollItemDetailScreenState extends State<PayrollItemDetailScreen> {
  bool _loading = true;
  PayrollItem? _item;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final item = await SupabaseService.getPayrollItem(widget.itemId);
      if (!mounted) return;
      setState(() {
        _item = item;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _recalcThisEmployee() async {
    final item = _item;
    if (item == null || _busy) return;
    if (widget.run.status == 'paid') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot edit a paid run')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final salary = await SupabaseService.getPayrollSalarySetting(item.userId);
      if (salary == null) {
        throw Exception('No salary package for this employee');
      }
      final configs = await SupabaseService.getPayrollStatutoryConfigs();
      if (configs.isEmpty) {
        throw Exception('No statutory configuration');
      }
      final statutory = widget.run.statutoryConfigId != null
          ? () {
              try {
                return configs.firstWhere(
                  (c) => c.id == widget.run.statutoryConfigId,
                );
              } catch (_) {
                return configs.first;
              }
            }()
          : configs.first;
      final month = DateTime(widget.run.periodYear, widget.run.periodMonth);
      final attFuture =
          SupabaseService.getEmployeeAttendanceByMonth(item.userId, month);
      final leavesFuture =
          SupabaseService.getEmployeeApprovedLeavesByMonth(item.userId, month);
      final employeeFuture = SupabaseService.getUserById(item.userId);
      final att = await attFuture;
      final leaves = await leavesFuture;
      final employee = await employeeFuture;
      final wd = PayrollEngine.workingWeekdaysInMonth(month);
      final present = PayrollEngine.presentDaysExcludingApprovedLeave(
        userId: item.userId,
        month: month,
        attendanceInMonth: att,
        leaves: leaves,
      );
      final unpaidOrInternUnits = salary.isIntern
          ? PayrollEngine.internLeaveCalendarUnitsFromRequests(
              userId: item.userId,
              month: month,
              leaves: leaves,
            )
          : PayrollEngine.unpaidLeaveDaysFromRequests(
              userId: item.userId,
              month: month,
              leaves: leaves,
            );
      final calc = PayrollEngine.compute(
        salary: salary,
        statutory: statutory,
        workingWeekdays: wd,
        presentDays: present,
        month: month,
        leaves: leaves,
        employeeDateOfBirth: employee?.dateOfBirth,
      );
      final updated = PayrollItem(
        id: item.id,
        payrollRunId: item.payrollRunId,
        userId: item.userId,
        employeeNameSnapshot: item.employeeNameSnapshot,
        workingWeekdays: wd,
        presentDays: present,
        otHours: 0,
        unpaidLeaveDays: unpaidOrInternUnits,
        compensationType: salary.compensationType,
        basicAmount: calc.basicAmount,
        allowanceAmount: calc.allowanceAmount,
        commissionAmount: calc.commissionAmount,
        incentiveAmount: calc.incentiveAmount,
        incrementAmount: calc.incrementAmount,
        otAmount: calc.otAmount,
        unpaidLeaveDeduction: calc.unpaidLeaveDeduction,
        epfEmployee: calc.epfEmployee,
        epfEmployer: calc.epfEmployer,
        socsoEmployee: calc.socsoEmployee,
        socsoEmployer: calc.socsoEmployer,
        eisEmployee: calc.eisEmployee,
        eisEmployer: calc.eisEmployer,
        grossPay: calc.grossPay,
        totalDeduction: calc.totalDeduction,
        netSalary: calc.netSalary,
        calcNote: '${calc.calcNote} (recalc)',
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      );
      await SupabaseService.updatePayrollItem(updated);
      await SupabaseService.payrollRecalculateRunTotals(widget.run.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recalculated')));
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

  Future<void> _payslip() async {
    final item = _item;
    if (item == null) return;
    setState(() => _busy = true);
    try {
      await PayrollPayslipPdf.sharePayslip(run: widget.run, item: item);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);
    final item = _item;
    if (_loading || item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payroll line')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final intern = item.isIntern;
    final calDays = PayrollEngine.calendarDaysInMonth(
      DateTime(widget.run.periodYear, widget.run.periodMonth),
    );
    Widget sec(String t, List<Widget> rows) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 6),
          ...rows,
          const SizedBox(height: 14),
        ],
      );
    }

    Widget line(String k, double v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(k, style: const TextStyle(color: AppColors.textSecondary)),
              Text(money.format(v), style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(item.employeeNameSnapshot),
        backgroundColor: AppColors.adminNavBackground,
        foregroundColor: AppColors.onBrand,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            intern
                ? 'Calendar days in month: $calDays · '
                    'Days with clock-in: ${item.presentDays} · '
                    'Leave days counted (incl. half-days): ${item.unpaidLeaveDays}'
                : 'Working weekdays in month: ${item.workingWeekdays} · '
                    'Days with clock-in: ${item.presentDays} · '
                    'Unpaid leave (weekdays): ${item.unpaidLeaveDays}d',
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              intern
                  ? 'Allowance and commission are divided by calendar days. Approved leave reduces pay. Half-day annual counts as 0.5. No EPF, SOCSO, or EIS for interns.'
                  : 'Only approved unpaid leave reduces pay. Sick, emergency, and annual leave are paid. Missing clock-in does not cut pay in this run.',
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: AppColors.textHint.withValues(alpha: 0.95),
              ),
            ),
          ),
          const SizedBox(height: 16),
          sec('Earnings', [
            if (!intern || item.basicAmount > 0) line('Basic', item.basicAmount),
            ...item.variablePayEarningsLines.map((e) => line(e.key, e.value)),
            line('Subtotal', item.earningsSubtotal),
            line(
              intern ? 'Less leave deduction' : 'Less unpaid leave',
              -item.unpaidLeaveDeduction,
            ),
            line('Gross pay', item.grossPay),
          ]),
          if (!intern)
            sec('Malaysia statutory deductions', [
              line('EPF/KWSP (employee)', item.epfEmployee),
              line('SOCSO/PERKESO (employee)', item.socsoEmployee),
              line('EIS/SIP (employee)', item.eisEmployee),
              line('Total statutory', item.statutoryEmployeeDeductions),
            ]),
          if (!intern)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Total take-home deductions: ${money.format(item.totalDeduction)} '
                '(unpaid leave + employee EPF/KWSP, SOCSO/PERKESO, EIS/SIP). '
                'Statutory amounts use Malaysia wage-band/threshold rules. '
                'Net pay = gross pay minus employee statutory only.',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ),
          if (intern)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Total deductions: ${money.format(item.totalDeduction)} (leave only). '
                'Net pay equals gross pay.',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ),
          if (!intern)
            sec('Employer (info)', [
              line('EPF/KWSP employer', item.epfEmployer),
              line('SOCSO/PERKESO employer', item.socsoEmployer),
              line('EIS/SIP employer', item.eisEmployer),
            ]),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Net salary', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(
                  money.format(item.netSalary),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ],
            ),
          ),
          if (item.calcNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(item.calcNote, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _busy ? null : _recalcThisEmployee,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Recalculate this employee'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _payslip,
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Generate payslip PDF'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 46),
            ),
          ),
        ],
      ),
    );
  }
}

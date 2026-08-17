import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_theme.dart';
import '../../models/payroll_item.dart';
import '../../models/payroll_run.dart';
import '../../services/payroll_engine.dart';
import '../../services/payroll_payslip_pdf.dart';

/// Read-only payslip breakdown + PDF share (employee).
class EmployeePayslipDetailScreen extends StatelessWidget {
  const EmployeePayslipDetailScreen({
    super.key,
    required this.run,
    required this.item,
  });

  final PayrollRun run;
  final PayrollItem item;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);
    final period =
        '${run.periodYear}-${run.periodMonth.toString().padLeft(2, '0')}';
    final periodReadable = DateFormat(
      'MMMM yyyy',
    ).format(DateTime(run.periodYear, run.periodMonth));
    final intern = item.isIntern;
    final calDays = PayrollEngine.calendarDaysInMonth(
      DateTime(run.periodYear, run.periodMonth),
    );

    Widget sec(String t, List<Widget> rows) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
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
          Text(
            money.format(v),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(period)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  periodReadable,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.employeeNameSnapshot,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  run.status == 'paid'
                      ? 'This period has been marked paid by payroll.'
                      : 'Approved. Payment follows your company\'s schedule.',
                  style: const TextStyle(fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            intern
                ? 'Calendar days in month: $calDays · '
                      'Days with clock-in: ${item.presentDays} · '
                      'Leave days counted: ${item.unpaidLeaveDays}'
                : 'Working weekdays in month: ${item.workingWeekdays} · '
                      'Days with clock-in: ${item.presentDays} · '
                      'Unpaid leave days counted: ${item.unpaidLeaveDays}d',
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
                  ? 'Intern allowance (and commission if any) is divided by calendar days. Approved non-annual leave in this period reduces pay. No EPF, SOCSO, or EIS.'
                  : 'Only approved unpaid leave on weekdays reduces pay. '
                        'Sick and other paid leave do not.',
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: AppColors.textHint.withValues(alpha: 0.95),
              ),
            ),
          ),
          const SizedBox(height: 18),
          sec('Earnings', [
            if (!intern || item.basicAmount > 0)
              line('Basic', item.basicAmount),
            ...item.variablePayEarningsLines.map((e) => line(e.key, e.value)),
            line('Subtotal', item.earningsSubtotal),
            line(
              intern ? 'Less leave deduction' : 'Less unpaid leave',
              -item.unpaidLeaveDeduction,
            ),
            line('Gross pay', item.grossPay),
          ]),
          if (!intern)
            sec('Malaysia statutory deductions (employee)', [
              line('EPF/KWSP', item.epfEmployee),
              line('SOCSO/PERKESO', item.socsoEmployee),
              line('EIS/SIP', item.eisEmployee),
              line('Total statutory', item.statutoryEmployeeDeductions),
            ]),
          if (!intern)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Total take-home deductions: ${money.format(item.totalDeduction)} '
                '(unpaid leave + EPF/KWSP, SOCSO/PERKESO, EIS/SIP). '
                'Statutory amounts use Malaysia wage-band/threshold rules. '
                'Net = gross minus these employee deductions.',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ),
          if (intern)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Total deductions: ${money.format(item.totalDeduction)} (leave only). Net equals gross pay.',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Net salary',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                Text(
                  money.format(item.netSalary),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          if (item.calcNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              item.calcNote,
              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            intern
                ? 'Intern payslip. Allowance and leave only. Contact HR if you need help.'
                : 'EPF, SOCSO, and EIS use Malaysia rules. Contact HR if you need help.',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textHint,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              try {
                await PayrollPayslipPdf.sharePayslip(
                  run: run,
                  item: item,
                  includeEmployerContributions: false,
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not share PDF: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Download / share PDF'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }
}

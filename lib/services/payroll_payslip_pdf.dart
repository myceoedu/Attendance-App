import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/payroll_item.dart';
import '../models/payroll_run.dart';
import 'payslip_pdf_export_stub.dart'
    if (dart.library.html) 'payslip_pdf_export_web.dart'
    if (dart.library.io) 'payslip_pdf_export_io.dart';

Future<Uint8List> _buildPayslipPdfBytes(Map<String, dynamic> payload) async {
  final runMap = payload['run'] as Map<String, dynamic>;
  final itemMap = payload['item'] as Map<String, dynamic>;
  final company = payload['company_name'] as String? ?? 'Company';
  final includeEmployerContributions =
      payload['include_employer_contributions'] as bool? ?? true;
  final run = PayrollRun.fromMap(runMap);
  final item = PayrollItem.fromMap(itemMap);
  final money = NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);
  final intern = item.isIntern;

  pw.Widget row(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(
              k,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(v, style: const pw.TextStyle(fontSize: 9))),
        ],
      ),
    );
  }

  final period =
      '${run.periodYear}-${run.periodMonth.toString().padLeft(2, '0')}';

  final variableLineWidgets = <pw.Widget>[
    for (final e in item.variablePayEarningsLines)
      row(e.key, money.format(e.value)),
  ];

  final doc = pw.Document();
  final earningsSection = intern
      ? <pw.Widget>[
          pw.Text(
            'Earnings',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          ...variableLineWidgets,
          row('Subtotal', money.format(item.earningsSubtotal)),
          row('Less leave deduction', money.format(-item.unpaidLeaveDeduction)),
          row('Gross pay', money.format(item.grossPay)),
        ]
      : <pw.Widget>[
          pw.Text(
            'Earnings',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          row('Basic salary', money.format(item.basicAmount)),
          ...variableLineWidgets,
          row('Subtotal', money.format(item.earningsSubtotal)),
          row('Less unpaid leave', money.format(-item.unpaidLeaveDeduction)),
          row('Gross pay', money.format(item.grossPay)),
        ];

  final statutorySection = intern
      ? <pw.Widget>[
          pw.SizedBox(height: 8),
          pw.Text(
            'Statutory deductions',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          row('EPF/KWSP, SOCSO/PERKESO, EIS/SIP', money.format(0)),
          pw.Text(
            'Not applicable — intern (no EPF/KWSP, SOCSO/PERKESO, or EIS/SIP).',
            style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Total deductions: ${money.format(item.totalDeduction)}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ]
      : <pw.Widget>[
          pw.SizedBox(height: 8),
          pw.Text(
            'Malaysia statutory deductions',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          row('EPF/KWSP (employee)', money.format(item.epfEmployee)),
          row('SOCSO/PERKESO (employee)', money.format(item.socsoEmployee)),
          row('EIS/SIP (employee)', money.format(item.eisEmployee)),
          row('Total statutory', money.format(item.statutoryEmployeeDeductions)),
          pw.SizedBox(height: 6),
          pw.Text(
            'All reductions (unpaid + Malaysia statutory): ${money.format(item.totalDeduction)}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ];

  final employerSection = (!includeEmployerContributions || intern)
      ? <pw.Widget>[]
      : <pw.Widget>[
          pw.SizedBox(height: 12),
          pw.Text(
            'Employer contributions (informational)',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          row('EPF/KWSP employer', money.format(item.epfEmployer)),
          row('SOCSO/PERKESO employer', money.format(item.socsoEmployer)),
          row('EIS/SIP employer', money.format(item.eisEmployer)),
        ];

  doc.addPage(
    pw.Page(
      pageTheme: const pw.PageTheme(margin: pw.EdgeInsets.all(40)),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            company,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Payslip — $period', style: const pw.TextStyle(fontSize: 10)),
          pw.Divider(),
          pw.Text(
            'Employee',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          row('Name', item.employeeNameSnapshot),
          pw.SizedBox(height: 8),
          ...earningsSection,
          ...statutorySection,
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Net salary',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  money.format(item.netSalary),
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...employerSection,
          pw.SizedBox(height: 16),
          pw.Text(
            intern
                ? 'Intern payslip — allowance and leave only.'
                : 'Malaysia statutory wage-band/threshold rules applied for EPF/KWSP, SOCSO/PERKESO, and EIS/SIP.',
            style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic),
          ),
        ],
      ),
    ),
  );

  return doc.save();
}

class PayrollPayslipPdf {
  PayrollPayslipPdf._();

  static Map<String, dynamic> _payload(
    PayrollRun run,
    PayrollItem item,
    String companyName,
    bool includeEmployerContributions,
  ) {
    return {
      'run': {
        'id': run.id,
        'period_year': run.periodYear,
        'period_month': run.periodMonth,
        'status': run.status,
        'statutory_config_id': run.statutoryConfigId,
        'pay_date': run.payDate?.toIso8601String(),
        'notes': run.notes,
        'total_net_pay': run.totalNetPay,
        'total_employer_cost': run.totalEmployerCost,
        'employee_count': run.employeeCount,
        'created_by': run.createdBy,
        'approved_by': run.approvedBy,
        'paid_by': run.paidBy,
        'approved_at': run.approvedAt?.toIso8601String(),
        'paid_at': run.paidAt?.toIso8601String(),
        'created_at': run.createdAt.toIso8601String(),
        'updated_at': run.updatedAt.toIso8601String(),
      },
      'item': {
        'id': item.id,
        'payroll_run_id': item.payrollRunId,
        'user_id': item.userId,
        'employee_name_snapshot': item.employeeNameSnapshot,
        'working_weekdays': item.workingWeekdays,
        'present_days': item.presentDays,
        'ot_hours': item.otHours,
        'unpaid_leave_days': item.unpaidLeaveDays,
        'compensation_type': item.compensationType,
        'basic_amount': item.basicAmount,
        'allowance_amount': item.allowanceAmount,
        'commission_amount': item.commissionAmount,
        'incentive_amount': item.incentiveAmount,
        'increment_amount': item.incrementAmount,
        'ot_amount': item.otAmount,
        'unpaid_leave_deduction': item.unpaidLeaveDeduction,
        'epf_employee': item.epfEmployee,
        'epf_employer': item.epfEmployer,
        'socso_employee': item.socsoEmployee,
        'socso_employer': item.socsoEmployer,
        'eis_employee': item.eisEmployee,
        'eis_employer': item.eisEmployer,
        'gross_pay': item.grossPay,
        'total_deduction': item.totalDeduction,
        'net_salary': item.netSalary,
        'calc_note': item.calcNote,
        'created_at': item.createdAt.toIso8601String(),
        'updated_at': item.updatedAt.toIso8601String(),
      },
      'company_name': companyName,
      'include_employer_contributions': includeEmployerContributions,
    };
  }

  static Future<void> sharePayslip({
    required PayrollRun run,
    required PayrollItem item,
    String companyName = 'Company',
    bool includeEmployerContributions = true,
  }) async {
    final map = _payload(
      run,
      item,
      companyName,
      includeEmployerContributions,
    );
    final bytes = kIsWeb
        ? await _buildPayslipPdfBytes(map)
        : await Isolate.run(() => _buildPayslipPdfBytes(map));

    final raw = item.employeeNameSnapshot.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final safeName =
        raw.isEmpty ? 'employee' : (raw.length > 24 ? raw.substring(0, 24) : raw);
    final filename =
        'payslip_${run.periodYear}_${run.periodMonth}_$safeName.pdf';
    final subject =
        'Payslip ${run.periodYear}-${run.periodMonth.toString().padLeft(2, '0')} — ${item.employeeNameSnapshot}';

    final savedOrDownloaded = await offerPayslipPdf(bytes, filename, subject);
    if (!savedOrDownloaded) {
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            mimeType: 'application/pdf',
            name: filename,
          ),
        ],
        subject: subject,
      );
    }
  }
}

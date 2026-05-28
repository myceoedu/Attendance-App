import 'payroll_item.dart';
import 'payroll_run.dart';

/// One payslip row: a [PayrollItem] with its parent [PayrollRun].
class PayrollHistoryEntry {
  PayrollHistoryEntry({required this.run, required this.item});

  final PayrollRun run;
  final PayrollItem item;
}

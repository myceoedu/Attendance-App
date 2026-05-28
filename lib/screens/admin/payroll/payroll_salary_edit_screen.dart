import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_theme.dart';
import '../../../models/app_user.dart';
import '../../../models/payroll_salary_setting.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/employment_status.dart';

class PayrollSalaryEditScreen extends StatefulWidget {
  const PayrollSalaryEditScreen({
    super.key,
    required this.user,
    this.existing,
  });

  final AppUser user;
  final PayrollSalarySetting? existing;

  @override
  State<PayrollSalaryEditScreen> createState() => _PayrollSalaryEditScreenState();
}

class _PayrollSalaryEditScreenState extends State<PayrollSalaryEditScreen> {
  late final TextEditingController _staffId;
  late final TextEditingController _dept;
  late final TextEditingController _pos;
  late final TextEditingController _basic;
  late final TextEditingController _internAllowance;
  late final TextEditingController _allowance;
  late final TextEditingController _commission;
  late final TextEditingController _incentive;
  late final TextEditingController _increment;
  late final TextEditingController _bank;
  late final TextEditingController _acct;
  late final Listenable _employeePayPreviewListenable;

  late bool _eis;
  late String _compType;
  late String _employmentStatus;
  late String _epfCat;
  late String _socCat;
  late String _payMethod;
  late String _status;
  bool _saving = false;

  static final _money0 = NumberFormat.currency(locale: 'en_US', symbol: 'RM ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    final u = widget.user;
    _staffId = TextEditingController(text: ex?.staffId ?? u.employeeCode ?? '');
    _dept = TextEditingController(text: ex?.department ?? u.department ?? '');
    _pos = TextEditingController(text: ex?.position ?? u.jobTitle ?? '');
    _basic = TextEditingController(text: '${ex?.basicSalary ?? 0}');
    _internAllowance = TextEditingController(text: '${ex?.fixedAllowance ?? 0}');
    _allowance = TextEditingController(text: '${ex?.fixedAllowance ?? 0}');
    _commission = TextEditingController(text: '${ex?.monthlyCommission ?? 0}');
    _incentive = TextEditingController(text: '${ex?.monthlyIncentive ?? 0}');
    _increment = TextEditingController(text: '${ex?.monthlyIncrement ?? 0}');
    _employeePayPreviewListenable = Listenable.merge([
      _basic,
      _allowance,
      _commission,
      _incentive,
      _increment,
    ]);
    _bank = TextEditingController(text: ex?.bankName ?? u.bankName ?? '');
    _acct = TextEditingController(text: ex?.bankAccountNumber ?? u.bankAccountNumber ?? '');
    _eis = ex?.eisEligible ?? true;
    _compType = ex?.compensationType ?? 'employee';
    _employmentStatus = EmploymentStatus.normalize(ex?.employmentStatus);
    _epfCat = ex?.epfCategory ?? 'standard';
    _socCat = ex?.socsoCategory ?? 'standard';
    _payMethod = ex?.paymentMethod ?? 'bank_transfer';
    _status = ex?.payrollStatus ?? 'active';

  }

  @override
  void dispose() {
    _staffId.dispose();
    _dept.dispose();
    _pos.dispose();
    _basic.dispose();
    _internAllowance.dispose();
    _allowance.dispose();
    _commission.dispose();
    _incentive.dispose();
    _increment.dispose();
    _bank.dispose();
    _acct.dispose();
    super.dispose();
  }

  double _parseRm(TextEditingController c) => double.tryParse(c.text) ?? 0;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final isIntern = _compType == 'intern';
      final s = PayrollSalarySetting(
        userId: widget.user.id,
        staffId: _staffId.text.trim(),
        department: _dept.text.trim(),
        position: _pos.text.trim(),
        employmentStatus: EmploymentStatus.normalize(_employmentStatus),
        basicSalary: isIntern ? 0 : (double.tryParse(_basic.text) ?? 0),
        fixedAllowance:
            isIntern ? (double.tryParse(_internAllowance.text) ?? 0) : _parseRm(_allowance),
        monthlyCommission: isIntern ? 0 : _parseRm(_commission),
        monthlyIncentive: isIntern ? 0 : _parseRm(_incentive),
        monthlyIncrement: isIntern ? 0 : _parseRm(_increment),
        otEligible: false,
        compensationType: _compType,
        epfCategory: _compType == 'intern' ? 'standard' : _epfCat,
        socsoCategory: _compType == 'intern' ? 'standard' : _socCat,
        eisEligible: _compType == 'intern' ? false : _eis,
        paymentMethod: _payMethod,
        bankName: _bank.text.trim(),
        bankAccountNumber: _acct.text.trim(),
        payrollStatus: _status,
        updatedAt: widget.existing?.updatedAt ?? DateTime.now(),
      );
      await SupabaseService.upsertPayrollSalarySetting(s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _card({required List<Widget> children}) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _blockTitle(String title, {String? subtitle}) {
    return Column(
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
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _employeeMonthlyPayPreview() {
    return AnimatedBuilder(
      animation: _employeePayPreviewListenable,
      builder: (_, __) {
        final basic = _parseRm(_basic);
        final add = _parseRm(_allowance) +
            _parseRm(_commission) +
            _parseRm(_incentive) +
            _parseRm(_increment);
        final total = basic + add;
        return _previewPanel(
          title: 'Payroll preview',
          message: add > 0
              ? '${_money0.format(basic)} basic  ·  ${_money0.format(add)} add-ons (total)  ·  ${_money0.format(total)} normal pay (before leave & statutory)'
              : '${_money0.format(basic)} basic only  ·  ${_money0.format(total)} normal pay (before leave & statutory)',
          color: AppColors.primary,
          fill: AppColors.primaryLight.withValues(alpha: 0.45),
        );
      },
    );
  }

  Widget _internPreview() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _internAllowance,
      builder: (_, value, ___) {
        final allow = double.tryParse(value.text) ?? 0;
        return _previewPanel(
          title: 'Allowance preview',
          message:
              'Monthly pool ${_money0.format(allow)} — divided by calendar days; approved leave reduces pay. No statutory deductions.',
          color: AppColors.teal,
          fill: AppColors.tealLight.withValues(alpha: 0.5),
        );
      },
    );
  }

  Widget _previewPanel({
    required String title,
    required String message,
    required Color color,
    required Color fill,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color.lerp(color, AppColors.primaryDark, 0.35),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rmAddOnField({
    required TextEditingController controller,
    required String label,
    String? helperText,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixText: 'RM ',
        isDense: true,
        helperText: helperText,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
    );
  }

  /// Avoids horizontal overflow on narrow screens when the selected label is long.
  Text _dropdownLabel(String text) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user.name.isNotEmpty ? widget.user.name : widget.user.username;
    final isIntern = _compType == 'intern';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(name),
        backgroundColor: AppColors.adminNavBackground,
        foregroundColor: AppColors.onBrand,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              'Save',
              style: TextStyle(
                color: AppColors.onBrand.withValues(alpha: _saving ? 0.5 : 1),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            children: [
              _blockTitle('Job details', subtitle: 'These fields are stored with payroll for reports.'),
              const SizedBox(height: 14),
              TextField(
                controller: _staffId,
                decoration: const InputDecoration(
                  labelText: 'Staff ID',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dept,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pos,
                decoration: const InputDecoration(
                  labelText: 'Position',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _card(
            children: [
              _blockTitle(
                'Employment status',
                subtitle:
                    'HR classification only. This is separate from “Compensation type” below (how pay is calculated).',
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey('emp_status_$_employmentStatus'),
                initialValue: EmploymentStatus.normalize(_employmentStatus),
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final c in EmploymentStatus.codes)
                    DropdownMenuItem(
                      value: c,
                      child: _dropdownLabel(EmploymentStatus.label(c)),
                    ),
                ],
                onChanged: (v) => setState(
                  () => _employmentStatus = EmploymentStatus.normalize(v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _card(
            children: [
              _blockTitle(
                'Employment type',
                subtitle: 'This controls how monthly pay and leave are calculated.',
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey('comp_type_$_compType'),
                initialValue: _compType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Compensation type',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'employee',
                    child: _dropdownLabel('Basic + add-ons'),
                  ),
                  DropdownMenuItem(
                    value: 'intern',
                    child: _dropdownLabel('Monthly allowance only'),
                  ),
                ],
                onChanged: (v) => setState(() => _compType = v ?? 'employee'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isIntern)
            _card(
              children: [
                _blockTitle(
                  'Intern pay',
                  subtitle: 'Step 1 — enter the full monthly allowance. No basic salary or statutory rows.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _internAllowance,
                  decoration: const InputDecoration(
                    labelText: 'Monthly allowance (RM)',
                    hintText: 'e.g. 1500',
                    border: OutlineInputBorder(),
                    prefixText: 'RM ',
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                ),
                const SizedBox(height: 14),
                _internPreview(),
              ],
            )
          else
            _card(
              children: [
                _blockTitle(
                  'Employee monthly pay',
                  subtitle:
                      'Basic plus any combination of allowance, commission, incentive, and increment. '
                      'Each non-zero amount appears as its own line on payslips. All count toward gross and statutory base.',
                ),
                const SizedBox(height: 18),
                const Text(
                  '1 · Basic salary',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _basic,
                  decoration: const InputDecoration(
                    labelText: 'Basic salary per month (RM)',
                    hintText: 'e.g. 4500',
                    border: OutlineInputBorder(),
                    prefixText: 'RM ',
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                ),
                const SizedBox(height: 22),
                const Divider(height: 1),
                const SizedBox(height: 18),
                const Text(
                  '2 · Monthly add-ons (all optional)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Use 0 or leave empty where not applicable. You can enter allowance and commission together, or any mix of the four.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textHint.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 14),
                _rmAddOnField(
                  controller: _allowance,
                  label: 'Allowance (RM / month)',
                  helperText: 'Fixed recurring allowance',
                ),
                const SizedBox(height: 12),
                _rmAddOnField(
                  controller: _commission,
                  label: 'Commission (RM / month)',
                  helperText: 'Sales or variable component',
                ),
                const SizedBox(height: 12),
                _rmAddOnField(
                  controller: _incentive,
                  label: 'Incentive (RM / month)',
                ),
                const SizedBox(height: 12),
                _rmAddOnField(
                  controller: _increment,
                  label: 'Increment (RM / month)',
                  helperText: 'Salary step-up / adjustment',
                ),
                const SizedBox(height: 16),
                _employeeMonthlyPayPreview(),
              ],
            ),
          if (!isIntern) ...[
            const SizedBox(height: 14),
            _card(
              children: [
                _blockTitle(
                  'Malaysia statutory',
                  subtitle: 'Age and category rules apply when payroll is calculated.',
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('EIS eligible'),
                  value: _eis,
                  onChanged: (v) => setState(() => _eis = v),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  key: ValueKey('epf_$_epfCat'),
                  initialValue: _epfCat,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'EPF / KWSP category',
                    helperText: 'Use “Age 60+” if employee is 60 or above (or DOB on file).',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'standard', child: Text('Standard')),
                    DropdownMenuItem(value: 'above60', child: Text('Age 60 and above')),
                  ],
                  onChanged: (v) => setState(() => _epfCat = v ?? 'standard'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('socso_$_socCat'),
                  initialValue: _socCat,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'SOCSO / PERKESO category',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'standard', child: Text('Standard')),
                  ],
                  onChanged: (v) => setState(() => _socCat = v ?? 'standard'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _card(
            children: [
              _blockTitle('Bank & status'),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey('pay_method_$_payMethod'),
                initialValue: _payMethod,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Payment method',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'bank_transfer', child: Text('Bank transfer')),
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                ],
                onChanged: (v) => setState(() => _payMethod = v ?? 'bank_transfer'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bank,
                decoration: const InputDecoration(
                  labelText: 'Bank name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _acct,
                decoration: const InputDecoration(
                  labelText: 'Bank account number',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('status_$_status'),
                initialValue: _status,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Payroll status',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'active',
                    child: _dropdownLabel('Active — include in runs'),
                  ),
                  DropdownMenuItem(
                    value: 'hold',
                    child: _dropdownLabel('Hold — pause payroll'),
                  ),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'active'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Save salary package'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

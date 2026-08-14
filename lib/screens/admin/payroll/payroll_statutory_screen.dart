import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_theme.dart';
import '../../../models/payroll_salary_setting.dart';
import '../../../payroll/payroll_calculator.dart';
import '../../../models/payroll_statutory_config.dart';
import '../../../services/supabase_service.dart';

class PayrollStatutoryScreen extends StatefulWidget {
  const PayrollStatutoryScreen({super.key});

  @override
  State<PayrollStatutoryScreen> createState() => _PayrollStatutoryScreenState();
}

class _PayrollStatutoryScreenState extends State<PayrollStatutoryScreen> {
  bool _loading = true;
  List<PayrollStatutoryConfig> _list = [];
  Map<String, int> _usageByConfigId = const {};
  final TextEditingController _debugWageCtrl = TextEditingController(
    text: '1700',
  );
  String _debugEpfCategory = 'standard';
  String _debugSocsoCategory = 'standard';
  bool _debugEisEligible = true;

  @override
  void dispose() {
    _debugWageCtrl.dispose();
    super.dispose();
  }

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
      final results = await Future.wait<Object>([
        SupabaseService.getPayrollStatutoryConfigs(),
        SupabaseService.getPayrollStatutoryUsageCounts(),
      ]);
      final data = results[0] as List<PayrollStatutoryConfig>;
      final usage = results[1] as Map<String, int>;
      if (!mounted) return;
      setState(() {
        _list = data;
        _usageByConfigId = usage;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load rate sets: $e')));
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  PayrollSalarySetting _debugSalarySeed() {
    return PayrollSalarySetting(
      userId: '_debug',
      staffId: '',
      department: '',
      position: '',
      employmentStatus: 'permanent',
      basicSalary: 0,
      fixedAllowance: 0,
      monthlyCommission: 0,
      monthlyIncentive: 0,
      monthlyIncrement: 0,
      otEligible: false,
      compensationType: 'employee',
      epfCategory: _debugEpfCategory,
      socsoCategory: _debugSocsoCategory,
      eisEligible: _debugEisEligible,
      paymentMethod: 'bank_transfer',
      bankName: '',
      bankAccountNumber: '',
      payrollStatus: 'active',
      updatedAt: DateTime.now(),
    );
  }

  Widget _debugStatutoryPreviewCard() {
    final wage = double.tryParse(_debugWageCtrl.text.trim()) ?? 0;
    final amounts = PayrollCalculator.computeMalaysiaStatutory(
      wageBase: wage,
      month: DateTime.now(),
      salary: _debugSalarySeed(),
    );
    final money = NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);

    Widget rowLine(String label, double employee, double employer) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(
              width: 108,
              child: Text(
                money.format(employee),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 108,
              child: Text(
                money.format(employer),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
          boxShadow: AppElevation.cardOnSurface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8),
                Text(
                  'Statutory debug preview',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Quick HR sandbox: input wage and categories to verify KWSP/SOCSO/EIS bracket outputs.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textHint,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _debugWageCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Wage base (RM)',
                      hintText: 'e.g. 1700',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey<String>(_debugEpfCategory),
                    initialValue: _debugEpfCategory,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'KWSP age band',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'standard',
                        child: Text('Below 60'),
                      ),
                      DropdownMenuItem(
                        value: 'above60',
                        child: Text('60 and above'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _debugEpfCategory = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey<String>(_debugSocsoCategory),
              initialValue: _debugSocsoCategory,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'SOCSO category',
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'standard',
                  child: Text('First category'),
                ),
                DropdownMenuItem(
                  value: 'second',
                  child: Text('Second category'),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _debugSocsoCategory = v);
              },
            ),
            const SizedBox(height: 4),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'EIS eligible',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              dense: true,
              value: _debugEisEligible,
              onChanged: (v) => setState(() => _debugEisEligible = v),
            ),
            const Divider(height: 16),
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Contribution',
                      style: TextStyle(fontSize: 11, color: AppColors.textHint),
                    ),
                  ),
                  SizedBox(
                    width: 108,
                    child: Text(
                      'Employee',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11, color: AppColors.textHint),
                    ),
                  ),
                  SizedBox(width: 8),
                  SizedBox(
                    width: 108,
                    child: Text(
                      'Employer',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11, color: AppColors.textHint),
                    ),
                  ),
                ],
              ),
            ),
            rowLine('KWSP', amounts.epfEmployee, amounts.epfEmployer),
            rowLine(
              'SOCSO / PERKESO',
              amounts.socsoEmployee,
              amounts.socsoEmployer,
            ),
            rowLine('EIS / SIP', amounts.eisEmployee, amounts.eisEmployer),
          ],
        ),
      ),
    );
  }

  /// Shared form dialog for both create and edit.
  Future<void> _showForm({PayrollStatutoryConfig? existing}) async {
    final isNew = existing == null;
    final seed = existing ?? (_list.isNotEmpty ? _list.first : null);

    final labelCtrl = TextEditingController(
      text: existing?.label ?? 'Malaysia default template',
    );
    DateTime effectiveDate = existing?.effectiveFrom ?? DateTime.now();
    final effectiveDateCtrl = TextEditingController(
      text: _fmtDate(effectiveDate),
    );
    final epfECtrl = TextEditingController(
      text: '${seed?.epfEmployeePct ?? 11}',
    );
    final epfErCtrl = TextEditingController(
      text: '${seed?.epfEmployerPct ?? 13}',
    );
    final ceilingCtrl = TextEditingController(
      text: seed?.epfSalaryCeiling?.toString() ?? '',
    );
    final soECtrl = TextEditingController(
      text: '${seed?.socsoEmployeePct ?? 0.5}',
    );
    final soErCtrl = TextEditingController(
      text: '${seed?.socsoEmployerPct ?? 1.75}',
    );
    final eiECtrl = TextEditingController(
      text: '${seed?.eisEmployeePct ?? 0.2}',
    );
    final eiErCtrl = TextEditingController(
      text: '${seed?.eisEmployerPct ?? 0.2}',
    );

    String? formError;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(isNew ? 'New rate set' : 'Edit rate set'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Label'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: effectiveDateCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Effective from',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today_outlined),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: effectiveDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2050),
                        );
                        if (picked != null) {
                          setS(() {
                            effectiveDate = picked;
                            effectiveDateCtrl.text = _fmtDate(picked);
                          });
                        }
                      },
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                const Text(
                  'Legacy/reference rates (%)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Malaysia statutory calculation now uses built-in wage-band and threshold rules. These fields are kept for reference and historical compatibility.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: epfECtrl,
                        decoration: const InputDecoration(
                          labelText: 'EPF employee %',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: epfErCtrl,
                        decoration: const InputDecoration(
                          labelText: 'EPF employer %',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ceilingCtrl,
                  decoration: const InputDecoration(
                    labelText: 'EPF wage ceiling (optional)',
                    hintText: 'Leave blank for no ceiling',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: soECtrl,
                        decoration: const InputDecoration(
                          labelText: 'SOCSO employee %',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: soErCtrl,
                        decoration: const InputDecoration(
                          labelText: 'SOCSO employer %',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: eiECtrl,
                        decoration: const InputDecoration(
                          labelText: 'EIS employee %',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: eiErCtrl,
                        decoration: const InputDecoration(
                          labelText: 'EIS employer %',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                if (formError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    formError!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                double? pct(String v) {
                  final d = double.tryParse(v);
                  if (d == null || d < 0 || d > 100) return null;
                  return d;
                }

                final epfE = pct(epfECtrl.text);
                final epfEr = pct(epfErCtrl.text);
                final soE = pct(soECtrl.text);
                final soEr = pct(soErCtrl.text);
                final eiE = pct(eiECtrl.text);
                final eiEr = pct(eiErCtrl.text);

                String? err;
                if (labelCtrl.text.trim().isEmpty) {
                  err = 'Label is required';
                } else if (epfE == null) {
                  err = 'EPF employee % must be 0–100';
                } else if (epfEr == null) {
                  err = 'EPF employer % must be 0–100';
                } else if (soE == null) {
                  err = 'SOCSO employee % must be 0–100';
                } else if (soEr == null) {
                  err = 'SOCSO employer % must be 0–100';
                } else if (eiE == null) {
                  err = 'EIS employee % must be 0–100';
                } else if (eiEr == null) {
                  err = 'EIS employer % must be 0–100';
                } else {
                  final sameDate = _list.any(
                    (x) =>
                        x.id != (existing?.id ?? '') &&
                        x.effectiveFrom.year == effectiveDate.year &&
                        x.effectiveFrom.month == effectiveDate.month &&
                        x.effectiveFrom.day == effectiveDate.day,
                  );
                  if (sameDate) {
                    err = 'Another rate set already uses this effective date';
                  }
                }

                if (err != null) {
                  setS(() => formError = err);
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(isNew ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    final config = PayrollStatutoryConfig(
      id: existing?.id ?? '',
      label: labelCtrl.text.trim().isEmpty ? 'Rate set' : labelCtrl.text.trim(),
      effectiveFrom: effectiveDate,
      epfEmployeePct:
          double.tryParse(epfECtrl.text) ?? (seed?.epfEmployeePct ?? 11),
      epfEmployerPct:
          double.tryParse(epfErCtrl.text) ?? (seed?.epfEmployerPct ?? 13),
      epfSalaryCeiling: ceilingCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(ceilingCtrl.text.trim()),
      socsoEmployeePct:
          double.tryParse(soECtrl.text) ?? (seed?.socsoEmployeePct ?? 0.5),
      socsoEmployerPct:
          double.tryParse(soErCtrl.text) ?? (seed?.socsoEmployerPct ?? 1.75),
      eisEmployeePct:
          double.tryParse(eiECtrl.text) ?? (seed?.eisEmployeePct ?? 0.2),
      eisEmployerPct:
          double.tryParse(eiErCtrl.text) ?? (seed?.eisEmployerPct ?? 0.2),
      otHourlyMultiplier:
          existing?.otHourlyMultiplier ?? (seed?.otHourlyMultiplier ?? 1.5),
      standardHoursPerDay:
          existing?.standardHoursPerDay ?? (seed?.standardHoursPerDay ?? 8),
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    try {
      if (isNew) {
        await SupabaseService.insertPayrollStatutoryConfig(config);
      } else {
        await SupabaseService.updatePayrollStatutoryConfig(config);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isNew ? 'Rate set created' : 'Saved')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _delete(PayrollStatutoryConfig c) async {
    final isCurrentDefault = _list.isNotEmpty && _list.first.id == c.id;
    final nextDefault = isCurrentDefault && _list.length > 1 ? _list[1] : null;

    final body = isCurrentDefault && nextDefault != null
        ? 'Delete "${c.label}"?\n\n"${nextDefault.label}" (effective ${_fmtDate(nextDefault.effectiveFrom)}) will become the new default for future payroll runs.\n\nThis cannot be undone.'
        : 'Delete "${c.label}"?\n\nThis cannot be undone.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete rate set?'),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await SupabaseService.deletePayrollStatutoryConfig(c.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Deleted')));
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _replaceUsage(PayrollStatutoryConfig from) async {
    final candidates = _list.where((e) => e.id != from.id).toList();
    if (candidates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add another rate set first')),
        );
      }
      return;
    }
    String selectedId = candidates.first.id;
    final picked = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Replace usage with...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Move payroll runs using "${from.label}" to another rate set.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Target rate set'),
                items: candidates
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c.id,
                        child: Text(
                          '${c.label} (${_fmtDate(c.effectiveFrom)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setS(() => selectedId = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      ),
    );
    if (picked != true || !mounted) return;

    try {
      final updated = await SupabaseService.reassignPayrollStatutoryUsage(
        fromConfigId: from.id,
        toConfigId: selectedId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Moved $updated payroll run${updated == 1 ? '' : 's'}',
            ),
          ),
        );
      }
      _load();
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
        title: const Text('Statutory rates'),
        backgroundColor: AppColors.adminNavBackground,
        foregroundColor: AppColors.onBrand,
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _showForm(),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New rate set',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.percent_rounded,
                      size: 48,
                      color: AppColors.textHint.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No statutory rate sets yet.\nTap + to add one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 13,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'The top item is the default for new payroll runs (latest effective date). EPF, SOCSO, and EIS use Malaysia wage-band rules. Saved percentage fields are kept for reference only.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _debugStatutoryPreviewCard(),
                const SizedBox(height: 8),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final c = _list[i];
                        final isDefault = i == 0;
                        final today = DateTime.now();
                        final isFuture = c.effectiveFrom.isAfter(
                          DateTime(today.year, today.month, today.day),
                        );
                        final usedCount = _usageByConfigId[c.id] ?? 0;
                        // Default set: deletable only if another set exists
                        // to take over. Other sets: deletable only if no
                        // existing runs reference them.
                        final canDelete = isDefault
                            ? _list.length > 1
                            : usedCount == 0;
                        final deleteTooltip = canDelete
                            ? (isDefault
                                  ? '"${_list[1].label}" will become the new default'
                                  : 'Delete')
                            : (isDefault
                                  ? 'Add another rate set first'
                                  : 'Used by $usedCount run${usedCount > 1 ? 's' : ''}. Replace usage first');
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () => _showForm(existing: c),
                            borderRadius: BorderRadius.circular(16),
                            child: Ink(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDefault
                                      ? AppColors.primary.withValues(
                                          alpha: 0.45,
                                        )
                                      : AppColors.divider,
                                  width: isDefault ? 1.5 : 1,
                                ),
                              ),
                              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                c.label,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            if (isDefault) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.successLight,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: const Text(
                                                  'NEW RUN DEFAULT',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.success,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Text(
                                              'Effective ${_fmtDate(c.effectiveFrom)}',
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (isFuture) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'FUTURE DATE',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.orange,
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          isDefault
                                              ? 'Default for new payroll runs'
                                              : (usedCount == 0
                                                    ? 'Not used by any payroll run'
                                                    : 'Used by $usedCount payroll run${usedCount > 1 ? 's' : ''}'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDefault
                                                ? AppColors.success
                                                : (usedCount == 0
                                                      ? AppColors.textHint
                                                      : AppColors.primaryDark),
                                            fontWeight: isDefault
                                                ? FontWeight.w600
                                                : (usedCount == 0
                                                      ? FontWeight.w500
                                                      : FontWeight.w700),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Reference: EPF ${c.epfEmployeePct}% / ${c.epfEmployerPct}%'
                                          '  ·  SOCSO ${c.socsoEmployeePct}% / ${c.socsoEmployerPct}%'
                                          '  ·  EIS ${c.eisEmployeePct}% / ${c.eisEmployerPct}%',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                            height: 1.35,
                                          ),
                                        ),
                                        if (c.epfSalaryCeiling != null) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            'EPF wage ceiling: RM ${c.epfSalaryCeiling!.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textHint,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: AppColors.textHint,
                                      ),
                                      const SizedBox(height: 4),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          Icons.swap_horiz_rounded,
                                          size: 18,
                                          color: usedCount > 0
                                              ? AppColors.primary
                                              : AppColors.textHint,
                                        ),
                                        onPressed: usedCount > 0
                                            ? () => _replaceUsage(c)
                                            : null,
                                        tooltip: usedCount > 0
                                            ? 'Replace usage with another set'
                                            : 'No usage to replace',
                                      ),
                                      const SizedBox(height: 4),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                          color: canDelete
                                              ? AppColors.danger
                                              : AppColors.textHint,
                                        ),
                                        onPressed: canDelete
                                            ? () => _delete(c)
                                            : null,
                                        tooltip: deleteTooltip,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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

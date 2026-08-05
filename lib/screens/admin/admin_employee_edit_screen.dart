import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_theme.dart';
import '../../models/app_user.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_time.dart';
import '../../utils/profile_validators.dart';

/// Full employee record editor for administrators.
class AdminEmployeeEditScreen extends StatefulWidget {
  const AdminEmployeeEditScreen({super.key, required this.employee});

  final AppUser employee;

  @override
  State<AdminEmployeeEditScreen> createState() =>
      _AdminEmployeeEditScreenState();
}

class _AdminEmployeeEditScreenState extends State<AdminEmployeeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _loadingProfile = true;
  String? _loadError;

  /// Full row from DB (list payload is incomplete — reload on open).
  late AppUser _employee;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _icCtrl;
  late final TextEditingController _jobCtrl;
  late final TextEditingController _deptCtrl;
  late final TextEditingController _empIdCtrl;
  late final TextEditingController _epfCtrl;
  late final TextEditingController _socsoCtrl;
  late final TextEditingController _bankNameCtrl;
  late final TextEditingController _bankAcctCtrl;
  late final TextEditingController _eduLevelCtrl;
  late final TextEditingController _eduInstCtrl;
  late final TextEditingController _emeNameCtrl;
  late final TextEditingController _emeRelCtrl;
  late final TextEditingController _emePhoneCtrl;
  late final TextEditingController _overrideCtrl;

  String _role = 'employee';
  String _maritalValue = '';
  DateTime? _dob;
  DateTime? _employmentStart;

  @override
  void initState() {
    super.initState();
    _employee = widget.employee;
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _icCtrl = TextEditingController();
    _jobCtrl = TextEditingController();
    _deptCtrl = TextEditingController();
    _empIdCtrl = TextEditingController();
    _epfCtrl = TextEditingController();
    _socsoCtrl = TextEditingController();
    _bankNameCtrl = TextEditingController();
    _bankAcctCtrl = TextEditingController();
    _eduLevelCtrl = TextEditingController();
    _eduInstCtrl = TextEditingController();
    _emeNameCtrl = TextEditingController();
    _emeRelCtrl = TextEditingController();
    _emePhoneCtrl = TextEditingController();
    _overrideCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadFullProfile();
    });
  }

  void _applyEmployee(AppUser e) {
    _employee = e;
    _nameCtrl.text = e.name;
    _phoneCtrl.text = e.phone ?? '';
    _addressCtrl.text = e.address ?? '';
    _icCtrl.text = e.icNumber ?? '';
    _jobCtrl.text = e.jobTitle ?? '';
    _deptCtrl.text = e.department ?? '';
    _empIdCtrl.text = e.employeeCode ?? '';
    _epfCtrl.text = e.epfNumber ?? '';
    _socsoCtrl.text = e.socsoNumber ?? '';
    _bankNameCtrl.text = e.bankName ?? '';
    _bankAcctCtrl.text = e.bankAccountNumber ?? '';
    _eduLevelCtrl.text = e.educationLevel ?? '';
    _eduInstCtrl.text = e.educationInstitution ?? '';
    _emeNameCtrl.text = e.emergencyContactName ?? '';
    _emeRelCtrl.text = e.emergencyContactRelationship ?? '';
    _emePhoneCtrl.text = e.emergencyContactPhone ?? '';
    _overrideCtrl.text = e.annualLeaveEntitlementOverride?.toString() ?? '';
    _role = e.role;
    _maritalValue = e.maritalStatus ?? '';
    _dob = e.dateOfBirth;
    _employmentStart = e.employmentStartDate;
  }

  Future<void> _loadFullProfile() async {
    setState(() {
      _loadingProfile = true;
      _loadError = null;
    });
    try {
      final full = await SupabaseService.getUserById(widget.employee.id);
      if (!mounted) return;
      if (full == null) {
        setState(() {
          _loadingProfile = false;
          _loadError = 'Employee record not found.';
        });
        return;
      }
      _applyEmployee(full);
      setState(() => _loadingProfile = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _loadError = 'Could not load employee details. Pull to retry.';
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _icCtrl.dispose();
    _jobCtrl.dispose();
    _deptCtrl.dispose();
    _empIdCtrl.dispose();
    _epfCtrl.dispose();
    _socsoCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAcctCtrl.dispose();
    _eduLevelCtrl.dispose();
    _eduInstCtrl.dispose();
    _emeNameCtrl.dispose();
    _emeRelCtrl.dispose();
    _emePhoneCtrl.dispose();
    _overrideCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, [IconData? icon]) {
    return InputDecoration(
      labelText: label,
      // Keep labels on the border so filled/empty fields look the same.
      floatingLabelBehavior: FloatingLabelBehavior.always,
      prefixIcon: icon != null
          ? Icon(icon, size: 22, color: AppColors.textSecondary)
          : null,
      alignLabelWithHint: true,
    );
  }

  Widget _fieldIcon(IconData icon) =>
      Icon(icon, size: 22, color: AppColors.textSecondary);

  Future<void> _pickDob() async {
    final now = AppTime.malaysiaNow();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 80),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _pickEmploymentStart() async {
    final now = AppTime.malaysiaNow();
    final picked = await showDatePicker(
      context: context,
      initialDate: _employmentStart ??
          DateTime(now.year, now.month, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) {
      setState(
        () => _employmentStart = DateTime(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ename = _emeNameCtrl.text.trim();
    if (ename.isNotEmpty && _emePhoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add emergency contact phone')),
      );
      return;
    }

    final rawOv = _overrideCtrl.text.trim();
    double? parsedOv;
    var clearOv = false;
    if (rawOv.isEmpty) {
      clearOv = _employee.annualLeaveEntitlementOverride != null;
    } else {
      parsedOv = double.tryParse(rawOv.replaceAll(',', '.'));
      if (parsedOv == null || parsedOv < 0 || parsedOv > 99.9) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave override must be a number (0–99.9) or empty.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await SupabaseService.updateEmployeeAsAdmin(
        userId: _employee.id,
        name: _nameCtrl.text,
        role: _role,
        phone: _phoneCtrl.text,
        address: _addressCtrl.text,
        maritalStatus: _maritalValue,
        dateOfBirth: _dob,
        icNumber: _icCtrl.text,
        jobTitle: _jobCtrl.text,
        department: _deptCtrl.text,
        employeeCode: _empIdCtrl.text,
        epfNumber: _epfCtrl.text,
        socsoNumber: _socsoCtrl.text,
        bankName: _bankNameCtrl.text,
        bankAccountNumber: _bankAcctCtrl.text,
        educationLevel: _eduLevelCtrl.text,
        educationInstitution: _eduInstCtrl.text,
        emergencyContactName: _emeNameCtrl.text,
        emergencyContactRelationship: _emeRelCtrl.text,
        emergencyContactPhone: _emePhoneCtrl.text,
        employmentStartDate: _employmentStart,
        entitlementOverride: clearOv ? null : parsedOv,
        clearEntitlementOverride: clearOv,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee saved'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.contains('users_employee_code_unique')
                ? 'Employee ID already in use.'
                : 'Could not save: $e',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _employee;
    final dateFmt = DateFormat('d MMM yyyy');
    final canEdit = !_loadingProfile && _loadError == null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Edit employee'),
        actions: [
          TextButton(
            onPressed: (_saving || !canEdit) ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadFullProfile,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              e.name.isNotEmpty ? e.name : e.username,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${e.username} · ${e.email}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Account email and username are set at registration and are not editable here.',
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
            const Divider(height: 28),
            TextFormField(
              controller: _nameCtrl,
              decoration: _dec('Full name', Icons.person_outline_rounded),
              validator: ProfileValidators.requiredName,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: _dec('Role', Icons.admin_panel_settings_outlined),
              items: const [
                DropdownMenuItem(value: 'employee', child: Text('Employee')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'employee'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: _dec('Phone', Icons.phone_rounded),
              validator: ProfileValidators.phoneMalaysia,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressCtrl,
              maxLines: 2,
              decoration: _dec('Address', Icons.home_outlined),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey<String>('marital_$_maritalValue'),
              initialValue: _maritalValue.isEmpty ? '' : _maritalValue,
              decoration: _dec('Marital status', Icons.favorite_border_rounded),
              items: const [
                DropdownMenuItem(value: '', child: Text('Not set')),
                DropdownMenuItem(value: 'Single', child: Text('Single')),
                DropdownMenuItem(value: 'Married', child: Text('Married')),
                DropdownMenuItem(value: 'Divorced', child: Text('Divorced')),
                DropdownMenuItem(value: 'Widowed', child: Text('Widowed')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _maritalValue = v ?? ''),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: _fieldIcon(Icons.cake_rounded),
              title: const Text('Date of birth'),
              subtitle: Text(
                _dob == null ? 'Tap to select' : dateFmt.format(_dob!),
              ),
              trailing: _fieldIcon(Icons.chevron_right_rounded),
              onTap: _pickDob,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _icCtrl,
              decoration: _dec('IC / NRIC', Icons.contact_page_outlined),
              validator: ProfileValidators.icNumber,
            ),
            const Divider(height: 28),
            const Text(
              'Employment',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _jobCtrl,
              decoration: _dec('Job title', Icons.work_outline_rounded),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _deptCtrl,
              decoration: _dec('Department', Icons.business_outlined),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _empIdCtrl,
              decoration: _dec('Employee ID', Icons.tag_rounded),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: _fieldIcon(Icons.event_outlined),
              title: const Text('Employment start'),
              subtitle: Text(
                _employmentStart == null
                    ? 'Not set'
                    : dateFmt.format(_employmentStart!),
              ),
              trailing: _fieldIcon(Icons.chevron_right_rounded),
              onTap: _pickEmploymentStart,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _overrideCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _dec(
                'Annual leave days override (optional)',
                Icons.event_available_outlined,
              ),
            ),
            const Text(
              'Leave empty to use company tiers; sets HR override when filled.',
              style: TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
            const Divider(height: 28),
            const Text(
              'Statutory & bank',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _epfCtrl,
              decoration: _dec('EPF', Icons.account_balance_wallet_outlined),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _socsoCtrl,
              decoration: _dec('SOCSO', Icons.health_and_safety_outlined),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bankNameCtrl,
              decoration: _dec('Bank name', Icons.account_balance_outlined),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bankAcctCtrl,
              keyboardType: TextInputType.number,
              decoration: _dec('Bank account no.', Icons.numbers_rounded),
              validator: ProfileValidators.bankAccount,
            ),
            const Divider(height: 28),
            const Text(
              'Education',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _eduLevelCtrl,
              decoration: _dec('Highest level', Icons.school_outlined),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _eduInstCtrl,
              decoration: _dec('Institution', Icons.domain_outlined),
            ),
            const Divider(height: 28),
            const Text(
              'Emergency contact',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emeNameCtrl,
              decoration: _dec('Name', Icons.person_outline_rounded),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emeRelCtrl,
              decoration: _dec('Relationship', Icons.group_outlined),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emePhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: _dec('Phone', Icons.phone_rounded),
              validator: ProfileValidators.phoneMalaysia,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: (_saving || !canEdit) ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save changes'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

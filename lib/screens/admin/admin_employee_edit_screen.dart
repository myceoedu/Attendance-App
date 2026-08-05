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

  static const Color _pageBg = Color(0xFFF6F8FB);
  static const Color _fieldBg = Color(0xFFF3F5F9);
  static const Color _cardBorder = Color(0xFFE6EAF0);
  static const double _radius = 16;
  static const double _fieldRadius = 12;

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
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: _fieldBg,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      prefixIcon: icon != null
          ? Icon(icon, size: 20, color: AppColors.textSecondary)
          : null,
      alignLabelWithHint: true,
      labelStyle: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(color: _cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.55),
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(color: _cardBorder),
      ),
    );
  }

  Widget _fieldIcon(IconData icon) =>
      Icon(icon, size: 20, color: AppColors.textSecondary);

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

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _gap([double h = 14]) => SizedBox(height: h);

  Widget _dateField({
    required String label,
    required String value,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_fieldRadius),
        child: InputDecorator(
          decoration: _dec(label, icon).copyWith(
            suffixIcon: _fieldIcon(Icons.calendar_today_rounded),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: value.startsWith('Tap') || value == 'Not set'
                  ? AppColors.textHint
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileSummary(AppUser e) {
    final displayName = e.name.isNotEmpty
        ? e.name
        : (e.username.isNotEmpty ? e.username : 'Employee');
    final initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : '?';
    final isAdmin = _role == 'admin' || e.isAdmin;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            e.email,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isAdmin
                  ? AppColors.violet.withValues(alpha: 0.12)
                  : AppColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isAdmin
                    ? AppColors.violet.withValues(alpha: 0.25)
                    : AppColors.teal.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              isAdmin ? 'Administrator' : 'Employee',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isAdmin ? AppColors.violet : AppColors.teal,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Username: ${e.username.isNotEmpty ? e.username : '—'}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Account email and username are set at registration and are not editable here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = _employee;
    final dateFmt = DateFormat('d MMM yyyy');
    final canEdit = !_loadingProfile && _loadError == null;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Employee details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: AppColors.textPrimary,
          ),
        ),
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                children: [
                  _profileSummary(e),
                  const SizedBox(height: 20),

                  // ── Personal Information ─────────────────────────────
                  _sectionCard(
                    title: 'Personal Information',
                    icon: Icons.person_outline_rounded,
                    children: [
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _dec(
                          'Full Name',
                          Icons.person_outline_rounded,
                        ),
                        validator: ProfileValidators.requiredName,
                        textCapitalization: TextCapitalization.words,
                      ),
                      _gap(),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: _dec('Phone', Icons.phone_rounded),
                        validator: ProfileValidators.phoneMalaysia,
                      ),
                      _gap(),
                      _dateField(
                        label: 'Date of Birth',
                        value: _dob == null
                            ? 'Tap to select'
                            : dateFmt.format(_dob!),
                        onTap: _pickDob,
                        icon: Icons.cake_outlined,
                      ),
                      _gap(),
                      DropdownButtonFormField<String>(
                        key: ValueKey<String>('marital_$_maritalValue'),
                        initialValue:
                            _maritalValue.isEmpty ? '' : _maritalValue,
                        decoration: _dec(
                          'Marital Status',
                          Icons.favorite_border_rounded,
                        ),
                        icon: _fieldIcon(Icons.keyboard_arrow_down_rounded),
                        borderRadius: BorderRadius.circular(_fieldRadius),
                        items: const [
                          DropdownMenuItem(
                            value: '',
                            child: Text('Not set'),
                          ),
                          DropdownMenuItem(
                            value: 'Single',
                            child: Text('Single'),
                          ),
                          DropdownMenuItem(
                            value: 'Married',
                            child: Text('Married'),
                          ),
                          DropdownMenuItem(
                            value: 'Divorced',
                            child: Text('Divorced'),
                          ),
                          DropdownMenuItem(
                            value: 'Widowed',
                            child: Text('Widowed'),
                          ),
                          DropdownMenuItem(
                            value: 'Other',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _maritalValue = v ?? ''),
                      ),
                      _gap(),
                      TextFormField(
                        controller: _icCtrl,
                        decoration: _dec(
                          'IC / NRIC',
                          Icons.badge_outlined,
                        ),
                        validator: ProfileValidators.icNumber,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Address ──────────────────────────────────────────
                  _sectionCard(
                    title: 'Address',
                    icon: Icons.home_outlined,
                    children: [
                      TextFormField(
                        controller: _addressCtrl,
                        maxLines: 3,
                        minLines: 3,
                        decoration: _dec(
                          'Full Address',
                          Icons.location_on_outlined,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Employment ───────────────────────────────────────
                  _sectionCard(
                    title: 'Employment',
                    icon: Icons.work_outline_rounded,
                    children: [
                      TextFormField(
                        controller: _jobCtrl,
                        decoration: _dec(
                          'Job Title',
                          Icons.work_outline_rounded,
                        ),
                      ),
                      _gap(),
                      TextFormField(
                        controller: _deptCtrl,
                        decoration: _dec(
                          'Department',
                          Icons.apartment_outlined,
                        ),
                      ),
                      _gap(),
                      TextFormField(
                        controller: _empIdCtrl,
                        decoration: _dec('Employee ID', Icons.tag_rounded),
                      ),
                      _gap(),
                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: _dec(
                          'Role',
                          Icons.admin_panel_settings_outlined,
                        ),
                        icon: _fieldIcon(Icons.keyboard_arrow_down_rounded),
                        borderRadius: BorderRadius.circular(_fieldRadius),
                        items: const [
                          DropdownMenuItem(
                            value: 'employee',
                            child: Text('Employee'),
                          ),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('Admin'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _role = v ?? 'employee'),
                      ),
                      _gap(),
                      _dateField(
                        label: 'Employment Start',
                        value: _employmentStart == null
                            ? 'Not set'
                            : dateFmt.format(_employmentStart!),
                        onTap: _pickEmploymentStart,
                        icon: Icons.event_outlined,
                      ),
                      _gap(),
                      TextFormField(
                        controller: _overrideCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _dec(
                          'Annual leave days override (optional)',
                          Icons.event_available_outlined,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Leave empty to use company tiers; sets HR override when filled.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Statutory & bank ─────────────────────────────────
                  _sectionCard(
                    title: 'Statutory & Bank',
                    icon: Icons.account_balance_outlined,
                    children: [
                      TextFormField(
                        controller: _epfCtrl,
                        decoration: _dec(
                          'EPF',
                          Icons.account_balance_wallet_outlined,
                        ),
                      ),
                      _gap(),
                      TextFormField(
                        controller: _socsoCtrl,
                        decoration: _dec(
                          'SOCSO',
                          Icons.health_and_safety_outlined,
                        ),
                      ),
                      _gap(),
                      TextFormField(
                        controller: _bankNameCtrl,
                        decoration: _dec(
                          'Bank name',
                          Icons.account_balance_outlined,
                        ),
                      ),
                      _gap(),
                      TextFormField(
                        controller: _bankAcctCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _dec(
                          'Bank account no.',
                          Icons.numbers_rounded,
                        ),
                        validator: ProfileValidators.bankAccount,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Education ────────────────────────────────────────
                  _sectionCard(
                    title: 'Education',
                    icon: Icons.school_outlined,
                    children: [
                      TextFormField(
                        controller: _eduLevelCtrl,
                        decoration: _dec(
                          'Highest level',
                          Icons.school_outlined,
                        ),
                      ),
                      _gap(),
                      TextFormField(
                        controller: _eduInstCtrl,
                        decoration: _dec(
                          'Institution',
                          Icons.domain_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Emergency contact ────────────────────────────────
                  _sectionCard(
                    title: 'Emergency Contact',
                    icon: Icons.contact_emergency_outlined,
                    children: [
                      TextFormField(
                        controller: _emeNameCtrl,
                        decoration: _dec(
                          'Name',
                          Icons.person_outline_rounded,
                        ),
                      ),
                      _gap(),
                      TextFormField(
                        controller: _emeRelCtrl,
                        decoration: _dec(
                          'Relationship',
                          Icons.group_outlined,
                        ),
                      ),
                      _gap(),
                      TextFormField(
                        controller: _emePhoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: _dec('Phone', Icons.phone_rounded),
                        validator: ProfileValidators.phoneMalaysia,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Actions ──────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: (_saving || !canEdit) ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_fieldRadius),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: _cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_fieldRadius),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

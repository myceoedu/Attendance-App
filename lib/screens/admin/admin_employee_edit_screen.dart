import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../constants/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/payroll_salary_setting.dart';
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
  bool _annualEligible = true;

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

  // Match Add employee admin form tokens.
  static const Color _navy = Color(0xFF14213D);
  static const Color _pageBg = Color(0xFFF5F6F8);
  static const Color _border = Color(0xFFD8DBE2);
  static const Color _muted = Color(0xFF9AA1AD);
  static const Color _label = Color(0xFF3A3F4B);
  static const Color _avatarBg = Color(0xFFE9EBF2);
  static const Color _roleGreen = Color(0xFF16A34A);
  static const Color _roleGreenBg = Color(0xFFDCFCE7);
  static const Color _roleViolet = Color(0xFF7C3AED);
  static const Color _roleVioletBg = Color(0xFFEDE9FE);
  static const double _radius = 8;
  static const double _fieldHeight = 40;

  TextStyle get _ui => GoogleFonts.inter();

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
      PayrollSalarySetting? salary;
      try {
        salary = await SupabaseService.getPayrollSalarySetting(full.id);
      } catch (_) {
        salary = null;
      }
      if (!mounted) return;
      setState(() {
        _annualEligible = salary == null || salary.hasAnnualLeave;
        _loadingProfile = false;
      });
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

  InputDecoration _dec({
    IconData? icon,
    bool multiline = false,
    Widget? suffix,
  }) {
    final iconColor = WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.focused)) return _navy;
      return _muted;
    });

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      prefixIcon: icon == null
          ? null
          : (multiline
              ? Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8, top: 12),
                  child: Align(
                    alignment: Alignment.topCenter,
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Icon(icon, size: 18),
                  ),
                )
              : Icon(icon, size: 18)),
      prefixIconColor: iconColor,
      suffixIcon: suffix,
      suffixIconColor: iconColor,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: multiline ? 12 : 10,
      ),
      constraints: multiline
          ? null
          : const BoxConstraints(minHeight: _fieldHeight),
      border: border(_border, 1),
      enabledBorder: border(_border, 1),
      disabledBorder: border(_border.withValues(alpha: 0.7), 1),
      focusedBorder: border(_navy, 1.5),
      errorBorder: border(AppColors.danger, 1),
      focusedErrorBorder: border(AppColors.danger, 1.5),
      errorStyle: _ui.copyWith(fontSize: 11.5, color: AppColors.danger),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: _ui.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: _label,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _labeled(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fieldLabel(label),
        field,
      ],
    );
  }

  Widget _fieldIcon(IconData icon) => Icon(icon, size: 18, color: _muted);

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
      initialDate: _employmentStart ?? DateTime(now.year, now.month, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) {
      setState(
        () =>
            _employmentStart = DateTime(picked.year, picked.month, picked.day),
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

    final rawOv = _annualEligible ? _overrideCtrl.text.trim() : '';
    double? parsedOv;
    var clearOv = false;
    if (_annualEligible) {
      if (rawOv.isEmpty) {
        clearOv = _employee.annualLeaveEntitlementOverride != null;
      } else {
        parsedOv = double.tryParse(rawOv.replaceAll(',', '.'));
        if (parsedOv == null || parsedOv < 0 || parsedOv > 99.9) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Leave override must be a number (0–99.9) or empty.',
              ),
              backgroundColor: AppColors.danger,
            ),
          );
          return;
        }
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
        entitlementOverride: _annualEligible
            ? (clearOv ? null : parsedOv)
            : null,
        clearEntitlementOverride: _annualEligible && clearOv,
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _navy),
              const SizedBox(width: 8),
              Text(
                title,
                style: _ui.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: _navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _gap([double h = 10]) => SizedBox(height: h);

  Widget _dateField({
    required String label,
    required String value,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    final empty = value.startsWith('Tap') || value == 'Not set';
    return _labeled(
      label,
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_radius),
          child: InputDecorator(
            decoration: _dec(
              icon: icon,
              suffix: _fieldIcon(Icons.calendar_today_outlined),
            ),
            child: Text(
              value,
              style: _ui.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: empty ? _muted : _label,
              ),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: _avatarBg,
            child: Text(
              initial,
              style: _ui.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _navy,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: _ui.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: _navy,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            e.email,
            textAlign: TextAlign.center,
            style: _ui.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: _muted,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isAdmin ? _roleVioletBg : _roleGreenBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isAdmin ? 'Administrator' : 'Employee',
              style: _ui.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isAdmin ? _roleViolet : _roleGreen,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 12),
          Text(
            'Username: ${e.username.isNotEmpty ? e.username : '—'}',
            style: _ui.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Account email and username are set at registration and are not editable here.',
            textAlign: TextAlign.center,
            style: _ui.copyWith(
              fontSize: 11,
              height: 1.35,
              fontWeight: FontWeight.w400,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _inputStyle => _ui.copyWith(
        fontSize: 14,
        color: _label,
        fontWeight: FontWeight.w500,
      );

  @override
  Widget build(BuildContext context) {
    final e = _employee;
    final dateFmt = DateFormat('d MMM yyyy');
    final canEdit = !_loadingProfile && _loadError == null;

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: _pageBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          iconTheme: const IconThemeData(color: _navy, size: 22),
          title: Text(
            'Employee details',
            style: _ui.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _navy,
              letterSpacing: -0.1,
            ),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: ColoredBox(
              color: _border,
              child: SizedBox(height: 1, width: double.infinity),
            ),
          ),
        ),
        body: _loadingProfile
            ? const Center(
                child: CircularProgressIndicator(
                  color: _navy,
                  strokeWidth: 2.4,
                ),
              )
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
                        style: _ui.copyWith(color: AppColors.danger),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _loadFullProfile,
                        child: Text(
                          'Retry',
                          style: _ui.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                  children: [
                    _profileSummary(e),
                    const SizedBox(height: 16),

                    _sectionCard(
                      title: 'Personal information',
                      icon: Icons.person_outline_rounded,
                      children: [
                        _labeled(
                          'Full name',
                          TextFormField(
                            controller: _nameCtrl,
                            style: _inputStyle,
                            decoration:
                                _dec(icon: Icons.person_outline_rounded),
                            validator: ProfileValidators.requiredName,
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                        _gap(),
                        _labeled(
                          'Phone',
                          TextFormField(
                            controller: _phoneCtrl,
                            style: _inputStyle,
                            keyboardType: TextInputType.phone,
                            decoration: _dec(icon: Icons.phone_outlined),
                            validator: ProfileValidators.phoneMalaysia,
                          ),
                        ),
                        _gap(),
                        _dateField(
                          label: 'Date of birth',
                          value: _dob == null
                              ? 'Tap to select'
                              : dateFmt.format(_dob!),
                          onTap: _pickDob,
                          icon: Icons.cake_outlined,
                        ),
                        _gap(),
                        _labeled(
                          'Marital status',
                          DropdownButtonFormField<String>(
                            key: ValueKey<String>('marital_$_maritalValue'),
                            initialValue:
                                _maritalValue.isEmpty ? '' : _maritalValue,
                            style: _inputStyle,
                            decoration: _dec(
                              icon: Icons.favorite_border_rounded,
                            ),
                            icon: _fieldIcon(Icons.keyboard_arrow_down_rounded),
                            borderRadius: BorderRadius.circular(_radius),
                            dropdownColor: Colors.white,
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
                        ),
                        _gap(),
                        _labeled(
                          'IC / NRIC',
                          TextFormField(
                            controller: _icCtrl,
                            style: _inputStyle,
                            decoration: _dec(icon: Icons.badge_outlined),
                            validator: ProfileValidators.icNumber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _sectionCard(
                      title: 'Address',
                      icon: Icons.home_outlined,
                      children: [
                        _labeled(
                          'Full address',
                          TextFormField(
                            controller: _addressCtrl,
                            style: _inputStyle,
                            maxLines: 3,
                            minLines: 3,
                            decoration: _dec(
                              icon: Icons.location_on_outlined,
                              multiline: true,
                            ),
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _sectionCard(
                      title: 'Employment',
                      icon: Icons.work_outline_rounded,
                      children: [
                        _labeled(
                          'Job title',
                          TextFormField(
                            controller: _jobCtrl,
                            style: _inputStyle,
                            decoration: _dec(icon: Icons.work_outline_rounded),
                          ),
                        ),
                        _gap(),
                        _labeled(
                          'Department',
                          TextFormField(
                            controller: _deptCtrl,
                            style: _inputStyle,
                            decoration: _dec(icon: Icons.apartment_outlined),
                          ),
                        ),
                        _gap(),
                        _labeled(
                          'Employee ID',
                          TextFormField(
                            controller: _empIdCtrl,
                            style: _inputStyle,
                            decoration: _dec(icon: Icons.tag_rounded),
                          ),
                        ),
                        _gap(),
                        _labeled(
                          'Role',
                          DropdownButtonFormField<String>(
                            initialValue: _role,
                            style: _inputStyle,
                            decoration: _dec(
                              icon: Icons.admin_panel_settings_outlined,
                            ),
                            icon: _fieldIcon(Icons.keyboard_arrow_down_rounded),
                            borderRadius: BorderRadius.circular(_radius),
                            dropdownColor: Colors.white,
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
                        ),
                        _gap(),
                        _dateField(
                          label: 'Employment start',
                          value: _employmentStart == null
                              ? 'Not set'
                              : dateFmt.format(_employmentStart!),
                          onTap: _pickEmploymentStart,
                          icon: Icons.event_outlined,
                        ),
                        _gap(),
                        if (_annualEligible) ...[
                          _labeled(
                            'Annual leave days override (optional)',
                            TextFormField(
                              controller: _overrideCtrl,
                              style: _inputStyle,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: _dec(
                                icon: Icons.event_available_outlined,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Leave empty for company tiers. Enter a value to set an HR override.',
                            style: _ui.copyWith(
                              fontSize: 11.5,
                              height: 1.35,
                              color: _muted,
                            ),
                          ),
                        ] else
                          Text(
                            'Annual leave is for permanent and contract staff only. Interns do not have an annual balance.',
                            style: _ui.copyWith(
                              fontSize: 12.5,
                              height: 1.4,
                              color: _muted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _sectionCard(
                      title: 'Statutory & bank',
                      icon: Icons.account_balance_outlined,
                      children: [
                        _labeled(
                          'EPF',
                          TextFormField(
                            controller: _epfCtrl,
                            style: _inputStyle,
                            decoration: _dec(
                              icon: Icons.account_balance_wallet_outlined,
                            ),
                          ),
                        ),
                        _gap(),
                        _labeled(
                          'SOCSO',
                          TextFormField(
                            controller: _socsoCtrl,
                            style: _inputStyle,
                            decoration: _dec(
                              icon: Icons.health_and_safety_outlined,
                            ),
                          ),
                        ),
                        _gap(),
                        _labeled(
                          'Bank name',
                          TextFormField(
                            controller: _bankNameCtrl,
                            style: _inputStyle,
                            decoration: _dec(
                              icon: Icons.account_balance_outlined,
                            ),
                          ),
                        ),
                        _gap(),
                        _labeled(
                          'Bank account no.',
                          TextFormField(
                            controller: _bankAcctCtrl,
                            style: _inputStyle,
                            keyboardType: TextInputType.number,
                            decoration: _dec(icon: Icons.numbers_rounded),
                            validator: ProfileValidators.bankAccount,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _sectionCard(
                      title: 'Education',
                      icon: Icons.school_outlined,
                      children: [
                        _labeled(
                          'Highest level',
                          TextFormField(
                            controller: _eduLevelCtrl,
                            style: _inputStyle,
                            decoration: _dec(icon: Icons.school_outlined),
                          ),
                        ),
                        _gap(),
                        _labeled(
                          'Institution',
                          TextFormField(
                            controller: _eduInstCtrl,
                            style: _inputStyle,
                            decoration: _dec(icon: Icons.domain_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _sectionCard(
                      title: 'Emergency contact',
                      icon: Icons.contact_emergency_outlined,
                      children: [
                        _labeled(
                          'Name',
                          TextFormField(
                            controller: _emeNameCtrl,
                            style: _inputStyle,
                            decoration:
                                _dec(icon: Icons.person_outline_rounded),
                          ),
                        ),
                        _gap(),
                        _labeled(
                          'Relationship',
                          TextFormField(
                            controller: _emeRelCtrl,
                            style: _inputStyle,
                            decoration: _dec(icon: Icons.group_outlined),
                          ),
                        ),
                        _gap(),
                        _labeled(
                          'Phone',
                          TextFormField(
                            controller: _emePhoneCtrl,
                            style: _inputStyle,
                            keyboardType: TextInputType.phone,
                            decoration: _dec(icon: Icons.phone_outlined),
                            validator: ProfileValidators.phoneMalaysia,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton(
                        onPressed: (_saving || !canEdit) ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              _navy.withValues(alpha: 0.45),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_radius),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Save changes',
                                style: _ui.copyWith(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        onPressed:
                            _saving ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _label,
                          side: const BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_radius),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: _ui.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _label,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

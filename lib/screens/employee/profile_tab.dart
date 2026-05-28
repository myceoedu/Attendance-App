import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/app_theme.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../services/employee_profile_pdf.dart';
import '../../utils/app_time.dart';
import '../../utils/profile_validators.dart';
import '../change_password_screen.dart';
import '../help_support_screen.dart';
import 'employee_payroll_history_screen.dart';

enum _ProfileSectionKey {
  personal,
  employment,
  statutory,
  bank,
  education,
  emergency,
}

Set<_ProfileSectionKey> _defaultExpandedForView() => {
      _ProfileSectionKey.personal,
      _ProfileSectionKey.employment,
    };

String _profileSectionSubtitle(_ProfileSectionKey section, AppUser u) {
  switch (section) {
    case _ProfileSectionKey.personal:
      final name = u.name.trim();
      final phone = u.phone?.trim() ?? '';
      if (name.isEmpty) return 'Add your personal details';
      if (phone.isEmpty) return '$name · Mobile not set';
      return '$name · $phone';
    case _ProfileSectionKey.employment:
      final j = u.jobTitle?.trim() ?? '';
      final d = u.department?.trim() ?? '';
      if (j.isNotEmpty && d.isNotEmpty) return '$j · $d';
      if (j.isNotEmpty) return j;
      if (d.isNotEmpty) return d;
      final jd = u.employmentStartDate;
      if (jd != null) {
        return 'Joined ${DateFormat('d MMM yyyy').format(jd)}';
      }
      return 'Role & employment details';
    case _ProfileSectionKey.statutory:
      final hasEpf = u.epfNumber?.trim().isNotEmpty ?? false;
      final hasSocso = u.socsoNumber?.trim().isNotEmpty ?? false;
      if (hasEpf && hasSocso) return 'EPF & SOCSO on file';
      if (hasEpf) return 'EPF on file · SOCSO missing';
      if (hasSocso) return 'SOCSO on file · EPF missing';
      return 'EPF & SOCSO not updated yet';
    case _ProfileSectionKey.bank:
      final bn = u.bankName?.trim() ?? '';
      final ac = u.bankAccountNumber?.trim() ?? '';
      if (bn.isEmpty && ac.isEmpty) return 'Bank details not updated yet';
      if (bn.isNotEmpty) return bn;
      return 'Account on file';
    case _ProfileSectionKey.education:
      final el = u.educationLevel?.trim() ?? '';
      if (el.isNotEmpty) return el;
      final inst = u.educationInstitution?.trim() ?? '';
      if (inst.isNotEmpty) return inst;
      return 'Education not updated yet';
    case _ProfileSectionKey.emergency:
      final n = u.emergencyContactName?.trim() ?? '';
      if (n.isEmpty) return 'Emergency contact not set';
      return n;
  }
}

/// Employee profile & self-service information center (view / edit).
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  bool _editing = false;
  bool _saving = false;
  bool _exportingPdf = false;

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
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _emailCtrl;

  String _maritalValue = '';
  DateTime? _dob;
  late DateTime _joinDate;

  Set<_ProfileSectionKey> _expandedSections = _defaultExpandedForView();
  String? _expansionUserId;

  @override
  void initState() {
    super.initState();
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
    _usernameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    final u = context.read<AuthProvider>().user;
    if (u != null) {
      _applyUser(u);
    } else {
      final n = AppTime.malaysiaNow();
      _joinDate = DateTime(n.year, n.month, n.day);
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
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _applyUser(AppUser u) {
    _usernameCtrl.text = u.username;
    _emailCtrl.text = u.email;
    _nameCtrl.text = u.name;
    _phoneCtrl.text = u.phone ?? '';
    _addressCtrl.text = u.address ?? '';
    _maritalValue = u.maritalStatus ?? '';
    _dob = u.dateOfBirth;
    _icCtrl.text = u.icNumber ?? '';
    _jobCtrl.text = u.jobTitle ?? '';
    _deptCtrl.text = u.department ?? '';
    _empIdCtrl.text = u.employeeCode ?? '';
    _epfCtrl.text = u.epfNumber ?? '';
    _socsoCtrl.text = u.socsoNumber ?? '';
    _bankNameCtrl.text = u.bankName ?? '';
    _bankAcctCtrl.text = u.bankAccountNumber ?? '';
    _eduLevelCtrl.text = u.educationLevel ?? '';
    _eduInstCtrl.text = u.educationInstitution ?? '';
    _emeNameCtrl.text = u.emergencyContactName ?? '';
    _emeRelCtrl.text = u.emergencyContactRelationship ?? '';
    _emePhoneCtrl.text = u.emergencyContactPhone ?? '';
    final emp = u.employmentStartDate;
    if (emp != null) {
      _joinDate = DateTime(emp.year, emp.month, emp.day);
    } else {
      final c = u.createdAt;
      _joinDate = DateTime(c.year, c.month, c.day);
    }
  }

  int _completionPercent(AppUser u) {
    var ok = 0;
    const total = 21;
    void hit(String? s) {
      if (s != null && s.trim().isNotEmpty) ok++;
    }

    hit(u.name);
    hit(u.email);
    hit(u.phone);
    hit(u.address);
    hit(u.maritalStatus);
    if (u.dateOfBirth != null) ok++;
    hit(u.icNumber);
    hit(u.jobTitle);
    hit(u.department);
    hit(u.employeeCode);
    if (u.employmentStartDate != null) ok++;
    hit(u.epfNumber);
    hit(u.socsoNumber);
    hit(u.bankName);
    hit(u.bankAccountNumber);
    hit(u.educationLevel);
    hit(u.educationInstitution);
    hit(u.emergencyContactName);
    hit(u.emergencyContactRelationship);
    hit(u.emergencyContactPhone);
    return ((ok / total) * 100).round().clamp(0, 100);
  }

  String _joinDateLabel(AppUser u) {
    final d = u.employmentStartDate ?? u.createdAt;
    return DateFormat('d MMM yyyy').format(d);
  }

  Future<void> _pickDob() async {
    final now = AppTime.malaysiaNow();
    final first = DateTime(now.year - 70);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: first,
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _pickJoinDate() async {
    final now = AppTime.malaysiaNow();
    final first = DateTime(now.year - 50);
    final picked = await showDatePicker(
      context: context,
      initialDate: _joinDate,
      firstDate: first,
      lastDate: now,
    );
    if (picked != null) {
      setState(
        () => _joinDate = DateTime(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _onRefresh() async {
    final auth = context.read<AuthProvider>();
    await auth.refreshProfile();
    if (!mounted) return;
    final u = auth.user;
    if (u != null) setState(() => _applyUser(u));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ename = _emeNameCtrl.text.trim();
    if (ename.isNotEmpty) {
      final ep = _emePhoneCtrl.text.trim();
      if (ep.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add emergency contact phone')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    final err = await context.read<AuthProvider>().updateEmployeeProfileFull(
          name: _nameCtrl.text,
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
          employmentStartDate: _joinDate,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.danger),
      );
    } else {
      setState(() {
        _editing = false;
        _expandedSections = _defaultExpandedForView();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _cancelEdit(AppUser u) {
    setState(() {
      _editing = false;
      _applyUser(u);
      _expandedSections = _defaultExpandedForView();
    });
  }

  void _toggleSection(_ProfileSectionKey key) {
    setState(() {
      if (_expandedSections.contains(key)) {
        _expandedSections = Set<_ProfileSectionKey>.from(_expandedSections)
          ..remove(key);
      } else {
        _expandedSections = Set<_ProfileSectionKey>.from(_expandedSections)
          ..add(key);
      }
    });
  }

  Future<void> _exportPdf(AppUser u) async {
    setState(() => _exportingPdf = true);
    try {
      await EmployeeProfilePdf.shareProfilePdf(u);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              auth.signOut();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthProvider, AppUser?>((a) => a.user);
    if (user == null) return const SizedBox.shrink();

    if (_expansionUserId != user.id) {
      _expansionUserId = user.id;
      _expandedSections = _defaultExpandedForView();
    }

    final dateFmtLong = DateFormat('d MMM yyyy');
    final pct = _completionPercent(user);

    Widget body = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _ProfileHeader(
          user: user,
          editing: _editing,
          pct: pct,
          onTogglePhoto: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile photo upload will be available soon.'),
              ),
            );
          },
        )),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _expandedSections =
                                Set<_ProfileSectionKey>.from(_ProfileSectionKey.values);
                          });
                        },
                        child: const Text('Expand all'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _expandedSections = {});
                        },
                        child: const Text('Collapse all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  _ProfileExpandableSection(
                    title: 'Personal information',
                    icon: Icons.person_outline_rounded,
                    accent: AppColors.indigo,
                    subtitle:
                        _profileSectionSubtitle(_ProfileSectionKey.personal, user),
                    expanded:
                        _expandedSections.contains(_ProfileSectionKey.personal),
                    onToggle: () => _toggleSection(_ProfileSectionKey.personal),
                    body: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      if (!_editing) ...[
                        _viewRow(Icons.badge_outlined, 'Full name', user.name),
                        _viewRow(Icons.phone_iphone_rounded, 'Mobile',
                            ProfileValidators.displayValue(user.phone, editing: false)),
                        _viewRow(Icons.home_outlined, 'Current address',
                            ProfileValidators.displayValue(user.address, editing: false)),
                        _viewRow(Icons.favorite_outline_rounded, 'Marital status',
                            ProfileValidators.displayValue(user.maritalStatus, editing: false)),
                        _viewRow(Icons.cake_outlined, 'Date of birth',
                            user.dateOfBirth != null
                                ? dateFmtLong.format(user.dateOfBirth!)
                                : 'Not updated yet'),
                        _viewRow(Icons.credit_card_outlined, 'IC number',
                            user.icNumber == null || user.icNumber!.trim().isEmpty
                                ? 'Not updated yet'
                                : ProfileValidators.displayIcMasked(user.icNumber)),
                      ] else ...[
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: _dec(Icons.badge_outlined, 'Full name'),
                          validator: ProfileValidators.requiredName,
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: _dec(Icons.phone_iphone_rounded, 'Mobile number'),
                          validator: ProfileValidators.phoneMalaysia,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _addressCtrl,
                          maxLines: 2,
                          decoration: _dec(Icons.home_outlined, 'Current address'),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey<String>('marital_$_maritalValue'),
                          initialValue:
                              _maritalValue.isEmpty ? '' : _maritalValue,
                          decoration: _dec(
                            Icons.favorite_outline_rounded,
                            'Marital status',
                          ),
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
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.cake_outlined, color: AppColors.primary.withValues(alpha: 0.85)),
                          title: const Text('Date of birth'),
                          subtitle: Text(
                            _dob == null
                                ? 'Tap to select'
                                : dateFmtLong.format(_dob!),
                            style: TextStyle(
                              color: _dob == null
                                  ? AppColors.textHint
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: const Icon(Icons.edit_calendar_outlined),
                          onTap: _pickDob,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _icCtrl,
                          decoration: _dec(
                            Icons.credit_card_outlined,
                            'IC number (######-##-####)',
                          ),
                          validator: ProfileValidators.icNumber,
                        ),
                      ],
                      const SizedBox(height: 8),
                      _readonlyBlock(),
                    ],
                  ),
                ),
                  const SizedBox(height: 10),
                  _ProfileExpandableSection(
                    title: 'Employment information',
                    icon: Icons.work_outline_rounded,
                    accent: AppColors.teal,
                    subtitle:
                        _profileSectionSubtitle(_ProfileSectionKey.employment, user),
                    expanded: _expandedSections
                        .contains(_ProfileSectionKey.employment),
                    onToggle: () => _toggleSection(_ProfileSectionKey.employment),
                    body: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      _viewRow(
                        Icons.shield_outlined,
                        'Role',
                        user.isAdmin ? 'Administrator' : 'Employee',
                      ),
                      if (!_editing)
                        _viewRow(
                          Icons.event_outlined,
                          'Join date',
                          _joinDateLabel(user),
                        )
                      else ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.event_outlined,
                            color: AppColors.primary.withValues(alpha: 0.85),
                          ),
                          title: const Text('Join date'),
                          subtitle: Text(
                            dateFmtLong.format(_joinDate),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: const Icon(Icons.edit_calendar_outlined),
                          onTap: _pickJoinDate,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'If your start date was recorded wrong, update it here. '
                          'Annual leave calculations may use this date.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary.withValues(alpha: 0.9),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (!_editing) ...[
                        _viewRow(
                          Icons.workspace_premium_outlined,
                          'Position',
                          ProfileValidators.displayValue(user.jobTitle, editing: false),
                        ),
                        _viewRow(
                          Icons.apartment_outlined,
                          'Department',
                          ProfileValidators.displayValue(user.department, editing: false),
                        ),
                        _viewRow(
                          Icons.badge_rounded,
                          'Employee ID',
                          ProfileValidators.displayValue(user.employeeCode, editing: false),
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _jobCtrl,
                          decoration: _dec(
                            Icons.workspace_premium_outlined,
                            'Position / role title',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _deptCtrl,
                          decoration: _dec(Icons.apartment_outlined, 'Department'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _empIdCtrl,
                          decoration: _dec(Icons.badge_rounded, 'Employee ID'),
                        ),
                      ],
                    ],
                  ),
                ),
                  const SizedBox(height: 10),
                  _ProfileExpandableSection(
                    title: 'Statutory (Malaysia)',
                    icon: Icons.account_balance_outlined,
                    accent: AppColors.sky,
                    subtitle:
                        _profileSectionSubtitle(_ProfileSectionKey.statutory, user),
                    expanded: _expandedSections
                        .contains(_ProfileSectionKey.statutory),
                    onToggle: () => _toggleSection(_ProfileSectionKey.statutory),
                    body: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      if (!_editing) ...[
                        _viewRow(
                          Icons.savings_outlined,
                          'EPF number',
                          ProfileValidators.displayValue(user.epfNumber, editing: false),
                        ),
                        _viewRow(
                          Icons.health_and_safety_outlined,
                          'SOCSO number',
                          ProfileValidators.displayValue(user.socsoNumber, editing: false),
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _epfCtrl,
                          decoration: _dec(Icons.savings_outlined, 'EPF number'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _socsoCtrl,
                          decoration:
                              _dec(Icons.health_and_safety_outlined, 'SOCSO number'),
                        ),
                      ],
                    ],
                  ),
                ),
                  const SizedBox(height: 10),
                  _ProfileExpandableSection(
                    title: 'Bank information',
                    icon: Icons.account_balance_wallet_outlined,
                    accent: AppColors.violet,
                    subtitle: _profileSectionSubtitle(_ProfileSectionKey.bank, user),
                    expanded: _expandedSections.contains(_ProfileSectionKey.bank),
                    onToggle: () => _toggleSection(_ProfileSectionKey.bank),
                    body: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      if (!_editing) ...[
                        _viewRow(
                          Icons.account_balance_outlined,
                          'Bank name',
                          ProfileValidators.displayValue(user.bankName, editing: false),
                        ),
                        _viewRow(
                          Icons.numbers_rounded,
                          'Account number',
                          user.bankAccountNumber == null ||
                                  user.bankAccountNumber!.trim().isEmpty
                              ? 'Not updated yet'
                              : ProfileValidators.displayBankMasked(
                                  user.bankAccountNumber),
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _bankNameCtrl,
                          decoration: _dec(Icons.account_balance_outlined, 'Bank name'),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _bankAcctCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _dec(Icons.numbers_rounded, 'Bank account number'),
                          validator: ProfileValidators.bankAccount,
                        ),
                      ],
                    ],
                  ),
                ),
                  const SizedBox(height: 10),
                  _ProfileExpandableSection(
                    title: 'Education',
                    icon: Icons.school_outlined,
                    accent: AppColors.orange,
                    subtitle:
                        _profileSectionSubtitle(_ProfileSectionKey.education, user),
                    expanded:
                        _expandedSections.contains(_ProfileSectionKey.education),
                    onToggle: () => _toggleSection(_ProfileSectionKey.education),
                    body: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      if (!_editing) ...[
                        _viewRow(
                          Icons.stacked_bar_chart_outlined,
                          'Highest level of studies',
                          ProfileValidators.displayValue(user.educationLevel,
                              editing: false),
                        ),
                        _viewRow(
                          Icons.domain_outlined,
                          'College / university',
                          ProfileValidators.displayValue(
                            user.educationInstitution,
                            editing: false,
                          ),
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _eduLevelCtrl,
                          decoration: _dec(
                            Icons.stacked_bar_chart_outlined,
                            'Highest level (e.g. Bachelor)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _eduInstCtrl,
                          decoration: _dec(Icons.domain_outlined, 'Institution name'),
                          textCapitalization: TextCapitalization.words,
                        ),
                      ],
                    ],
                  ),
                ),
                  const SizedBox(height: 10),
                  _ProfileExpandableSection(
                    title: 'Emergency contact',
                    icon: Icons.contact_phone_outlined,
                    accent: AppColors.danger,
                    subtitle: _profileSectionSubtitle(
                      _ProfileSectionKey.emergency,
                      user,
                    ),
                    expanded:
                        _expandedSections.contains(_ProfileSectionKey.emergency),
                    onToggle: () => _toggleSection(_ProfileSectionKey.emergency),
                    body: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      if (!_editing) ...[
                        _viewRow(
                          Icons.person_outline_rounded,
                          'Contact name',
                          ProfileValidators.displayValue(
                            user.emergencyContactName,
                            editing: false,
                          ),
                        ),
                        _viewRow(
                          Icons.group_outlined,
                          'Relationship',
                          ProfileValidators.displayValue(
                            user.emergencyContactRelationship,
                            editing: false,
                          ),
                        ),
                        _viewRow(
                          Icons.phone_callback_outlined,
                          'Phone',
                          ProfileValidators.displayValue(
                            user.emergencyContactPhone,
                            editing: false,
                          ),
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _emeNameCtrl,
                          decoration: _dec(Icons.person_outline_rounded, 'Contact name'),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emeRelCtrl,
                          decoration: _dec(Icons.group_outlined, 'Relationship'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emePhoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration:
                              _dec(Icons.phone_callback_outlined, 'Phone number'),
                          validator: ProfileValidators.phoneMalaysia,
                        ),
                      ],
                    ],
                  ),
                ),
                  const SizedBox(height: 20),
                  if (!user.isAdmin) ...[
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.violetLight.withValues(alpha: 0.85),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            color: AppColors.violet,
                          ),
                        ),
                        title: const Text(
                          'My payslips',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'Pay history and PDF downloads',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.92),
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color:
                              AppColors.textHint.withValues(alpha: 0.85),
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const EmployeePayrollHistoryScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _QuickActions(
                    editing: _editing,
                    saving: _saving,
                    exportingPdf: _exportingPdf,
                    onStartEdit: () => setState(() {
                      _editing = true;
                      _expandedSections =
                          Set<_ProfileSectionKey>.from(_ProfileSectionKey.values);
                    }),
                    onSave: _save,
                    onCancel: () => _cancelEdit(user),
                    onHelpSupport: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => HelpSupportScreen(
                            adminView: user.isAdmin,
                          ),
                        ),
                      );
                    },
                    onChangePassword: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      );
                    },
                    onDownloadPdf: () => _exportPdf(user),
                    onSignOut: () =>
                        _confirmLogout(context, context.read<AuthProvider>()),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    return SizedBox.expand(
      child: ColoredBox(
        color: AppColors.surface,
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: body,
        ),
      ),
    );
  }

  InputDecoration _dec(IconData icon, String label) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 22),
      alignLabelWithHint: true,
    );
  }

  Widget _readonlyBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        TextFormField(
          controller: _usernameCtrl,
          readOnly: true,
          decoration: _dec(Icons.alternate_email, 'Username'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emailCtrl,
          readOnly: true,
          decoration: _dec(Icons.email_outlined, 'Email'),
        ),
      ],
    );
  }

  Widget _viewRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: value == 'Not updated yet'
                        ? AppColors.textHint
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.editing,
    required this.pct,
    required this.onTogglePhoto,
  });

  final AppUser user;
  final bool editing;
  final int pct;
  final VoidCallback onTogglePhoto;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppChrome.onBrand,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppGradients.brandHeader,
          border: Border(bottom: BorderSide(color: AppColors.brandHeaderBorder)),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandHeaderShadow,
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: -4,
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'My profile',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onBrand,
                      ),
                    ),
                    const Spacer(),
                    if (editing)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.onBrand.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Editing',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onBrand,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppGradients.primary,
                        border: Border.all(
                          color: AppColors.brandAvatarRing,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.22),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        user.name.isNotEmpty
                            ? user.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onBrand,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -2,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: IconButton(
                          tooltip: 'Change photo',
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 36,
                          ),
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          onPressed: onTogglePhoto,
                          icon: Icon(
                            Icons.photo_camera_outlined,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  user.name.isNotEmpty ? user.name : 'Employee',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onBrand,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _chip(
                      user.isAdmin ? 'ADMIN' : 'EMPLOYEE',
                      AppColors.brandChipFill,
                    ),
                    const SizedBox(width: 8),
                    _chip(
                      user.isAdmin ? 'Administrator' : 'Team member',
                      AppColors.onBrand.withValues(alpha: 0.1),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$pct% profile complete — fill empty fields for a complete record',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onBrandSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String t, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brandChipBorder),
      ),
      child: Text(
        t,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.onBrand,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _ProfileExpandableSection extends StatelessWidget {
  const _ProfileExpandableSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.subtitle,
    required this.expanded,
    required this.onToggle,
    required this.body,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final String subtitle;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 8, expanded ? 10 : 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: accent, size: 20),
                    ),
                    const SizedBox(width: 10),
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
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary.withValues(alpha: 0.92),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 2, top: 2),
                      child: AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        child: Icon(
                          Icons.expand_more_rounded,
                          size: 26,
                          color: AppColors.textSecondary.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Visibility(
              visible: expanded,
              maintainState: true,
              maintainAnimation: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 22),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: body,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.editing,
    required this.saving,
    required this.exportingPdf,
    required this.onStartEdit,
    required this.onSave,
    required this.onCancel,
    required this.onHelpSupport,
    required this.onChangePassword,
    required this.onDownloadPdf,
    required this.onSignOut,
  });

  final bool editing;
  final bool saving;
  final bool exportingPdf;
  final VoidCallback onStartEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onHelpSupport;
  final VoidCallback onChangePassword;
  final VoidCallback onDownloadPdf;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Quick actions',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary.withValues(alpha: 0.85),
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 10),
        if (!editing)
          FilledButton.icon(
            onPressed: onStartEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit profile'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          )
        else ...[
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(saving ? 'Saving…' : 'Save changes'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: saving ? null : onCancel,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        _actionTile(
          icon: Icons.support_agent_rounded,
          label: 'Help & support',
          onTap: onHelpSupport,
        ),
        _actionTile(
          icon: Icons.lock_reset_rounded,
          label: 'Change password',
          onTap: onChangePassword,
        ),
        _actionTile(
          icon: Icons.picture_as_pdf_outlined,
          label: exportingPdf ? 'Preparing PDF…' : 'Download employee info (PDF)',
          onTap: exportingPdf ? null : onDownloadPdf,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.danger),
          label: const Text('Sign out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
            backgroundColor: AppColors.dangerLight.withValues(alpha: 0.35),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
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
    );
  }
}

import 'package:flutter/material.dart';
import '../../utils/app_route.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/app_theme.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_time.dart';
import '../../utils/profile_validators.dart';
import '../change_password_screen.dart';
import '../help_support_screen.dart';
import '../../widgets/app_confirm_dialog.dart';

// Profile design system (match Add employee / Employee details).
const Color _kNavy = Color(0xFF14213D);
const Color _kPageBg = Color(0xFFF5F6F8);
const Color _kBorder = Color(0xFFE4E6EB);
const Color _kInputBorder = Color(0xFFD8DBE2);
const Color _kMuted = Color(0xFF9AA1AD);
const Color _kHairline = Color(0xFFEEF0F3);
const Color _kAvatarTile = Color(0xFFE9EBF2);
const Color _kProgressGreen = Color(0xFF5DCAA5);
const Color _kAmber = Color(0xFFC9A961);
const Color _kAmberBorder = Color(0xFFE0C088);
const Color _kAmberBg = Color(0xFFFDF9F1);
const Color _kLockedBorder = Color(0xFFEEF0F3);
const Color _kLockedBg = Color(0xFFFAFAFA);
const Color _kLockedText = Color(0xFFB4B9C2);
const Color _kLinkBlue = Color(0xFF185FA5);

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

final DateFormat _dateFmtLong = DateFormat('d MMM yyyy');

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
        return 'Joined ${_dateFmtLong.format(jd)}';
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

  /// Section subtitles + completion % for the current profile.
  AppUser? _derivedFrom;
  int _completion = 0;
  Map<_ProfileSectionKey, String> _sectionSubtitles = const {};

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncForUser(context.read<AuthProvider>().user);
  }

  void _syncForUser(AppUser? user) {
    if (user == null) return;
    if (_expansionUserId != user.id) {
      _expansionUserId = user.id;
      _expandedSections = _defaultExpandedForView();
    }
    if (!identical(_derivedFrom, user)) {
      _derivedFrom = user;
      _completion = _completionPercent(user);
      _sectionSubtitles = {
        for (final key in _ProfileSectionKey.values)
          key: _profileSectionSubtitle(key, user),
      };
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
    return _dateFmtLong.format(d);
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

  Future<void> _confirmLogout(BuildContext context, AuthProvider auth) async {
    final ok = await showAppConfirmDialog(
      context: context,
      title: 'Sign out?',
      message: 'You will need to sign in again to use the app.',
      cancelLabel: 'Stay',
      confirmLabel: 'Sign out',
      emphasis: AppConfirmEmphasis.safe,
      confirmColor: AppColors.danger,
    );
    if (ok && context.mounted) {
      auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthProvider, AppUser?>((a) => a.user);
    if (user == null) return const SizedBox.shrink();

    if (!identical(_derivedFrom, user)) _syncForUser(user);

    final dateFmtLong = _dateFmtLong;
    final pct = _completion;
    final subtitles = _sectionSubtitles;

    Widget body = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _ProfileHeader(
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
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: _kBorder),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: _kLinkBlue,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                textStyle: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _expandedSections =
                                      Set<_ProfileSectionKey>.from(
                                    _ProfileSectionKey.values,
                                  );
                                });
                              },
                              child: const Text('Expand all'),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: _kMuted,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                textStyle: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              onPressed: () {
                                setState(() => _expandedSections = {});
                              },
                              child: const Text('Collapse all'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _ProfileExpandableSection(
                    title: 'Personal information',
                    icon: Icons.person_outline_rounded,
                    subtitle: subtitles[_ProfileSectionKey.personal]!,
                    expanded: _expandedSections.contains(
                      _ProfileSectionKey.personal,
                    ),
                    onToggle: () => _toggleSection(_ProfileSectionKey.personal),
                    body: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_editing) ...[
                          _viewRow(
                            Icons.badge_outlined,
                            'Full name',
                            user.name,
                          ),
                          _viewRow(
                            Icons.phone_iphone_rounded,
                            'Mobile',
                            ProfileValidators.displayValue(
                              user.phone,
                              editing: false,
                            ),
                          ),
                          _viewRow(
                            Icons.home_outlined,
                            'Current address',
                            ProfileValidators.displayValue(
                              user.address,
                              editing: false,
                            ),
                          ),
                          _viewRow(
                            Icons.favorite_outline_rounded,
                            'Marital status',
                            ProfileValidators.displayValue(
                              user.maritalStatus,
                              editing: false,
                            ),
                          ),
                          _viewRow(
                            Icons.cake_outlined,
                            'Date of birth',
                            user.dateOfBirth != null
                                ? dateFmtLong.format(user.dateOfBirth!)
                                : 'Not updated yet',
                          ),
                          _viewRow(
                            Icons.credit_card_outlined,
                            'IC number',
                            user.icNumber == null ||
                                    user.icNumber!.trim().isEmpty
                                ? 'Not updated yet'
                                : ProfileValidators.displayIcMasked(
                                    user.icNumber,
                                  ),
                          ),
                        ] else ...[
                          _editTextField(
                            label: 'Full name',
                            icon: Icons.badge_outlined,
                            controller: _nameCtrl,
                            emptyHint: 'Add your full name',
                            validator: ProfileValidators.requiredName,
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 10),
                          _editTextField(
                            label: 'Mobile number',
                            icon: Icons.phone_iphone_rounded,
                            controller: _phoneCtrl,
                            emptyHint: 'Add your mobile number',
                            keyboardType: TextInputType.phone,
                            validator: ProfileValidators.phoneMalaysia,
                          ),
                          const SizedBox(height: 10),
                          _editTextField(
                            label: 'Current address',
                            icon: Icons.home_outlined,
                            controller: _addressCtrl,
                            emptyHint: 'Add your address',
                            maxLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                          const SizedBox(height: 10),
                          _editDropdownField(
                            label: 'Marital status',
                            icon: Icons.favorite_outline_rounded,
                            value: _maritalValue.isEmpty ? '' : _maritalValue,
                            emptyHint: 'Not set',
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
                          const SizedBox(height: 10),
                          _editDateField(
                            label: 'Date of birth',
                            icon: Icons.cake_outlined,
                            value: _dob == null
                                ? null
                                : dateFmtLong.format(_dob!),
                            emptyHint: 'Tap to select',
                            onTap: _pickDob,
                          ),
                          const SizedBox(height: 10),
                          _editTextField(
                            label: 'IC number',
                            icon: Icons.credit_card_outlined,
                            controller: _icCtrl,
                            emptyHint: '######-##-####',
                            validator: ProfileValidators.icNumber,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _lockedField(
                    label: 'Username',
                    icon: Icons.alternate_email,
                    value: _usernameCtrl.text.isNotEmpty
                        ? _usernameCtrl.text
                        : '—',
                  ),
                  const SizedBox(height: 10),
                  _lockedField(
                    label: 'Email',
                    icon: Icons.email_outlined,
                    value: _emailCtrl.text.isNotEmpty ? _emailCtrl.text : '—',
                  ),
                  const SizedBox(height: 10),
                  _scrollMoreHint(),
                  const SizedBox(height: 10),
                  _ProfileExpandableSection(
                    title: 'Employment information',
                    icon: Icons.work_outline_rounded,
                    subtitle: subtitles[_ProfileSectionKey.employment]!,
                    expanded: _expandedSections.contains(
                      _ProfileSectionKey.employment,
                    ),
                    onToggle: () =>
                        _toggleSection(_ProfileSectionKey.employment),
                    body: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_editing)
                          _viewRow(
                            Icons.shield_outlined,
                            'Role',
                            user.isAdmin ? 'Administrator' : 'Employee',
                          )
                        else
                          _lockedField(
                            label: 'Role',
                            icon: Icons.shield_outlined,
                            value: user.isAdmin ? 'Administrator' : 'Employee',
                          ),
                        if (!_editing)
                          _viewRow(
                            Icons.event_outlined,
                            'Join date',
                            _joinDateLabel(user),
                          )
                        else ...[
                          _editDateField(
                            label: 'Join date',
                            icon: Icons.event_outlined,
                            value: dateFmtLong.format(_joinDate),
                            emptyHint: 'Tap to select',
                            onTap: _pickJoinDate,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'If your start date was recorded wrong, update it here. '
                            'Annual leave calculations may use this date.',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: _kMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        if (!_editing) ...[
                          _viewRow(
                            Icons.workspace_premium_outlined,
                            'Position',
                            ProfileValidators.displayValue(
                              user.jobTitle,
                              editing: false,
                            ),
                          ),
                          _viewRow(
                            Icons.apartment_outlined,
                            'Department',
                            ProfileValidators.displayValue(
                              user.department,
                              editing: false,
                            ),
                          ),
                          _viewRow(
                            Icons.badge_rounded,
                            'Employee ID',
                            ProfileValidators.displayValue(
                              user.employeeCode,
                              editing: false,
                            ),
                          ),
                        ] else ...[
                          _editTextField(
                            label: 'Position',
                            icon: Icons.workspace_premium_outlined,
                            controller: _jobCtrl,
                            emptyHint: 'Add your position',
                          ),
                          const SizedBox(height: 10),
                          _editTextField(
                            label: 'Department',
                            icon: Icons.apartment_outlined,
                            controller: _deptCtrl,
                            emptyHint: 'Add your department',
                          ),
                          const SizedBox(height: 10),
                          _editTextField(
                            label: 'Employee ID',
                            icon: Icons.badge_rounded,
                            controller: _empIdCtrl,
                            emptyHint: 'Add employee ID',
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ProfileExpandableSection(
                    title: 'Statutory (Malaysia)',
                    icon: Icons.account_balance_outlined,
                    subtitle: subtitles[_ProfileSectionKey.statutory]!,
                    expanded: _expandedSections.contains(
                      _ProfileSectionKey.statutory,
                    ),
                    onToggle: () =>
                        _toggleSection(_ProfileSectionKey.statutory),
                    body: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_editing) ...[
                          _viewRow(
                            Icons.account_balance_wallet_outlined,
                            'EPF number',
                            ProfileValidators.displayValue(
                              user.epfNumber,
                              editing: false,
                            ),
                          ),
                          _viewRow(
                            Icons.health_and_safety_outlined,
                            'SOCSO number',
                            ProfileValidators.displayValue(
                              user.socsoNumber,
                              editing: false,
                            ),
                          ),
                        ] else ...[
                          _editTextField(
                            label: 'EPF number',
                            icon: Icons.account_balance_wallet_outlined,
                            controller: _epfCtrl,
                            emptyHint: 'Add EPF number',
                          ),
                          const SizedBox(height: 10),
                          _editTextField(
                            label: 'SOCSO number',
                            icon: Icons.health_and_safety_outlined,
                            controller: _socsoCtrl,
                            emptyHint: 'Add SOCSO number',
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ProfileExpandableSection(
                    title: 'Bank information',
                    icon: Icons.account_balance_wallet_outlined,
                    subtitle: subtitles[_ProfileSectionKey.bank]!,
                    expanded: _expandedSections.contains(
                      _ProfileSectionKey.bank,
                    ),
                    onToggle: () => _toggleSection(_ProfileSectionKey.bank),
                    body: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_editing) ...[
                          _viewRow(
                            Icons.account_balance_outlined,
                            'Bank name',
                            ProfileValidators.displayValue(
                              user.bankName,
                              editing: false,
                            ),
                          ),
                          _viewRow(
                            Icons.numbers_rounded,
                            'Account number',
                            user.bankAccountNumber == null ||
                                    user.bankAccountNumber!.trim().isEmpty
                                ? 'Not updated yet'
                                : ProfileValidators.displayBankMasked(
                                    user.bankAccountNumber,
                                  ),
                          ),
                        ] else ...[
                          _editTextField(
                            label: 'Bank name',
                            icon: Icons.account_balance_outlined,
                            controller: _bankNameCtrl,
                            emptyHint: 'Add bank name',
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 10),
                          _editTextField(
                            label: 'Bank account number',
                            icon: Icons.numbers_rounded,
                            controller: _bankAcctCtrl,
                            emptyHint: 'Add account number',
                            keyboardType: TextInputType.number,
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
                    subtitle: subtitles[_ProfileSectionKey.education]!,
                    expanded: _expandedSections.contains(
                      _ProfileSectionKey.education,
                    ),
                    onToggle: () =>
                        _toggleSection(_ProfileSectionKey.education),
                    body: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_editing) ...[
                          _viewRow(
                            Icons.stacked_bar_chart_outlined,
                            'Highest level of studies',
                            ProfileValidators.displayValue(
                              user.educationLevel,
                              editing: false,
                            ),
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
                          _editTextField(
                            label: 'Highest level of studies',
                            icon: Icons.stacked_bar_chart_outlined,
                            controller: _eduLevelCtrl,
                            emptyHint: 'e.g. Bachelor',
                          ),
                          const SizedBox(height: 10),
                          _editTextField(
                            label: 'College / university',
                            icon: Icons.domain_outlined,
                            controller: _eduInstCtrl,
                            emptyHint: 'Add institution name',
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
                    subtitle: subtitles[_ProfileSectionKey.emergency]!,
                    expanded: _expandedSections.contains(
                      _ProfileSectionKey.emergency,
                    ),
                    onToggle: () =>
                        _toggleSection(_ProfileSectionKey.emergency),
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
                          _editTextField(
                            label: 'Contact name',
                            icon: Icons.person_outline_rounded,
                            controller: _emeNameCtrl,
                            emptyHint: 'Add contact name',
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 10),
                          _editTextField(
                            label: 'Relationship',
                            icon: Icons.group_outlined,
                            controller: _emeRelCtrl,
                            emptyHint: 'Add relationship',
                          ),
                          const SizedBox(height: 10),
                          _editTextField(
                            label: 'Phone number',
                            icon: Icons.phone_callback_outlined,
                            controller: _emePhoneCtrl,
                            emptyHint: 'Add phone number',
                            keyboardType: TextInputType.phone,
                            validator: ProfileValidators.phoneMalaysia,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _QuickActions(
                    editing: _editing,
                    saving: _saving,
                    onStartEdit: () => setState(() {
                      _editing = true;
                      _expandedSections = Set<_ProfileSectionKey>.from(
                        _ProfileSectionKey.values,
                      );
                    }),
                    onSave: _save,
                    onCancel: () => _cancelEdit(user),
                    onHelpSupport: () {
                      pushAppPage(
                        context,
                        HelpSupportScreen(adminView: user.isAdmin),
                      );
                    },
                    onChangePassword: () {
                      pushAppPage(context, const ChangePasswordScreen());
                    },
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

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      child: SizedBox.expand(
        child: ColoredBox(
          color: _kPageBg,
          child: RefreshIndicator(
            color: _kNavy,
            onRefresh: _onRefresh,
            child: body,
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: _kMuted,
        ),
      ),
    );
  }

  InputDecoration _editInputDec({
    required IconData icon,
    required bool empty,
    String? hint,
    int maxLines = 1,
  }) {
    final iconColor = empty ? _kAmber : _kMuted;
    final transparent = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    );
    final solid = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _kInputBorder),
    );
    final focused = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: empty ? _kAmber : _kNavy,
        width: empty ? 1.5 : 1.5,
      ),
    );

    return InputDecoration(
      hintText: empty ? hint : null,
      hintStyle: GoogleFonts.inter(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: _kAmber,
      ),
      prefixIcon: Icon(icon, size: 18, color: iconColor),
      isDense: true,
      filled: true,
      fillColor: empty ? _kAmberBg : Colors.white,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: maxLines > 1 ? 12 : 10,
      ),
      border: empty ? transparent : solid,
      enabledBorder: empty ? transparent : solid,
      focusedBorder: empty ? transparent : focused,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
    );
  }

  Widget _wrapEditBox({
    required bool empty,
    required Widget child,
    int maxLines = 1,
  }) {
    final box = ConstrainedBox(
      constraints: BoxConstraints(minHeight: maxLines > 1 ? 64 : 40),
      child: child,
    );
    if (!empty) return box;
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: _kAmberBorder,
        radius: 8,
        strokeWidth: 1.5,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColoredBox(
          color: _kAmberBg,
          child: box,
        ),
      ),
    );
  }

  Widget _editTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String emptyHint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
  }) {
    final empty = controller.text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fieldLabel(label),
        _wrapEditBox(
          empty: empty,
          maxLines: maxLines,
          child: TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            maxLines: maxLines,
            minLines: maxLines > 1 ? maxLines : 1,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              fontStyle: empty ? FontStyle.italic : FontStyle.normal,
              color: empty ? _kAmber : _kNavy,
            ),
            decoration: _editInputDec(
              icon: icon,
              empty: empty,
              hint: emptyHint,
              maxLines: maxLines,
            ),
          ),
        ),
      ],
    );
  }

  Widget _editDropdownField({
    required String label,
    required IconData icon,
    required String value,
    required String emptyHint,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final empty = value.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fieldLabel(label),
        _wrapEditBox(
          empty: empty,
          child: DropdownButtonFormField<String>(
            key: ValueKey<String>('dd_${label}_$value'),
            initialValue: value,
            items: items,
            onChanged: onChanged,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: empty ? _kAmber : _kMuted,
              size: 20,
            ),
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              fontStyle: empty ? FontStyle.italic : FontStyle.normal,
              color: empty ? _kAmber : _kNavy,
            ),
            dropdownColor: Colors.white,
            decoration: _editInputDec(
              icon: icon,
              empty: empty,
              hint: emptyHint,
            ),
          ),
        ),
      ],
    );
  }

  Widget _editDateField({
    required String label,
    required IconData icon,
    required String? value,
    required String emptyHint,
    required VoidCallback onTap,
  }) {
    final empty = value == null || value.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fieldLabel(label),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: _wrapEditBox(
              empty: empty,
              child: InputDecorator(
                decoration: _editInputDec(
                  icon: icon,
                  empty: empty,
                  hint: emptyHint,
                ).copyWith(
                  suffixIcon: Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: empty ? _kAmber : _kMuted,
                  ),
                ),
                child: Text(
                  empty ? emptyHint : value,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                    color: empty ? _kAmber : _kNavy,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _lockedField({
    required String label,
    required IconData icon,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fieldLabel(label),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _kLockedBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kLockedBorder),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: _kLockedText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: _kLockedText,
                  ),
                ),
              ),
              const Icon(Icons.lock_outline_rounded, size: 15, color: _kLockedText),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scrollMoreHint() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Scroll for more',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _kMuted,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: _kMuted,
          ),
        ],
      ),
    );
  }

  Widget _viewRow(IconData icon, String label, String value) {
    final empty = value == 'Not updated yet';
    final accent = empty ? _kAmber : _kMuted;
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kHairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: _kMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: empty ? FontWeight.w400 : FontWeight.w500,
                      fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                      color: empty ? _kAmber : _kNavy,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1.5,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  static const double _dash = 4;
  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth;
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
        color: _kNavy,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'My profile',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
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
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Editing',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(
                          side: BorderSide(color: _kNavy, width: 2),
                        ),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onTogglePhoto,
                          child: const SizedBox(
                            width: 26,
                            height: 26,
                            child: Icon(
                              Icons.photo_camera_outlined,
                              size: 14,
                              color: _kNavy,
                            ),
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
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _chip(user.isAdmin ? 'Admin' : 'Employee'),
                    const SizedBox(width: 8),
                    _chip(user.isAdmin ? 'Administrator' : 'Team member'),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    color: _kProgressGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$pct% complete · fill in the empty fields to finish your profile',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.72),
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

  Widget _chip(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        t,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

class _ProfileExpandableSection extends StatelessWidget {
  const _ProfileExpandableSection({
    required this.title,
    required this.icon,
    required this.subtitle,
    required this.expanded,
    required this.onToggle,
    required this.body,
  });

  final String title;
  final IconData icon;
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
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
                padding: EdgeInsets.fromLTRB(14, 12, 10, expanded ? 10 : 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _kAvatarTile,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: _kNavy, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: _kNavy,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: _kMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: _kMuted,
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
              maintainState: false,
              maintainAnimation: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Divider(height: 1, thickness: 1, color: _kHairline),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
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
    required this.onStartEdit,
    required this.onSave,
    required this.onCancel,
    required this.onHelpSupport,
    required this.onChangePassword,
    required this.onSignOut,
  });

  final bool editing;
  final bool saving;
  final VoidCallback onStartEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onHelpSupport;
  final VoidCallback onChangePassword;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Quick actions',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _kNavy,
          ),
        ),
        const SizedBox(height: 10),
        if (!editing)
          FilledButton.icon(
            onPressed: onStartEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit profile'),
            style: FilledButton.styleFrom(
              backgroundColor: _kNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(saving ? 'Saving…' : 'Save changes'),
            style: FilledButton.styleFrom(
              backgroundColor: _kNavy,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _kNavy.withValues(alpha: 0.45),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: saving ? null : onCancel,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kMuted,
              side: const BorderSide(color: _kBorder),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onSignOut,
          icon: const Icon(
            Icons.logout_rounded,
            size: 18,
            color: AppColors.danger,
          ),
          label: const Text('Sign out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
            backgroundColor: AppColors.dangerLight.withValues(alpha: 0.35),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
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
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              children: [
                Icon(icon, color: _kNavy, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _kNavy,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _kMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

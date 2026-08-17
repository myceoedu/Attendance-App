import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/app_user.dart';
import '../../services/supabase_service.dart';
import '../../utils/account_validators.dart';
import '../../utils/app_route.dart';
import '../../utils/debouncer.dart';
import 'admin_employee_edit_screen.dart';

/// Creates a staff login (email + username + password). HR details are optional
/// afterwards so this screen stays fast and hard to abandon.
class AdminAddEmployeeScreen extends StatefulWidget {
  const AdminAddEmployeeScreen({super.key});

  @override
  State<AdminAddEmployeeScreen> createState() => _AdminAddEmployeeScreenState();
}

class _AdminAddEmployeeScreenState extends State<AdminAddEmployeeScreen> {
  // Stripe/Linear-style admin form tokens for this screen only.
  static const Color _navy = Color(0xFF14213D);
  static const Color _pageBg = Color(0xFFF5F6F8);
  static const Color _border = Color(0xFFD8DBE2);
  static const Color _muted = Color(0xFF9AA1AD);
  static const Color _label = Color(0xFF3A3F4B);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _success = Color(0xFF16A34A);
  static const double _fieldRadius = 8;
  static const double _fieldHeight = 40;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _usernameDebounce = Debouncer(
    duration: const Duration(milliseconds: 400),
  );

  bool _obscure = true;
  bool _obscure2 = true;
  bool _busy = false;
  String? _error;
  String? _usernameHint;
  bool _usernameTaken = false;
  bool _usernameChecking = false;
  int _usernameCheckGen = 0;

  TextStyle get _ui => GoogleFonts.inter();

  @override
  void dispose() {
    _usernameDebounce.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String _) {
    _usernameDebounce(_checkUsername);
  }

  Future<void> _checkUsername() async {
    final gen = ++_usernameCheckGen;
    final norm = SupabaseService.normalizeUsername(_usernameCtrl.text);
    if (AccountValidators.username(norm) != null) {
      if (!mounted || gen != _usernameCheckGen) return;
      setState(() {
        _usernameChecking = false;
        _usernameHint = null;
        _usernameTaken = false;
      });
      return;
    }

    if (mounted && gen == _usernameCheckGen) {
      setState(() => _usernameChecking = true);
    }

    try {
      final ok = await SupabaseService.isUsernameAvailable(
        norm,
      ).timeout(const Duration(seconds: 8));
      if (!mounted || gen != _usernameCheckGen) return;
      setState(() {
        _usernameChecking = false;
        _usernameTaken = !ok;
        _usernameHint = ok
            ? 'Username is available'
            : 'Username is already taken';
      });
    } catch (_) {
      if (!mounted || gen != _usernameCheckGen) return;
      setState(() {
        _usernameChecking = false;
        _usernameHint = null;
        _usernameTaken = false;
      });
    }
  }

  String _plainError(Object e) {
    var s = e.toString();
    if (s.startsWith('Exception: ')) s = s.substring(11);
    return s.trim().isEmpty ? 'Could not create employee. Try again.' : s;
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_usernameTaken) {
      setState(() => _error = 'Username is already taken');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final created = await SupabaseService.createEmployeeAsAdmin(
        name: _nameCtrl.text,
        email: _emailCtrl.text,
        username: _usernameCtrl.text,
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await _afterCreated(created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _plainError(e);
      });
    }
  }

  Future<void> _afterCreated(AppUser created) async {
    final name = created.name.isNotEmpty ? created.name : created.username;
    final addDetails = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Employee added', style: _ui.copyWith(fontWeight: FontWeight.w600)),
          content: Text(
            '$name can sign in with their email or username.\n\n'
            'Add job, leave, and payroll details now, or do it later from the list.',
            style: _ui.copyWith(fontSize: 14, height: 1.4, color: _label),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Not now', style: _ui.copyWith(color: _muted)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Add profile details', style: _ui.copyWith(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
    if (!mounted) return;

    if (addDetails == true) {
      await pushAppPage<bool>(
        context,
        AdminEmployeeEditScreen(employee: created),
      );
      if (!mounted) return;
    }

    Navigator.pop(context, true);
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    final iconColor = WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.focused)) return _navy;
      return _muted;
    });

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: _ui.copyWith(fontSize: 13.5, color: _muted, fontWeight: FontWeight.w400),
      prefixIcon: Icon(icon, size: 18),
      prefixIconColor: iconColor,
      suffixIcon: suffix,
      suffixIconColor: _muted,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      constraints: const BoxConstraints(minHeight: _fieldHeight),
      border: border(_border, 1),
      enabledBorder: border(_border, 1),
      disabledBorder: border(_border.withValues(alpha: 0.7), 1),
      focusedBorder: border(_navy, 1.5),
      errorBorder: border(_danger, 1),
      focusedErrorBorder: border(_danger, 1.5),
      errorStyle: _ui.copyWith(fontSize: 11.5, color: _danger),
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

  Widget _labeledField({
    required String label,
    required Widget field,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fieldLabel(label),
        field,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
          splashFactory: InkRipple.splashFactory,
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
              'Add employee',
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
          body: AutofillGroup(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  _introCard(),
                  const SizedBox(height: 20),
                  Text(
                    'ACCOUNT',
                    style: _ui.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.06 * 11,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _labeledField(
                          label: 'Full name',
                          field: TextFormField(
                            controller: _nameCtrl,
                            enabled: !_busy,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.name],
                            style: _ui.copyWith(
                              fontSize: 14,
                              color: _label,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _fieldDecoration(
                              hint: 'Full name',
                              icon: Icons.badge_outlined,
                            ),
                            validator: AccountValidators.fullName,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _labeledField(
                          label: 'Email',
                          field: TextFormField(
                            controller: _emailCtrl,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            autofillHints: const [AutofillHints.email],
                            style: _ui.copyWith(
                              fontSize: 14,
                              color: _label,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _fieldDecoration(
                              hint: 'name@company.com',
                              icon: Icons.email_outlined,
                            ),
                            validator: AccountValidators.email,
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(RegExp(r'\s')),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _labeledField(
                          label: 'Username',
                          field: TextFormField(
                            controller: _usernameCtrl,
                            enabled: !_busy,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: const [AutofillHints.username],
                            style: _ui.copyWith(
                              fontSize: 14,
                              color: _label,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _fieldDecoration(
                              hint: 'e.g. siti.aisyah',
                              icon: Icons.alternate_email,
                              suffix: _usernameChecking
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _muted,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            validator: AccountValidators.username,
                            onChanged: _onUsernameChanged,
                          ),
                        ),
                        if (_usernameHint != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _usernameHint!,
                            style: _ui.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _usernameTaken ? _danger : _success,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        _labeledField(
                          label: 'Password',
                          field: TextFormField(
                            controller: _passwordCtrl,
                            enabled: !_busy,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            style: _ui.copyWith(
                              fontSize: 14,
                              color: _label,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _fieldDecoration(
                              hint: 'Password',
                              icon: Icons.lock_outline,
                              suffix: IconButton(
                                tooltip:
                                    _obscure ? 'Show password' : 'Hide password',
                                onPressed: _busy
                                    ? null
                                    : () =>
                                        setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color: _muted,
                                ),
                              ),
                            ),
                            validator: AccountValidators.password,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _labeledField(
                          label: 'Confirm password',
                          field: TextFormField(
                            controller: _confirmCtrl,
                            enabled: !_busy,
                            obscureText: _obscure2,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            onFieldSubmitted: (_) => _submit(),
                            style: _ui.copyWith(
                              fontSize: 14,
                              color: _label,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _fieldDecoration(
                              hint: 'Confirm password',
                              icon: Icons.lock_outline,
                              suffix: IconButton(
                                tooltip: _obscure2
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: _busy
                                    ? null
                                    : () => setState(
                                          () => _obscure2 = !_obscure2,
                                        ),
                                icon: Icon(
                                  _obscure2
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color: _muted,
                                ),
                              ),
                            ),
                            validator: (v) =>
                                AccountValidators.confirmPassword(
                              v,
                              _passwordCtrl.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _danger.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _danger.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 18,
                            color: _danger,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: _ui.copyWith(
                                fontSize: 13,
                                height: 1.35,
                                color: _danger,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _navy.withValues(alpha: 0.45),
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Create account',
                              style: _ui.copyWith(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'They can sign in immediately. Passwords cannot be viewed later.',
                    textAlign: TextAlign.center,
                    style: _ui.copyWith(
                      fontSize: 11.5,
                      height: 1.35,
                      color: _muted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _pageBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: _muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Create a login with email, username, and password. '
              'You can fill job and payroll details after this.',
              style: _ui.copyWith(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w400,
                color: _muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

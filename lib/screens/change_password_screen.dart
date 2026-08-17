import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../providers/auth_provider.dart';
import '../utils/account_validators.dart';
import '../utils/app_route.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  bool _obscureCurrent = true;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
      _success = false;
    });
    final result = await context.read<AuthProvider>().changePassword(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _success = result == null;
      _message = result ?? 'Password updated.';
    });
    if (_success) {
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      popApp(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(title: const Text('Change password')),
        body: AutofillGroup(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Update your password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter your current password, then a new one. '
                      'Username and email stay the same.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _currentCtrl,
                      enabled: !_busy,
                      obscureText: _obscureCurrent,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Current password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscureCurrent
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => _obscureCurrent = !_obscureCurrent,
                                ),
                          icon: Icon(
                            _obscureCurrent
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Enter your current password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _newCtrl,
                      enabled: !_busy,
                      obscureText: _obscure1,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'New password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscure1
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: _busy
                              ? null
                              : () => setState(() => _obscure1 = !_obscure1),
                          icon: Icon(
                            _obscure1
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: AccountValidators.password,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmCtrl,
                      enabled: !_busy,
                      obscureText: _obscure2,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscure2
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: _busy
                              ? null
                              : () => setState(() => _obscure2 = !_obscure2),
                          icon: Icon(
                            _obscure2
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          AccountValidators.confirmPassword(v, _newCtrl.text),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              (_success ? AppColors.success : AppColors.danger)
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _message!,
                          style: TextStyle(
                            color: _success
                                ? AppColors.success
                                : AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Update password'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

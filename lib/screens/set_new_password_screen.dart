import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../providers/auth_provider.dart';

/// Shown after the user opens a password-reset email link.
///
/// Flow: new password + confirm → save → sign out → login.
class SetNewPasswordScreen extends StatefulWidget {
  const SetNewPasswordScreen({super.key});

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _error;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final err = await auth.completePasswordRecovery(_newCtrl.text);

    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    // AuthGate swaps to LoginScreen — keep busy until disposed.
  }

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() => _busy = true);
    await context.read<AuthProvider>().cancelPasswordRecovery();
    // AuthGate shows LoginScreen.
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppChrome.onAuth,
        child: Scaffold(
          backgroundColor: AppColors.authBlue,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: AppGradients.authBackground,
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
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
                            const Icon(
                              Icons.lock_reset_rounded,
                              size: 42,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Set new password',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Choose a new password, confirm it, then sign in.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _newCtrl,
                              obscureText: _obscure1,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: InputDecoration(
                                labelText: 'New password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(
                                            () => _obscure1 = !_obscure1,
                                          ),
                                  icon: Icon(
                                    _obscure1
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.length < 6) {
                                  return 'Minimum 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _confirmCtrl,
                              obscureText: _obscure2,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: InputDecoration(
                                labelText: 'Confirm password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(
                                            () => _obscure2 = !_obscure2,
                                          ),
                                  icon: Icon(
                                    _obscure2
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value != _newCtrl.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.danger
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppColors.danger,
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
                                  : const Text('Confirm new password'),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: _busy ? null : _cancel,
                              child: const Text('Back to login'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

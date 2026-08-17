import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../providers/auth_provider.dart';
import '../utils/app_route.dart';

const Color _kNavy = Color(0xFF14213D);
const Color _kFieldBorder = Color(0xFFD8DBE2);
const Color _kLabel = Color(0xFF3A3F4B);
const Color _kMuted = Color(0xFF9AA1AD);
const Color _kLink = Color(0xFF185FA5);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscure2 = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  static String? _validateUsername(String? v) {
    final t = (v ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.length < 3) return 'At least 3 characters';
    if (t.length > 64) return 'Max 64 characters';
    // Letters (any language), numbers, spaces, and common name punctuation.
    if (!RegExp(r"^[\p{L}\p{N} .'_\-]+$", unicode: true).hasMatch(t)) {
      return 'Use letters, numbers, spaces, or . \' - _';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final msg = await auth.signUp(
      email: _emailCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (msg != null) {
      final isInfo =
          msg.contains('Confirm your email') || msg.contains('Account created');
      if (isInfo) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.success),
        );
        Navigator.of(context).pop();
        return;
      }
      setState(() => _error = msg);
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  static InputDecorationTheme _inputTheme() {
    const r = 8.0;
    return InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      prefixIconColor: _kMuted,
      hintStyle: const TextStyle(
        color: _kMuted,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide: const BorderSide(color: _kFieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide: const BorderSide(color: _kFieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide: const BorderSide(color: _kNavy, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppChrome.onAuth,
      child: Scaffold(
        backgroundColor: _kNavy,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _busy ? null : () => popApp(context),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Create account',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.96),
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Register with email, username & password',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.48),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                inputDecorationTheme: _inputTheme(),
                              ),
                              child: Form(
                                key: _formKey,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    22,
                                    24,
                                    22,
                                    22,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const _Label('Email'),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _emailCtrl,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: _kNavy,
                                        ),
                                        decoration: const InputDecoration(
                                          hintText: 'you@gmail.com',
                                          prefixIcon: Icon(
                                            Icons.email_outlined,
                                            size: 18,
                                          ),
                                        ),
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Required';
                                          }
                                          if (!v.contains('@')) {
                                            return 'Enter a valid email';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      const _Label('Username'),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _usernameCtrl,
                                        textInputAction: TextInputAction.next,
                                        autocorrect: false,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: _kNavy,
                                        ),
                                        decoration: const InputDecoration(
                                          hintText: 'e.g. your.name',
                                          prefixIcon: Icon(
                                            Icons.person_outline_rounded,
                                            size: 18,
                                          ),
                                        ),
                                        validator: _validateUsername,
                                      ),
                                      const SizedBox(height: 14),
                                      const _Label('Password'),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _passwordCtrl,
                                        obscureText: _obscure,
                                        textInputAction: TextInputAction.next,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: _kNavy,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: '••••••••',
                                          prefixIcon: const Icon(
                                            Icons.lock_outline_rounded,
                                            size: 18,
                                          ),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscure
                                                  ? Icons
                                                      .visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                              size: 18,
                                              color: _kMuted,
                                            ),
                                            onPressed: () => setState(
                                              () => _obscure = !_obscure,
                                            ),
                                          ),
                                        ),
                                        validator: (v) =>
                                            (v == null || v.length < 6)
                                                ? 'Min 6 characters'
                                                : null,
                                      ),
                                      const SizedBox(height: 14),
                                      const _Label('Confirm password'),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _confirmCtrl,
                                        obscureText: _obscure2,
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => _submit(),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: _kNavy,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: '••••••••',
                                          prefixIcon: const Icon(
                                            Icons.lock_outline_rounded,
                                            size: 18,
                                          ),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscure2
                                                  ? Icons
                                                      .visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                              size: 18,
                                              color: _kMuted,
                                            ),
                                            onPressed: () => setState(
                                              () => _obscure2 = !_obscure2,
                                            ),
                                          ),
                                        ),
                                        validator: (v) {
                                          if (v != _passwordCtrl.text) {
                                            return 'Passwords do not match';
                                          }
                                          return null;
                                        },
                                      ),
                                      if (_error != null) ...[
                                        const SizedBox(height: 14),
                                        _ErrorBanner(_error!),
                                      ],
                                      const SizedBox(height: 18),
                                      SizedBox(
                                        height: 48,
                                        child: FilledButton(
                                          onPressed: _busy ? null : _submit,
                                          style: FilledButton.styleFrom(
                                            backgroundColor: _kNavy,
                                            disabledBackgroundColor:
                                                _kFieldBorder,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: _busy
                                              ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      'Create account',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Icon(
                                                      Icons
                                                          .arrow_forward_rounded,
                                                      size: 18,
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Text.rich(
                                        TextSpan(
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: _kMuted,
                                          ),
                                          children: [
                                            const TextSpan(
                                              text: 'Already have an account? ',
                                            ),
                                            WidgetSpan(
                                              alignment: PlaceholderAlignment
                                                  .baseline,
                                              baseline: TextBaseline.alphabetic,
                                              child: GestureDetector(
                                                onTap: _busy
                                                    ? null
                                                    : () => popApp(context),
                                                child: Text(
                                                  'Sign in',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: _busy
                                                        ? _kMuted
                                                        : _kLink,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'myRekod · Enterprise HR · Secure access',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.38),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _kLabel,
        height: 1.0,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 15,
            color: AppColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

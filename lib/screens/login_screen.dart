import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../providers/auth_provider.dart';
import '../utils/app_route.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

const _kWordmarkTeal = Color(0xFF2DD4BF);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final err = await auth.signIn(
      _usernameCtrl.text.trim(),
      _passwordCtrl.text,
    );

    if (!mounted) return;
    // On success AuthGate replaces this screen — keep busy until disposed.
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppChrome.onBrand.copyWith(
        systemNavigationBarColor: const Color(0xFF0F2255),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1A3A8F),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: AppGradients.authBackground,
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _BrandMark(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          children: [
                            _FormCard(
                              formKey: _formKey,
                              usernameCtrl: _usernameCtrl,
                              passwordCtrl: _passwordCtrl,
                              obscure: _obscure,
                              busy: _busy,
                              error: _error,
                              onToggleObscure: () =>
                                  setState(() => _obscure = !_obscure),
                              onSubmit: _submit,
                              onForgotPassword: () =>
                                  pushAppPage(
                                    context,
                                    const ForgotPasswordScreen(),
                                  ),
                              onCreateAccount: () =>
                                  pushAppPage(
                                    context,
                                    const RegisterScreen(),
                                  ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'myRekod · Enterprise HR · Secure access',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.45),
                                letterSpacing: 0.3,
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Brand mark — sits above the card, minimal
// ─────────────────────────────────────────────────────────────────────────────

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 44, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon tile
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: AppColors.teal,
              boxShadow: [
                BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.40),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                  spreadRadius: -2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.fingerprint_rounded,
                size: 26,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Wordmark
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                height: 1.0,
              ),
              children: [
                TextSpan(
                  text: 'my',
                  style: TextStyle(color: Colors.white),
                ),
                TextSpan(
                  text: 'Rekod',
                  style: TextStyle(color: _kWordmarkTeal),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Workforce Management',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.48),
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form card — the floating white sheet
// ─────────────────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.formKey,
    required this.usernameCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.busy,
    required this.error,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onForgotPassword,
    required this.onCreateAccount,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController usernameCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final bool busy;
  final String? error;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;
  final VoidCallback onCreateAccount;

  static InputDecorationTheme _inputTheme() {
    const r = 10.0;
    return InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      prefixIconColor: AppColors.textSecondary,
      hintStyle: const TextStyle(
        color: AppColors.textHint,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide:
            const BorderSide(color: AppColors.teal, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide:
            const BorderSide(color: AppColors.danger, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          // Deep diffuse lift
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.36),
            blurRadius: 60,
            offset: const Offset(0, 24),
            spreadRadius: -12,
          ),
          // Soft ambient ring
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.07),
            blurRadius: 32,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context)
            .copyWith(inputDecorationTheme: _inputTheme()),
        child: Form(
          key: formKey,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ───────────────────────────────────────────
                const Text(
                  'Sign in to your account',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enter your credentials below to continue.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Username ─────────────────────────────────────────
                const _Label('Username or email'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: usernameCtrl,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'AHMAD FAIZ or you@company.com',
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final t = v.trim();
                    if (!t.contains('@') && t.length < 3) {
                      return 'At least 3 characters';
                    }
                    if (t.contains('@') && !t.contains('.')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Password (label + forgot inline) ─────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(child: _Label('Password')),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: busy ? null : onForgotPassword,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              'Forgot password?',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: busy
                                    ? AppColors.textHint
                                    : AppColors.teal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: passwordCtrl,
                  obscureText: obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: AppColors.textHint,
                      ),
                      onPressed: onToggleObscure,
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 6)
                          ? 'Min 6 characters'
                          : null,
                ),

                // ── Error banner ────────────────────────────────────
                if (error != null) ...[
                  const SizedBox(height: 14),
                  _ErrorBanner(error!),
                ],
                const SizedBox(height: 22),

                // ── Sign in button ───────────────────────────────────
                _SignInButton(
                  busy: busy,
                  onPressed: busy ? null : onSubmit,
                ),
                const SizedBox(height: 10),

                // ── Create account ───────────────────────────────────
                TextButton(
                  onPressed: busy ? null : onCreateAccount,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    minimumSize: const Size.fromHeight(44),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: const Text('Create an account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Atoms
// ─────────────────────────────────────────────────────────────────────────────

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
        color: AppColors.textPrimary,
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

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(10);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled ? AppGradients.teal : null,
        color: enabled ? null : AppColors.border,
        borderRadius: radius,
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          splashColor: Colors.white.withValues(alpha: 0.08),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          child: Ink(
            height: 50,
            decoration: BoxDecoration(borderRadius: radius),
            child: Center(
              child: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Sign in',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 13,
                            color: Colors.white,
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
}

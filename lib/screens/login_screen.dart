import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../providers/auth_provider.dart';
import '../utils/app_route.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

const Color _kNavy = Color(0xFF14213D);
const Color _kWordmarkAccent = Color(0xFF8FB4E8);
const Color _kFieldBorder = Color(0xFFD8DBE2);
const Color _kLabel = Color(0xFF3A3F4B);
const Color _kMuted = Color(0xFF9AA1AD);
const Color _kLink = Color(0xFF185FA5);

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
  String? _info;
  bool _infoIsError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final isError = auth.loginBannerIsError;
      final banner = auth.takeLoginBanner();
      if (banner == null) return;
      setState(() {
        if (isError) {
          _error = banner;
          _info = null;
        } else {
          _info = banner;
          _infoIsError = false;
        }
      });
    });
  }

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
      value: AppChrome.onAuth,
      child: Scaffold(
        backgroundColor: _kNavy,
        body: SafeArea(
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
                            info: _info,
                            infoIsError: _infoIsError,
                            onToggleObscure: () =>
                                setState(() => _obscure = !_obscure),
                            onSubmit: _submit,
                            onForgotPassword: () => pushAppPage(
                              context,
                              const ForgotPasswordScreen(),
                            ),
                            onCreateAccount: () => pushAppPage(
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

// ─────────────────────────────────────────────────────────────────────────────
// Brand mark — sits above the card
// ─────────────────────────────────────────────────────────────────────────────

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 44, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.fingerprint_rounded,
                size: 28,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
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
                  style: TextStyle(color: _kWordmarkAccent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Workforce management',
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
// Form card
// ─────────────────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.formKey,
    required this.usernameCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.busy,
    required this.error,
    this.info,
    this.infoIsError = false,
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
  final String? info;
  final bool infoIsError;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;
  final VoidCallback onCreateAccount;

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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(inputDecorationTheme: _inputTheme()),
        child: Form(
          key: formKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sign in to your account',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _kNavy,
                    letterSpacing: -0.3,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enter your credentials below to continue.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: _kMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),

                const _Label('Username or email'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: usernameCtrl,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _kNavy,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'you@gmail.com or username',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
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
                const SizedBox(height: 14),

                const _Label('Password'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: passwordCtrl,
                  obscureText: obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => onSubmit(),
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
                        obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: _kMuted,
                      ),
                      onPressed: onToggleObscure,
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: busy ? null : onForgotPassword,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: busy ? _kMuted : _kLink,
                        ),
                      ),
                    ),
                  ),
                ),

                if (info != null) ...[
                  const SizedBox(height: 12),
                  _InfoBanner(info!, isError: infoIsError),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(error!),
                ],
                const SizedBox(height: 16),

                _SignInButton(
                  busy: busy,
                  onPressed: busy ? null : onSubmit,
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
                      const TextSpan(text: "Don't have an account? "),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: busy ? null : onCreateAccount,
                          child: Text(
                            'Create one',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: busy ? _kMuted : _kLink,
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

class _InfoBanner extends StatelessWidget {
  const _InfoBanner(this.message, {this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.danger : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
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
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _kNavy,
          disabledBackgroundColor: _kFieldBorder,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sign in',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    );
  }
}

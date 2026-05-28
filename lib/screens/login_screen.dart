import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../providers/auth_provider.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const double _cardRadius = 28;

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
    setState(() => _busy = false);

    if (err != null) {
      setState(() => _error = err);
    }
  }

  InputDecorationTheme _loginInputTheme(BuildContext context) {
    const radius = 14.0;
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      prefixIconColor: AppColors.textSecondary,
      hintStyle: TextStyle(
        color: AppColors.textHint,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: AppColors.border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: AppColors.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: AppColors.danger, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
    );
  }

  Widget _backgroundOrbs() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: -72,
          top: -28,
          child: IgnorePointer(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
        ),
        Positioned(
          left: -56,
          top: 120,
          child: IgnorePointer(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
        ),
        Positioned(
          left: 40,
          bottom: 100,
          child: IgnorePointer(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _trustStrip() {
    Widget item(IconData icon, String label) {
      return Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: AppColors.onBrandMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onBrandMuted,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandChipBorder),
        color: AppColors.brandChipFill,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          item(Icons.verified_user_outlined, 'Secure session'),
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: Colors.white.withValues(alpha: 0.22),
          ),
          item(Icons.schedule_rounded, 'Live attendance'),
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: Colors.white.withValues(alpha: 0.22),
          ),
          item(Icons.groups_outlined, 'Team-ready'),
        ],
      ),
    );
  }

  Widget _signInCta(VoidCallback? onPressed, bool busy) {
    final radius = BorderRadius.circular(14);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.brandPanel,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Ink(
            height: 54,
            decoration: BoxDecoration(borderRadius: radius),
            child: Center(
              child: busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Sign in',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final topInset = MediaQuery.paddingOf(context).top;
    final logoW = (screenW - 44).clamp(240.0, 380.0);
    const logoH = 118.0;
    const maxContentW = 440.0;

    final linkButtonStyle = TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      textStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppChrome.onBrand.copyWith(
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration:
                  const BoxDecoration(gradient: AppGradients.brandHeader),
            ),
            _backgroundOrbs(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    22,
                    topInset > 28 ? 8 : 14,
                    22,
                    28,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: maxContentW),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 36,
                                offset: const Offset(0, 14),
                              ),
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.25),
                                blurRadius: 48,
                                spreadRadius: -8,
                              ),
                            ],
                          ),
                          child: SizedBox(
                            width: logoW,
                            height: logoH,
                            child: Image.asset(
                              'lib/assets/logo-CEO.png',
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.fingerprint_rounded,
                                size: logoH * 0.55,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Attendance',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.35,
                            height: 1.02,
                            color: AppColors.onBrand,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Workforce attendance, leave & claims — in one place.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                            color: AppColors.onBrandSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _trustStrip(),
                        const SizedBox(height: 14),
                        Center(
                          child: Container(
                            height: 3,
                            width: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.2),
                                  Colors.white.withValues(alpha: 0.85),
                                  Colors.white.withValues(alpha: 0.2),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sign in with your work username or company email',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            color: AppColors.onBrandMuted,
                          ),
                        ),
                        const SizedBox(height: 28),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(_cardRadius + 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.textPrimary
                                    .withValues(alpha: 0.12),
                                blurRadius: 40,
                                offset: const Offset(0, 18),
                                spreadRadius: -8,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            surfaceTintColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(_cardRadius),
                              side: BorderSide(
                                color: AppColors.textPrimary
                                    .withValues(alpha: 0.06),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    gradient: AppGradients.brandPanel,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    22,
                                    24,
                                    24,
                                  ),
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      inputDecorationTheme:
                                          _loginInputTheme(context),
                                    ),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: AppColors
                                                      .primaryLight
                                                      .withValues(alpha: 0.75),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Icon(
                                                  Icons.lock_open_rounded,
                                                  size: 20,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Welcome back',
                                                      style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        letterSpacing: -0.4,
                                                        color: AppColors
                                                            .textPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Enter your credentials to access the app.',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        height: 1.35,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 22),
                                          Text(
                                            'ACCOUNT',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.15,
                                              color: AppColors.textHint,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Username or email',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            controller: _usernameCtrl,
                                            keyboardType: TextInputType.text,
                                            textInputAction:
                                                TextInputAction.next,
                                            autocorrect: false,
                                            decoration: const InputDecoration(
                                              hintText:
                                                  'username or you@company.com',
                                              prefixIcon: Icon(
                                                Icons.person_outline,
                                                size: 20,
                                              ),
                                            ),
                                            validator: (v) {
                                              if (v == null ||
                                                  v.trim().isEmpty) {
                                                return 'Required';
                                              }
                                              final t = v.trim();
                                              if (!t.contains('@') &&
                                                  t.length < 3) {
                                                return 'At least 3 characters';
                                              }
                                              if (t.contains('@') &&
                                                  !t.contains('.')) {
                                                return 'Enter a valid email';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 18),
                                          Text(
                                            'Password',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            controller: _passwordCtrl,
                                            obscureText: _obscure,
                                            textInputAction:
                                                TextInputAction.done,
                                            onFieldSubmitted: (_) =>
                                                _submit(),
                                            decoration: InputDecoration(
                                              hintText: '••••••••',
                                              prefixIcon: const Icon(
                                                Icons.lock_outline,
                                                size: 20,
                                              ),
                                              suffixIcon: IconButton(
                                                icon: Icon(
                                                  _obscure
                                                      ? Icons
                                                          .visibility_off_outlined
                                                      : Icons
                                                          .visibility_outlined,
                                                  size: 20,
                                                  color: AppColors
                                                      .textSecondary,
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
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton(
                                              style: linkButtonStyle,
                                              onPressed: _busy
                                                  ? null
                                                  : () {
                                                      Navigator.of(context)
                                                          .push(
                                                        MaterialPageRoute<void>(
                                                          builder: (_) =>
                                                              const ForgotPasswordScreen(),
                                                        ),
                                                      );
                                                    },
                                              child: const Text(
                                                'Forgot password?',
                                              ),
                                            ),
                                          ),
                                          if (_error != null) ...[
                                            const SizedBox(height: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.danger
                                                    .withValues(alpha: 0.08),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: AppColors.danger
                                                      .withValues(alpha: 0.2),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.error_outline,
                                                    size: 18,
                                                    color: AppColors.danger,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      _error!,
                                                      style: TextStyle(
                                                        color:
                                                            AppColors.danger,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        height: 1.3,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 22),
                                          _signInCta(
                                            _busy ? null : _submit,
                                            _busy,
                                          ),
                                          const SizedBox(height: 6),
                                          TextButton(
                                            style: linkButtonStyle.copyWith(
                                              textStyle:
                                                  WidgetStateProperty.all(
                                                TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            onPressed: _busy
                                                ? null
                                                : () {
                                                    Navigator.of(context)
                                                        .push(
                                                      MaterialPageRoute<void>(
                                                        builder: (_) =>
                                                            const RegisterScreen(),
                                                      ),
                                                    );
                                                  },
                                            child: const Text(
                                              'Create an account',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Protected access • Contact your administrator if you need help',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onBrandFaint,
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
    );
  }
}

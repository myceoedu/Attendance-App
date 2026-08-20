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

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
      _success = false;
    });

    final result = await context
        .read<AuthProvider>()
        .sendPasswordResetEmail(_emailCtrl.text.trim());

    if (!mounted) return;
    setState(() {
      _busy = false;
      _success = result == null;
      _message = result ??
          'Reset email sent. Open the link to set a new password, then sign in.';
    });
  }

  static InputDecorationTheme _inputTheme() {
    const r = 8.0;
    return InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      prefixIconColor: _kMuted,
      hintStyle: TextStyle(
        color: _kMuted,
        fontSize: AppLayout.fieldFontSize,
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
                            'Forgot password',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.96),
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'We will email you a reset link',
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
                                      const Text(
                                        'Reset your password',
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
                                        'Enter your account email. We send a link that opens a screen to choose a new password (then you sign in).',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                          color: _kMuted,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 22),
                                      const _Label('Email'),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _emailCtrl,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => _submit(),
                                        style: TextStyle(
                                          fontSize: AppLayout.fieldFontSize,
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
                                        validator: (value) {
                                          final v = value?.trim() ?? '';
                                          if (v.isEmpty) {
                                            return 'Enter your email';
                                          }
                                          if (!v.contains('@') ||
                                              !v.contains('.')) {
                                            return 'Enter a valid email';
                                          }
                                          return null;
                                        },
                                      ),
                                      if (_message != null) ...[
                                        const SizedBox(height: 14),
                                        _StatusBanner(
                                          _message!,
                                          success: _success,
                                        ),
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
                                                      'Send reset email',
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
                                              text: 'Remembered it? ',
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
                                                  'Back to sign in',
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

class _StatusBanner extends StatelessWidget {
  const _StatusBanner(this.message, {required this.success});

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success ? AppColors.success : AppColors.danger;
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
            success
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
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

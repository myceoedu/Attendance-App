import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../providers/auth_provider.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

// ── Dot-grid background painter ──────────────────────────────────────────────
class _DotGridPainter extends CustomPainter {
  final Color color;
  const _DotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 26.0;
    const radius = 1.3;
    final paint = Paint()..color = color;
    for (double x = 0; x < size.width; x += gap) {
      for (double y = 0; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}

// ── Diagonal wave/arc decoration ─────────────────────────────────────────────
class _WavePainter extends CustomPainter {
  final Color color;
  const _WavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, size.height * 0.68)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.55,
        size.width,
        size.height * 0.72,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.color != color;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const double _cardRadius = 28;

  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _pulse.dispose();
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
        borderSide: const BorderSide(color: AppColors.teal, width: 2),
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

  // ── Background layers ─────────────────────────────────────────────────────

  Widget _buildBackground(Size size) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base gradient: deep navy → indigo → blue
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF071428), // near-black navy
                Color(0xFF0F2255), // deep navy
                Color(0xFF1A3A8F), // brand indigo
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),
        // Dot grid overlay
        Opacity(
          opacity: 0.28,
          child: CustomPaint(
            size: size,
            painter: _DotGridPainter(
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ),
        // Wave/arc at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: size.height * 0.28,
          child: CustomPaint(
            painter: _WavePainter(
              color: Colors.white.withValues(alpha: 0.03),
            ),
          ),
        ),
        // Teal glow orb — bottom left
        Positioned(
          left: -90,
          bottom: size.height * 0.12,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                width: 320 + _pulseAnim.value * 28,
                height: 320 + _pulseAnim.value * 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF0D9488).withValues(alpha: 0.28),
                      const Color(0xFF0D9488).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Indigo glow orb — top right
        Positioned(
          right: -80,
          top: -40,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                width: 280 + (1 - _pulseAnim.value) * 24,
                height: 280 + (1 - _pulseAnim.value) * 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF4F46E5).withValues(alpha: 0.22),
                      const Color(0xFF4F46E5).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Bright accent circle — mid-left
        Positioned(
          left: -30,
          top: size.height * 0.3,
          child: IgnorePointer(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Brand hero section ────────────────────────────────────────────────────

  Widget _buildHero() {
    return Column(
      children: [
        // Icon badge
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.fingerprint_rounded,
              size: 38,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Brand name: "my" white + "Rekod" teal
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.8,
              height: 1.0,
            ),
            children: [
              TextSpan(
                text: 'my',
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: 'Rekod',
                style: TextStyle(color: Color(0xFF2DD4BF)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Badge pill: HR Platform
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFF0D9488).withValues(alpha: 0.55),
            ),
            color: const Color(0xFF0D9488).withValues(alpha: 0.14),
          ),
          child: const Text(
            'Smart HR · Attendance · Leave · Claims',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5EEAD4),
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _trustStrip(),
      ],
    );
  }

  // ── Trust strip ──────────────────────────────────────────────────────────

  Widget _trustStrip() {
    Widget item(IconData icon, String label) {
      return Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: AppColors.onBrandMuted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Row(
        children: [
          item(Icons.verified_user_outlined, 'Secure'),
          _divider(),
          item(Icons.schedule_rounded, 'Live data'),
          _divider(),
          item(Icons.groups_outlined, 'Team-ready'),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 16,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: Colors.white.withValues(alpha: 0.18),
  );

  // ── Sign-in CTA button ────────────────────────────────────────────────────

  Widget _signInCta(VoidCallback? onPressed, bool busy) {
    final radius = BorderRadius.circular(14);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
        ),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.45),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Sign in',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
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

  // ── Root build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    const maxContentW = 440.0;

    final linkButtonStyle = TextButton.styleFrom(
      foregroundColor: AppColors.teal,
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppChrome.onBrand.copyWith(
        systemNavigationBarColor: const Color(0xFF0A1628),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF071428),
        body: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackground(size),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    22,
                    topInset > 28 ? 8 : 20,
                    22,
                    28,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: maxContentW),
                    child: Column(
                      children: [
                        _buildHero(),
                        const SizedBox(height: 10),
                        // Divider accent line
                        Center(
                          child: Container(
                            height: 2,
                            width: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.08),
                                  const Color(0xFF2DD4BF).withValues(
                                    alpha: 0.7,
                                  ),
                                  Colors.white.withValues(alpha: 0.08),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Sign in with your work username or email',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            color: AppColors.onBrandMuted,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Form card
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              _cardRadius + 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.32),
                                blurRadius: 48,
                                offset: const Offset(0, 20),
                                spreadRadius: -6,
                              ),
                              BoxShadow(
                                color: const Color(0xFF0D9488).withValues(
                                  alpha: 0.12,
                                ),
                                blurRadius: 36,
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            surfaceTintColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(_cardRadius),
                              side: BorderSide(
                                color: Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Teal accent bar
                                Container(
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF0F766E),
                                        Color(0xFF0D9488),
                                        Color(0xFF2DD4BF),
                                        Color(0xFF1A56DB),
                                      ],
                                    ),
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
                                      inputDecorationTheme: _loginInputTheme(
                                        context,
                                      ),
                                    ),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          // Card header row
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.tealLight,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Icon(
                                                  Icons.lock_open_rounded,
                                                  size: 20,
                                                  color: AppColors.teal,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
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
                                                      'Enter your credentials to continue.',
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
                                          const Text(
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
                                          const Text(
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
                                            onFieldSubmitted: (_) => _submit(),
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
                                                  color:
                                                      AppColors.textSecondary,
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
                                                      Navigator.of(
                                                        context,
                                                      ).push(
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
                                                      style: const TextStyle(
                                                        color: AppColors.danger,
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
                                                    const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                            ),
                                            onPressed: _busy
                                                ? null
                                                : () {
                                                    Navigator.of(context).push(
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
                          'myRekod · Protected access · Contact your admin for help',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
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

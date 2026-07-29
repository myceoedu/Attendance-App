import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppColors {
  static const primary = Color(0xFF1A56DB);
  static const primaryDark = Color(0xFF1E3A8A);
  static const primaryLight = Color(0xFFDBEAFE);
  static const secondary = Color(0xFF0E9F6E);
  static const accent = Color(0xFFF59E0B);
  static const danger = Color(0xFFE02424);
  /// Approved leave / absent-day emphasis (calendar, summaries, chips).
  static const leave = Color(0xFFDC2626);
  static const leaveLight = Color(0xFFFEE2E2);

  // Extended accent palette for a more vibrant UI.
  static const violet = Color(0xFF7C3AED);
  static const violetLight = Color(0xFFEDE9FE);
  static const teal = Color(0xFF0D9488);
  static const tealLight = Color(0xFFCCFBF1);
  static const pink = Color(0xFFDB2777);
  static const pinkLight = Color(0xFFFCE7F3);
  static const orange = Color(0xFFEA580C);
  static const orangeLight = Color(0xFFFFEDD5);
  static const sky = Color(0xFF0284C7);
  static const skyLight = Color(0xFFE0F2FE);
  static const indigo = Color(0xFF4F46E5);
  static const indigoLight = Color(0xFFE0E7FF);

  static const surface = Color(0xFFF8FAFC); // neutral cool gray (less blue cast)
  static const surfaceAlt = Color(0xFFE0E7FF); // subtle tint for header bands
  static const cardBg = Colors.white;
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textHint = Color(0xFF94A3B8);
  static const divider = Color(0xFFE2E8F0);
  static const border = Color(0xFFCBD5E1);

  /// Employee home quick-access grid: icon well and card chrome.
  static const quickAccessIconWell = Color(0xFFE8ECF0);
  static const quickAccessIconWellRing = Color(0xFFFFFFFF);
  static const quickAccessCardShadow = Color(0x1A0F172A); // ~10% textPrimary
  static const success = Color(0xFF059669);
  static const successLight = Color(0xFFD1FAE5);
  /// Open attendance / clocked-in state.
  static const open = Color(0xFF2563EB);
  static const openLight = Color(0xFFDBEAFE);
  /// Calendar-only highlight for today's date.
  static const today = Color(0xFF1E3A8A);
  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFEF3C7);
  static const dangerLight = Color(0xFFFEE2E2);
  static const pending = Color(0xFFF59E0B);
  static const completed = Color(0xFF059669);
  static const inProgress = Color(0xFF2563EB);
  static const rejected = Color(0xFFDC2626);

  // ── Brand chrome (headers, nav bar, hero cards on blue) ─────────────
  /// Primary text/icons on [primaryDark] and [AppGradients.brandHeader].
  static const Color onBrand = Color(0xFFFFFFFF);

  static Color get onBrandSecondary =>
      Colors.white.withValues(alpha: 0.84);

  static Color get onBrandMuted => Colors.white.withValues(alpha: 0.72);

  static Color get onBrandFaint => Colors.white.withValues(alpha: 0.58);

  static Color get brandHeaderBorder =>
      Colors.white.withValues(alpha: 0.2);

  static Color get brandHeaderShadow =>
      primaryDark.withValues(alpha: 0.32);

  static Color get brandChipFill => Colors.white.withValues(alpha: 0.2);

  static Color get brandChipBorder => Colors.white.withValues(alpha: 0.36);

  static Color get brandAvatarRing => Colors.white.withValues(alpha: 0.45);

  /// Pill / nav indicator on brand surfaces.
  static Color get brandIndicator => Colors.white.withValues(alpha: 0.22);

  static Color get navBarShadow => Colors.black.withValues(alpha: 0.18);

  /// Bottom [NavigationBar] — same family as [AppGradients.brandHeader].
  static const Color navigationBarBackground = primaryDark;

  /// Hairline on top of the nav bar; visible on brand blue.
  static Color get navigationBarTopLine =>
      Colors.white.withValues(alpha: 0.14);

  // ── Admin shell (distinct from employee blue) ────────────────────────
  static const adminNavBackground = Color(0xFF312E81);
  static Color get adminNavIndicator => Colors.white.withValues(alpha: 0.22);
  static Color get adminHeaderShadow =>
      const Color(0xFF312E81).withValues(alpha: 0.38);

  /// Soft fill behind shortcut icons (accent is semantic: leave, pay, etc.).
  static Color quickAccessWellFill(Color accent) => Color.alphaBlend(
        accent.withValues(alpha: 0.14),
        cardBg,
      );

  static Color quickAccessWellBorder(Color accent) =>
      Color.alphaBlend(accent.withValues(alpha: 0.35), divider);

  /// Keeps light accents (e.g. amber) readable at small sizes.
  static Color quickAccessIconOnAccent(Color accent) {
    if (accent.computeLuminance() > 0.62) {
      return Color.lerp(accent, textPrimary, 0.5)!;
    }
    return Color.lerp(accent, primaryDark, 0.1)!;
  }
}

/// Reusable gradients so screens share the same visual language.
abstract class AppGradients {
  static const primary = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF1A56DB), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const violet = LinearGradient(
    colors: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFFA78BFA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Matches [AppColors.leave] for approved-leave hero accents.
  static const leave = LinearGradient(
    colors: [Color(0xFFB91C1C), Color(0xFFDC2626), Color(0xFFF87171)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const teal = LinearGradient(
    colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF2DD4BF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const sunset = LinearGradient(
    colors: [Color(0xFFDB2777), Color(0xFFEA580C), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const sky = LinearGradient(
    colors: [Color(0xFF0369A1), Color(0xFF0284C7), Color(0xFF38BDF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Quick-access shortcut icon wells: soft top-left highlight to deeper grey.
  static const quickAccessWell = LinearGradient(
    colors: [Color(0xFFF8FAFC), Color(0xFFEEF2F6), Color(0xFFE2E8F0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Bottom clock FAB: clean white surface with slight depth.
  static const clockFabSurface = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Headers (home, profile) — matches [AppColors.navigationBarBackground] family.
  static const LinearGradient brandHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.primaryDark,
      Color(0xFF1C47AE), // ~ lerp(primaryDark, primary, 0.45)
      AppColors.primary,
    ],
  );

  /// Compact brand panels (e.g. attendance clock card).
  static const LinearGradient brandPanel = LinearGradient(
    colors: [AppColors.primaryDark, AppColors.primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Login / register screens — deep navy → brand blue.
  static const LinearGradient authBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0B1D4A),
      Color(0xFF0F2255),
      Color(0xFF1A3A8F),
    ],
    stops: [0.0, 0.45, 1.0],
  );

  /// Admin dashboard header — indigo / violet (not employee [brandHeader] blue).
  static const LinearGradient adminBrandHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF312E81),
      Color(0xFF4338CA),
      Color(0xFF6366F1),
    ],
  );
}

/// Status bar: pick based on background behind the status bar.
abstract class AppChrome {
  static const SystemUiOverlayStyle onBrand = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  /// White / light headers & lists — dark status icons.
  static const SystemUiOverlayStyle onLightSurface = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFFF8FAFC),
    systemNavigationBarIconBrightness: Brightness.dark,
  );
}

/// Employee home typography — **Inter only**, three weights: 500 / 600 / 700.
abstract class AppTypography {
  // --- Brand header (hero) -------------------------------------------------
  static TextStyle employeeHeroAvatarInitial() => GoogleFonts.inter(
        color: AppColors.onBrand,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1,
      );

  static TextStyle employeeHeroGreeting(Color color) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.2,
      );

  static TextStyle employeeHeroName(Color color) => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -0.25,
        height: 1.2,
      );

  static TextStyle employeeHeroDate(Color color) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.25,
      );

  // --- Section eyebrows (ATTENDANCE, QUICK ACTIONS): 12–13 medium, gray ----
  static TextStyle employeeSectionEyebrow(Color color) => GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.45,
        height: 1.2,
        color: color,
      );

  /// Tight overline for dense cards (preferred over heavy ALL CAPS).
  static TextStyle employeeCardOverline(Color color) => GoogleFonts.inter(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.65,
        height: 1.2,
        color: color,
      );

  /// Card headings: "Today's times", "Self-service".
  static TextStyle employeeSectionHeading(Color color) => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.25,
        color: color,
      );

  /// Main status line: "You are clocked in".
  static TextStyle employeeAttendanceStatus(Color color) => GoogleFonts.inter(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.15,
        height: 1.2,
        color: color,
      );

  /// Snapshot card headline — slightly tighter than [employeeAttendanceStatus].
  static TextStyle employeeSnapshotHeadline(Color color) => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.38,
        height: 1.22,
        color: color,
        fontFeatures: const [FontFeature.liningFigures()],
      );

  /// Clock-in / clock-out row labels (sentence case, calm).
  static TextStyle employeeTimeRowLabel(Color color) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.02,
        height: 1.2,
        color: color,
      );

  /// CLOCK-IN / CLOCK-OUT caps labels.
  static TextStyle employeeTimeFieldLabel(Color color) => GoogleFonts.inter(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.55,
        height: 1.15,
        color: color,
      );

  /// Clock times — boldest, 20–24.
  static TextStyle employeeTimeNumeric(double layoutWidth) => GoogleFonts.inter(
        fontSize: layoutWidth >= 400 ? 22 : 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
        height: 1.15,
        color: AppColors.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// "In progress", em dash placeholder.
  static TextStyle employeeTimeSecondary() => GoogleFonts.inter(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.05,
        height: 1.2,
        color: AppColors.textSecondary.withValues(alpha: 0.94),
      );

  /// Day shift / shift pill (muted secondary).
  static TextStyle employeeShiftSecondary(Color color) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: color,
      );

  /// Primary circular action (Clock In / Clock Out).
  static TextStyle employeePrimaryActionLabel() => GoogleFonts.inter(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.08,
        letterSpacing: -0.08,
      );

  /// Filled rectangular button (Attendance log).
  static TextStyle employeeFilledButtonLabel() => GoogleFonts.inter(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.15,
        letterSpacing: 0.02,
      );

  /// Right-rail primary action (compact).
  static TextStyle employeeRailPrimaryLabel() => GoogleFonts.inter(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.05,
        letterSpacing: 0.06,
      );

  static TextStyle employeeRailSecondaryLabel() => GoogleFonts.inter(
        color: Colors.white.withValues(alpha: 0.72),
        fontSize: 9.5,
        fontWeight: FontWeight.w500,
        height: 1.1,
        letterSpacing: 0.12,
      );

  /// Quick-access grid labels (same button weight class).
  static TextStyle quickAccessTileLabel() => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary.withValues(alpha: 0.92),
        height: 1.2,
        letterSpacing: -0.05,
      );
}

/// Spacing and shape — keep employee (and similar) screens visually aligned.
abstract class AppLayout {
  static const double screenPaddingH = 20;
  static const double sectionGap = 8;
  static const double cardRadiusLg = 20;
  static const double navBarHeight = 72;
}

/// One–two layer shadows used across cards (avoid noisy multi-drop shadows).
abstract class AppElevation {
  static List<BoxShadow> cardOnSurface = [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, 8),
      spreadRadius: -4,
    ),
  ];

  static List<BoxShadow> cardTinted(Color accent) => [
        BoxShadow(
          color: accent.withValues(alpha: 0.12),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
        BoxShadow(
          color: AppColors.textPrimary.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
}

ThemeData buildAppTheme() {
  // [surfaceTint] from [ColorScheme.fromSeed] is derived from the seed (our blue
  // primary). Material 3 applies that tint across full-screen [Material] layers,
  // which can paint the whole employee body the same blue as the spinner — and
  // [CircularProgressIndicator] defaults to [ColorScheme.primary], so the
  // indicator disappears → looks like an "empty" blue screen while data loads.
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceTint: Colors.transparent,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surface,
    surfaceContainerHighest: AppColors.surface,
  );

  // Material 2 avoids M3 scaffold/surface-tint paths that still composite badly
  // on some Android emulators (solid primary-colored body, widgets “missing”).
  final base = ThemeData(
    useMaterial3: false,
    brightness: Brightness.light,
    colorScheme: scheme,
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.surface,
    canvasColor: AppColors.surface,
    // Instant transitions for any MaterialPageRoute leftovers (AppRoute
    // already uses zero-duration on web).
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _InstantPageTransitionsBuilder(),
        TargetPlatform.iOS: _InstantPageTransitionsBuilder(),
        TargetPlatform.linux: _InstantPageTransitionsBuilder(),
        TargetPlatform.macOS: _InstantPageTransitionsBuilder(),
        TargetPlatform.windows: _InstantPageTransitionsBuilder(),
        TargetPlatform.fuchsia: _InstantPageTransitionsBuilder(),
      },
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.primary,
      circularTrackColor: AppColors.divider.withValues(alpha: 0.6),
    ),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.cardBg,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: AppColors.border),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.divider, space: 1),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textHint,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      actionTextColor: AppColors.primaryLight,
    ),
  );
}

/// No animation — keeps Back / system pops from hitching while pages dispose.
class _InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

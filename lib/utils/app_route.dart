import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

/// Platform-aware navigation route used everywhere in the app.
///
/// **iOS / macOS**
/// * Push is **instant** (zero transition duration) — the screen appears the
///   moment you tap, exactly like switching a footer tab. No animation means
///   no first-frame hitch.
/// * Pop (back button) slides out in 200 ms.
/// * Swipe-back follows the finger via [CupertinoPageRoute]'s built-in
///   gesture detector — no delay, no threshold stutter.
/// * The **secondary animation** (parallax slide + dimming of the underlying
///   screen) is disabled, cutting per-frame GPU work roughly in half during
///   any back transition.
///
/// **Android / Web**
/// * 220 ms fade with [allowSnapshotting] — Flutter pre-rasterises both
///   screens before the animation starts, removing the first-frame hitch.
///
/// Usage — identical to [MaterialPageRoute]:
/// ```dart
/// Navigator.of(context).push(AppRoute(builder: (_) => const LeaveTab()));
/// ```
// ignore: non_constant_identifier_names
Route<T> AppRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
}) {
  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    return _AppIOSRoute<T>(builder: builder, settings: settings);
  }

  // Android / Web: fast fade, pre-rasterised on both enter and exit.
  return PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (ctx, _, __) => builder(ctx),
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    allowSnapshotting: true,
    transitionsBuilder: (ctx, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ),
      child: child,
    ),
  );
}

/// Subclass of [CupertinoPageRoute] with two changes:
///
/// 1. **`transitionDuration: Duration.zero`** — push is instant (no slide-in).
///    The screen appears immediately, like a tab swap in the footer bar.
///
/// 2. **Secondary animation disabled** — [kAlwaysDismissedAnimation] is passed
///    for the secondary slot, so the underlying screen never shifts left or
///    darkens. Halves GPU compositing cost on every pop / swipe-back frame.
///
/// Swipe-back and tap-back both still work: [CupertinoPageRoute] owns the
/// edge-gesture detector; the 200 ms [reverseTransitionDuration] drives the
/// slide-out after a committed pop.
class _AppIOSRoute<T> extends CupertinoPageRoute<T> {
  _AppIOSRoute({required super.builder, super.settings});

  /// Instant push — animation jumps to completed on frame 1.
  @override
  Duration get transitionDuration => Duration.zero;

  /// Pop slides out in 200 ms (tap-back or swipe-commit).
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Replace the real secondaryAnimation with one that is always at 0,
    // so the screen underneath never translates or dims — less per-frame work.
    return super.buildTransitions(
      context,
      animation,
      kAlwaysDismissedAnimation,
      child,
    );
  }
}

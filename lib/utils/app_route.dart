import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

/// Platform-aware navigation route used everywhere in the app.
///
/// **iOS / macOS**
/// * Push is **instant** (zero transition duration) — the screen appears the
///   moment you tap, exactly like switching a footer tab.
/// * Pop (back button) slides out in 350 ms with native Cupertino easing.
/// * Swipe-back follows the finger with full iOS parallax on the screen below.
/// * [allowSnapshotting] pre-rasterises both routes before the back animation,
///   so heavy screens (gradients, lists) move as textures instead of repainting
///   every frame.
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
  Widget wrappedBuilder(BuildContext ctx) =>
      RepaintBoundary(child: builder(ctx));

  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    return _AppIOSRoute<T>(builder: wrappedBuilder, settings: settings);
  }

  // Android / Web: fast fade, pre-rasterised on both enter and exit.
  return PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (ctx, _, __) => wrappedBuilder(ctx),
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

/// Subclass of [CupertinoPageRoute] tuned for myRekod:
///
/// 1. **`transitionDuration: Duration.zero`** — push is instant (no slide-in).
/// 2. **`reverseTransitionDuration: 350 ms`** — native iOS pop timing.
/// 3. **`allowSnapshotting: true`** — both routes are rasterised before back
///    transitions, keeping swipe-back at 60 fps even on gradient-heavy screens.
/// 4. **Default secondary animation** — underlying screen parallax + dimming
///    restored for native iOS feel (no frozen background).
class _AppIOSRoute<T> extends CupertinoPageRoute<T> {
  _AppIOSRoute({required super.builder, super.settings});

  /// Instant push — animation jumps to completed on frame 1.
  @override
  Duration get transitionDuration => Duration.zero;

  /// Native iOS pop slide-out (tap-back or swipe-commit).
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 350);

  /// Pre-rasterise route content before back/swipe transitions.
  @override
  bool get allowSnapshotting => true;
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

/// Platform-aware drop-in replacement for [MaterialPageRoute].
///
/// **iOS / macOS:** uses [CupertinoPageRoute] — native horizontal slide that
/// follows the user's finger during a swipe-back gesture. The interactive pop
/// feels identical to every other iPhone app; no delay or "stuck" sensation.
///
/// **Android / Web / other:** lightweight fade transition with
/// [allowSnapshotting] so Flutter pre-rasterises both screens before the
/// animation begins — eliminates the freeze that occurred with a heavy first
/// build during a slide transition.
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
  final platform = defaultTargetPlatform;
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
    // CupertinoPageRoute delivers:
    //   • Slide animation that follows the finger in real-time
    //   • Native swipe-back (no perceived delay, cancellable mid-drag)
    //   • allowSnapshotting: true by default in Flutter 3.16+
    return CupertinoPageRoute<T>(builder: builder, settings: settings);
  }

  // Android / Web: fast fade, pre-rasterised on both enter and exit.
  return PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (ctx, _, __) => builder(ctx),
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    allowSnapshotting: true,
    transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: child,
      );
    },
  );
}

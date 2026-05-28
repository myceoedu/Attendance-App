import 'package:flutter/material.dart';

/// Drop-in replacement for [MaterialPageRoute] that:
///
/// * Uses [allowSnapshotting] so Flutter pre-rasterises both the outgoing
///   and incoming surfaces before the animation begins — eliminating the
///   "stuck" freeze that occurs when the new screen's first build runs
///   during an in-flight slide transition.
/// * Replaces the heavyweight slide transform with a lightweight fade
///   (no matrix translation → cheaper GPU compositing).
/// * Shorter durations (220 ms forward, 180 ms reverse) feel snappier than
///   the default 300 ms slide.
///
/// Usage — identical to [MaterialPageRoute]:
/// ```dart
/// Navigator.of(context).push(AppRoute(builder: (_) => const LeaveTab()));
/// ```
class AppRoute<T> extends PageRouteBuilder<T> {
  AppRoute({required WidgetBuilder builder, super.settings})
      : super(
          pageBuilder: (ctx, _, __) => builder(ctx),
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          // Pre-rasterise both screens so no build work happens mid-animation.
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

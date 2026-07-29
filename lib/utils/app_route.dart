import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Platform-aware navigation route used everywhere in the app.
///
/// **iOS / macOS** — instant push, Cupertino pop / swipe-back.
/// **Web** — near-instant push (avoids fade hitch while building pages).
/// **Android / desktop** — short fade with snapshotting.
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

  // Web: zero-duration enter so taps feel instant; short fade on pop only.
  // Android/desktop: short fade with pre-rasterisation.
  final enter =
      kIsWeb ? Duration.zero : const Duration(milliseconds: 160);
  final exit =
      kIsWeb ? const Duration(milliseconds: 120) : const Duration(milliseconds: 140);

  return PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (ctx, _, __) => wrappedBuilder(ctx),
    transitionDuration: enter,
    reverseTransitionDuration: exit,
    allowSnapshotting: true,
    transitionsBuilder: (ctx, animation, _, child) {
      if (enter == Duration.zero &&
          animation.status != AnimationStatus.reverse) {
        return child;
      }
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

/// Pushes [page] after the current frame so InkWell/ripple can paint first.
/// Prefer this from grid tiles and dashboard shortcuts for smoother taps.
Future<T?> pushAppPage<T>(
  BuildContext context,
  Widget page, {
  bool haptic = true,
}) {
  if (haptic) HapticFeedback.selectionClick();
  final nav = Navigator.of(context);
  final completer = Completer<T?>();
  SchedulerBinding.instance.scheduleFrameCallback((_) {
    if (!context.mounted) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    completer.complete(nav.push<T>(AppRoute(builder: (_) => page)));
  });
  SchedulerBinding.instance.scheduleFrame();
  return completer.future;
}

/// Subclass of [CupertinoPageRoute] tuned for myRekod.
class _AppIOSRoute<T> extends CupertinoPageRoute<T> {
  _AppIOSRoute({required super.builder, super.settings});

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 350);

  @override
  bool get allowSnapshotting => true;
}

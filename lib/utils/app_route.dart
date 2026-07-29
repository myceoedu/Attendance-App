import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Platform-aware navigation used everywhere in the app.
///
/// **Web (incl. Safari Add to Home Screen)** — instant push & pop. Fade/slide
/// during route build is the main cause of “stuck” taps and sluggish Back.
/// **Native iOS/macOS** — instant push, short Cupertino pop.
/// **Android / desktop** — very short fade with snapshotting.
// ignore: non_constant_identifier_names
Route<T> AppRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
}) {
  Widget wrappedBuilder(BuildContext ctx) =>
      RepaintBoundary(child: builder(ctx));

  // Web first: iPhone Safari reports TargetPlatform.iOS, which previously
  // forced a 350ms Cupertino pop and felt stuck.
  if (kIsWeb) {
    return _InstantPageRoute<T>(
      builder: wrappedBuilder,
      settings: settings,
    );
  }

  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    return _AppIOSRoute<T>(builder: wrappedBuilder, settings: settings);
  }

  return PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (ctx, _, __) => wrappedBuilder(ctx),
    transitionDuration: const Duration(milliseconds: 120),
    reverseTransitionDuration: const Duration(milliseconds: 100),
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

/// Zero-duration route — no animation hitch while the next page builds.
class _InstantPageRoute<T> extends PageRouteBuilder<T> {
  _InstantPageRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          pageBuilder: (ctx, _, __) => builder(ctx),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          allowSnapshotting: true,
          opaque: true,
          transitionsBuilder: (ctx, animation, _, child) => child,
        );
}

/// Pushes [page] with light haptic. On web, pushes immediately (instant route).
/// On native, yields one frame so InkWell ripple can paint first.
Future<T?> pushAppPage<T>(
  BuildContext context,
  Widget page, {
  bool haptic = true,
}) {
  if (haptic) HapticFeedback.selectionClick();
  final nav = Navigator.of(context);
  final route = AppRoute<T>(builder: (_) => page);

  if (kIsWeb) {
    return nav.push<T>(route);
  }

  final completer = Completer<T?>();
  SchedulerBinding.instance.scheduleFrameCallback((_) {
    if (!context.mounted) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    completer.complete(nav.push<T>(route));
  });
  SchedulerBinding.instance.scheduleFrame();
  return completer.future;
}

/// Instant pop with optional haptic — use for AppBar back / custom backs.
void popApp(BuildContext context, [Object? result]) {
  HapticFeedback.selectionClick();
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop(result);
  }
}

class _AppIOSRoute<T> extends CupertinoPageRoute<T> {
  _AppIOSRoute({required super.builder, super.settings});

  @override
  Duration get transitionDuration => Duration.zero;

  /// Shorter than stock Cupertino (350ms) so Back feels snappy.
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  bool get allowSnapshotting => true;
}

import 'package:flutter/foundation.dart';

/// Debug-only wall-clock from process start (`main`) for startup diagnostics.
///
/// Compare runs in **profile** or **debug** console:
/// - `binding_ready` → `supabase_ready` = Supabase init
/// - `run_app_scheduled` → `first_frame` = time to first paint
/// - `auth_interactive_*` = spinner gone (login or shell route)
/// - `auth_profile_refresh_done` = background profile fetch finished (cached path only)
class StartupTiming {
  StartupTiming._();

  static final Stopwatch _sw = Stopwatch();

  /// Last elapsed ms for each named milestone (latest call wins).
  static final Map<String, int> _marksMs = {};

  static int? get totalElapsedMs =>
      _sw.isRunning ? _sw.elapsedMilliseconds : null;

  /// Call once from `main` after binding init; starts the stopwatch.
  static void ensureStarted() {
    if (!_sw.isRunning) _sw.start();
  }

  static void mark(String name) {
    if (!kDebugMode) return;
    ensureStarted();
    final ms = _sw.elapsedMilliseconds;
    _marksMs[name] = ms;
    debugPrint('[Startup] $name @ ${ms}ms');
  }

  /// Delta from prior milestone in the typical startup chain (if present).
  static void reportDeltas() {
    if (!kDebugMode) return;
    const chain = [
      'binding_ready',
      'supabase_ready',
      'run_app_scheduled',
      'first_frame',
    ];
    int? prev;
    final buf = StringBuffer('[Startup] deltas (ms): ');
    for (final name in chain) {
      final ms = _marksMs[name];
      if (ms == null) continue;
      if (prev != null) {
        buf.write('$name +${ms - prev} ');
      }
      prev = ms;
    }
    debugPrint(buf.toString());
  }

  static void reportAuthPath({
    required bool hadSession,
    required bool usedCache,
    required bool backgroundRefreshScheduled,
  }) {
    if (!kDebugMode) return;
    final interactive = usedCache
        ? 'auth_interactive_cached'
        : (hadSession
            ? 'auth_interactive_network'
            : 'auth_interactive_guest');
    final ms = _marksMs[interactive];
    if (ms != null) {
      debugPrint(
        '[Startup] $interactive: spinner dismissed @ ${ms}ms '
        '(cache=$usedCache refresh=$backgroundRefreshScheduled)',
      );
    }
    final first = _marksMs['first_frame'];
    if (ms != null && first != null) {
      debugPrint(
        '[Startup] first_frame → auth_interactive: ${ms - first}ms '
        '(time from first paint to route)',
      );
    }
    final authStart = _marksMs['auth_init_start'];
    if (ms != null && authStart != null) {
      debugPrint(
        '[Startup] auth_init_start → auth_interactive: ${ms - authStart}ms',
      );
    }
  }
}

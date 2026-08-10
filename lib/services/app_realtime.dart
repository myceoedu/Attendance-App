import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Test hook for building a channel.
typedef RealtimeChannelBuilder =
    RealtimeChannel Function({
      required String topic,
      required String table,
      String? filterColumn,
      String? filterValue,
      required void Function() onEvent,
    });

/// Handle for a shared realtime topic.
final class RealtimeSubscription {
  RealtimeSubscription._(this._topic, this._onReload);

  final String _topic;
  final void Function() _onReload;
  bool _released = false;
}

class _SharedTopic {
  RealtimeChannel? channel;
  final List<RealtimeSubscription> subscribers = [];
  bool teardownScheduled = false;
}

/// Supabase Realtime helpers. Tables must be in the `supabase_realtime`
/// publication (see `supabase_setup.sql`).
///
/// Channels are pooled by topic. Multiple screens can share one channel.
final class AppRealtime {
  AppRealtime._();

  static final Map<String, _SharedTopic> _topics = {};

  static RealtimeChannelBuilder _channelBuilder = _defaultChannelBuilder;
  static void Function(RealtimeChannel) _channelRemover = _defaultChannelRemover;

  /// Override channel open/close for tests. Pass null to restore defaults.
  @visibleForTesting
  static void debugSetChannelBuilder(
    RealtimeChannelBuilder? builder, {
    void Function(RealtimeChannel)? remover,
  }) {
    _channelBuilder = builder ?? _defaultChannelBuilder;
    _channelRemover = remover ?? _defaultChannelRemover;
  }

  @visibleForTesting
  static int debugTopicCount() => _topics.length;

  static void _defaultChannelRemover(RealtimeChannel channel) {
    unawaited(SupabaseService.client.removeChannel(channel));
  }

  static RealtimeChannel _defaultChannelBuilder({
    required String topic,
    required String table,
    String? filterColumn,
    String? filterValue,
    required void Function() onEvent,
  }) {
    return SupabaseService.client
        .channel(topic)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          filter: (filterColumn == null || filterValue == null)
              ? null
              : PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: filterColumn,
                  value: filterValue,
                ),
          callback: (_) => onEvent(),
        )
        .subscribe();
  }

  static RealtimeSubscription _subscribe({
    required String topic,
    required String table,
    String? filterColumn,
    String? filterValue,
    required void Function() onReload,
  }) {
    final handle = RealtimeSubscription._(topic, onReload);
    final existing = _topics[topic];
    if (existing != null) {
      existing.subscribers.add(handle);
      return handle;
    }

    final shared = _SharedTopic();
    _topics[topic] = shared;
    shared.subscribers.add(handle);
    shared.channel = _channelBuilder(
      topic: topic,
      table: table,
      filterColumn: filterColumn,
      filterValue: filterValue,
      onEvent: () => _fanOut(topic),
    );
    return handle;
  }

  static void _fanOut(String topic) {
    final shared = _topics[topic];
    if (shared == null) return;
    // Snapshot in case a listener releases itself during the callback.
    for (final subscriber in List.of(shared.subscribers)) {
      if (!subscriber._released) subscriber._onReload();
    }
  }

  /// Release one subscriber. Closes the channel when none remain.
  static void disposeChannel(RealtimeSubscription? subscription) {
    if (subscription == null || subscription._released) return;
    subscription._released = true;

    final topic = subscription._topic;
    final shared = _topics[topic];
    if (shared == null) return;
    shared.subscribers.remove(subscription);
    if (shared.subscribers.isNotEmpty || shared.teardownScheduled) return;

    // Delay close so a replacement screen can reuse the channel.
    shared.teardownScheduled = true;
    scheduleMicrotask(() {
      shared.teardownScheduled = false;
      if (shared.subscribers.isNotEmpty) return;
      if (!identical(_topics[topic], shared)) return;
      _topics.remove(topic);
      final channel = shared.channel;
      if (channel != null) _channelRemover(channel);
    });
  }

  /// Close all pooled channels (call on sign-out).
  static void disposeAll() {
    final topics = List.of(_topics.values);
    _topics.clear();
    for (final shared in topics) {
      for (final subscriber in shared.subscribers) {
        subscriber._released = true;
      }
      shared.subscribers.clear();
      final channel = shared.channel;
      if (channel != null) _channelRemover(channel);
    }
  }

  static RealtimeSubscription subscribeMyAttendance({
    required String userId,
    required void Function() onReload,
  }) {
    return _subscribe(
      topic: 'attendance:user:$userId',
      table: 'attendance',
      filterColumn: 'user_id',
      filterValue: userId,
      onReload: onReload,
    );
  }

  static RealtimeSubscription subscribeMyLeaves({
    required String userId,
    required void Function() onReload,
  }) {
    return _subscribe(
      topic: 'leave_requests:user:$userId',
      table: 'leave_requests',
      filterColumn: 'user_id',
      filterValue: userId,
      onReload: onReload,
    );
  }

  static RealtimeSubscription subscribeMyNotifications({
    required String userId,
    required void Function() onReload,
  }) {
    return _subscribe(
      topic: 'app_notifications:user:$userId',
      table: 'app_notifications',
      filterColumn: 'user_id',
      filterValue: userId,
      onReload: onReload,
    );
  }

  static RealtimeSubscription subscribeMyClaims({
    required String userId,
    required void Function() onReload,
  }) {
    return _subscribe(
      topic: 'expense_claims:user:$userId',
      table: 'expense_claims',
      filterColumn: 'user_id',
      filterValue: userId,
      onReload: onReload,
    );
  }

  /// Admin attendance changes (RLS-scoped).
  static RealtimeSubscription subscribeAdminAttendance({
    required void Function() onReload,
  }) {
    return _subscribe(
      topic: 'attendance:all',
      table: 'attendance',
      onReload: onReload,
    );
  }

  static RealtimeSubscription subscribeAdminLeaves({
    required void Function() onReload,
  }) {
    return _subscribe(
      topic: 'leave_requests:all',
      table: 'leave_requests',
      onReload: onReload,
    );
  }

  static RealtimeSubscription subscribeAdminClaims({
    required void Function() onReload,
  }) {
    return _subscribe(
      topic: 'expense_claims:all',
      table: 'expense_claims',
      onReload: onReload,
    );
  }

  /// Company announcements.
  static RealtimeSubscription subscribeCompanyAnnouncements({
    required void Function() onReload,
  }) {
    return _subscribe(
      topic: 'company_announcements:all',
      table: 'company_announcements',
      onReload: onReload,
    );
  }
}

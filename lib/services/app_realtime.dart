import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Builds the underlying channel for a topic. Overridable in tests.
typedef RealtimeChannelBuilder =
    RealtimeChannel Function({
      required String topic,
      required String table,
      String? filterColumn,
      String? filterValue,
      required void Function() onEvent,
    });

/// One subscriber's handle on a shared realtime topic.
///
/// Screens hold this instead of the channel itself so several widgets can
/// watch the same table without opening a websocket topic each.
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
/// Subscriptions are pooled by topic. Previously every screen opened its own
/// channel, so an admin with the dashboard, attendance list, and leave inbox in
/// the navigation stack held three channels on overlapping tables, and the
/// notification bell duplicated the notifications screen for the same user.
final class AppRealtime {
  AppRealtime._();

  static final Map<String, _SharedTopic> _topics = {};

  static RealtimeChannelBuilder _channelBuilder = _defaultChannelBuilder;
  static void Function(RealtimeChannel) _channelRemover = _defaultChannelRemover;

  /// Swaps the transport so pooling can be exercised without a live client.
  /// Passing `null` restores the Supabase-backed implementations.
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
    // Copy first: a listener may release its own subscription while reloading.
    for (final subscriber in List.of(shared.subscribers)) {
      if (!subscriber._released) subscriber._onReload();
    }
  }

  /// Releases one subscriber. The channel closes once the last one is gone.
  static void disposeChannel(RealtimeSubscription? subscription) {
    if (subscription == null || subscription._released) return;
    subscription._released = true;

    final topic = subscription._topic;
    final shared = _topics[topic];
    if (shared == null) return;
    shared.subscribers.remove(subscription);
    if (shared.subscribers.isNotEmpty || shared.teardownScheduled) return;

    // Deferred so channel removal does not compete with the final pop
    // animation frame, and so a replacement screen subscribing during the same
    // transition can reuse the still-open channel.
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

  /// Drops every pooled channel. Used on sign-out so a new session does not
  /// inherit topics scoped to the previous account.
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

  /// Admins receive rows allowed by RLS (typically all).
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

  /// New posts visible to all authenticated users (RLS).
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

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Supabase Realtime helpers. Tables must be in `supabase_realtime` publication
/// (see [supabase_setup.sql]).
final class AppRealtime {
  AppRealtime._();

  static void disposeChannel(RealtimeChannel? channel) {
    if (channel == null) return;
    // Defer teardown so Supabase channel removal does not compete with the
    // final pop animation frame on iOS.
    scheduleMicrotask(() {
      unawaited(SupabaseService.client.removeChannel(channel));
    });
  }

  static RealtimeChannel subscribeMyAttendance({
    required String userId,
    required String channelSuffix,
    required void Function() onReload,
  }) {
    return SupabaseService.client
        .channel('attendance_${channelSuffix}_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendance',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => onReload(),
        )
        .subscribe();
  }

  static RealtimeChannel subscribeMyLeaves({
    required String userId,
    required String channelSuffix,
    required void Function() onReload,
  }) {
    return SupabaseService.client
        .channel('leave_${channelSuffix}_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'leave_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => onReload(),
        )
        .subscribe();
  }

  static RealtimeChannel subscribeMyNotifications({
    required String userId,
    required String channelSuffix,
    required void Function() onReload,
  }) {
    return SupabaseService.client
        .channel('notif_${channelSuffix}_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => onReload(),
        )
        .subscribe();
  }

  /// Admins receive rows allowed by RLS (typically all).
  static RealtimeChannel subscribeAdminAttendance({
    required String channelSuffix,
    required void Function() onReload,
  }) {
    return SupabaseService.client
        .channel('admin_att_$channelSuffix')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendance',
          callback: (_) => onReload(),
        )
        .subscribe();
  }

  static RealtimeChannel subscribeAdminLeaves({
    required String channelSuffix,
    required void Function() onReload,
  }) {
    return SupabaseService.client
        .channel('admin_leave_$channelSuffix')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'leave_requests',
          callback: (_) => onReload(),
        )
        .subscribe();
  }

  static RealtimeChannel subscribeMyClaims({
    required String userId,
    required String channelSuffix,
    required void Function() onReload,
  }) {
    return SupabaseService.client
        .channel('claim_${channelSuffix}_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'expense_claims',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => onReload(),
        )
        .subscribe();
  }

  static RealtimeChannel subscribeAdminClaims({
    required String channelSuffix,
    required void Function() onReload,
  }) {
    return SupabaseService.client
        .channel('admin_claim_$channelSuffix')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'expense_claims',
          callback: (_) => onReload(),
        )
        .subscribe();
  }

  /// New posts visible to all authenticated users (RLS).
  static RealtimeChannel subscribeCompanyAnnouncements({
    required String channelSuffix,
    required void Function() onReload,
  }) {
    return SupabaseService.client
        .channel('announcements_$channelSuffix')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'company_announcements',
          callback: (_) => onReload(),
        )
        .subscribe();
  }
}

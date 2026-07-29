import '../models/company_announcement.dart';
import '../utils/prefs_cache.dart';
import 'supabase_service.dart';

/// Tracks the newest `created_at` the employee has **seen** in
/// [AnnouncementsScreen] and counts posts newer than that (local unread).
class AnnouncementBadgeService {
  AnnouncementBadgeService._();

  static String _prefsKey(String userId) =>
      'announcement_seen_newest_created_utc_us_v3_$userId';

  /// Cursor = newest `created_at` among rows returned (or "now" if list empty).
  ///
  /// Stored using **microseconds** so DB timestamps are not truncated. Using
  /// ms-only made `isAfter(cursor)` stay true for the newest row, so the badge
  /// never cleared after opening the list.
  static Future<void> markAnnouncementsSeenFromList(
    String userId,
    List<CompanyAnnouncement> visible,
  ) async {
    final DateTime utc;
    if (visible.isEmpty) {
      utc = DateTime.now().toUtc();
    } else {
      utc = visible
          .map((e) => e.createdAt.toUtc())
          .reduce((a, b) => a.isAfter(b) ? a : b);
    }
    final p = await PrefsCache.instance();
    await p.setInt(_prefsKey(userId), utc.microsecondsSinceEpoch);
  }

  static Future<DateTime?> _newestSeenCursorUtc(String userId) async {
    final p = await PrefsCache.instance();
    final us = p.getInt(_prefsKey(userId));
    if (us == null) return null;
    return DateTime.fromMicrosecondsSinceEpoch(us, isUtc: true);
  }

  /// Posts with `created_at` strictly after the stored cursor.
  /// No cursor yet → total current count (everything is "new" until they open).
  static Future<int> unreadCountForUser(String userId) async {
    final cursor = await _newestSeenCursorUtc(userId);
    return SupabaseService.getCompanyAnnouncementCountAfter(cursor);
  }
}

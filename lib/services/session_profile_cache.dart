import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

/// Persists the last loaded [AppUser] for the signed-in auth id so cold start can
/// paint shell immediately and refresh from Supabase in the background.
class SessionProfileCache {
  SessionProfileCache._();

  static const _key = 'attendance_app_profile_cache_v1';

  static Future<AppUser?> loadIfMatches(String authUserId) async {
    if (authUserId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final id = map['id'] as String?;
      if (id == null || id != authUserId) return null;
      return AppUser.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(user.toMap()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

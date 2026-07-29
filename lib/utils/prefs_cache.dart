import 'package:shared_preferences/shared_preferences.dart';

/// Shared [SharedPreferences] handle so cold paths do not re-open storage.
class PrefsCache {
  PrefsCache._();

  static SharedPreferences? _instance;
  static Future<SharedPreferences>? _loading;

  static Future<SharedPreferences> instance() {
    final existing = _instance;
    if (existing != null) return Future.value(existing);
    final inFlight = _loading;
    if (inFlight != null) return inFlight;
    final future = SharedPreferences.getInstance().then((prefs) {
      _instance = prefs;
      _loading = null;
      return prefs;
    });
    _loading = future;
    return future;
  }
}

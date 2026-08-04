import 'dart:math' as math;

/// Local distance helpers for workplace geofence (matches SQL Haversine).
abstract final class Geofence {
  static const minRadiusMeters = 20;
  static const maxRadiusMeters = 5000;
  static const defaultRadiusMeters = 100;

  /// Parse `"lat,lng"` from attendance location string.
  static ({double lat, double lng})? parseLatLng(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return (lat: lat, lng: lng);
  }

  /// Great-circle distance in metres.
  static double distanceMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const earth = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earth * 2 * math.asin(math.sqrt(a));
  }

  static bool isWithinRadius({
    required double siteLat,
    required double siteLng,
    required double userLat,
    required double userLng,
    required int radiusMeters,
  }) {
    final d = distanceMeters(
      lat1: siteLat,
      lng1: siteLng,
      lat2: userLat,
      lng2: userLng,
    );
    return d <= radiusMeters;
  }

  static double _rad(double deg) => deg * math.pi / 180.0;
}

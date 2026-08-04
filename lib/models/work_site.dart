/// Singleton company workplace used for clock-in geofencing.
class WorkSite {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final bool isActive;
  final DateTime? updatedAt;

  const WorkSite({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.isActive,
    this.updatedAt,
  });

  factory WorkSite.fromMap(Map<String, dynamic> map) {
    return WorkSite(
      id: (map['id'] as num?)?.toInt() ?? 1,
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? (map['name'] as String).trim()
          : 'Workplace',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      radiusMeters: (map['radius_meters'] as num?)?.toInt() ?? 100,
      isActive: map['is_active'] as bool? ?? false,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toUpsertMap({String? updatedBy}) {
    return {
      'id': 1,
      'name': name.trim().isEmpty ? 'Workplace' : name.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (updatedBy != null) 'updated_by': updatedBy,
    };
  }

  WorkSite copyWith({
    String? name,
    double? latitude,
    double? longitude,
    int? radiusMeters,
    bool? isActive,
  }) {
    return WorkSite(
      id: id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt,
    );
  }
}

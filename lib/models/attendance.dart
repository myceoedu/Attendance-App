class Attendance {
  /// Optimistic clock-in rows use ids with this prefix until the server row is returned.
  static const String pendingLocalIdPrefix = 'local-';

  static bool isPendingLocalSyncId(String id) =>
      id.startsWith(pendingLocalIdPrefix);

  final String id;
  final String userId;
  final DateTime? clockInTime;
  final DateTime? clockOutTime;
  final DateTime date;
  final String status; // 'present', 'in_progress', 'completed'
  final String? location;
  final String? userName; // populated via join

  Attendance({
    required this.id,
    required this.userId,
    this.clockInTime,
    this.clockOutTime,
    required this.date,
    required this.status,
    this.location,
    this.userName,
  });

  factory Attendance.fromMap(Map<String, dynamic> map) {
    final usersData = map['users'];
    String? userName;
    if (usersData is Map<String, dynamic>) {
      userName = usersData['name'] as String?;
    }

    return Attendance(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      clockInTime: map['clock_in_time'] != null
          ? DateTime.parse(map['clock_in_time'] as String)
          : null,
      clockOutTime: map['clock_out_time'] != null
          ? DateTime.parse(map['clock_out_time'] as String)
          : null,
      date: DateTime.parse(map['date'] as String),
      status: map['status'] as String? ?? 'present',
      location: map['location'] as String?,
      userName: userName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'clock_in_time': clockInTime?.toIso8601String(),
      'clock_out_time': clockOutTime?.toIso8601String(),
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'status': status,
      'location': location,
    };
  }
}

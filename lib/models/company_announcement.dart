class CompanyAnnouncement {
  CompanyAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.createdBy,
    required this.createdAt,
    this.authorName,
  });

  final String id;
  final String title;
  final String body;
  final String createdBy;
  final DateTime createdAt;
  final String? authorName;

  static String? _parseAuthorName(Map<String, dynamic> map) {
    final nested = map['users'];
    if (nested is Map<String, dynamic>) {
      final n = nested['name'];
      if (n is String && n.trim().isNotEmpty) return n.trim();
    }
    return null;
  }

  factory CompanyAnnouncement.fromMap(Map<String, dynamic> map) {
    return CompanyAnnouncement(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      authorName: _parseAuthorName(map),
    );
  }
}

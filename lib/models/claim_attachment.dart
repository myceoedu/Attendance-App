class ClaimAttachment {
  final String id;
  final String claimId;
  final String storagePath;
  final String originalName;
  final int? byteSize;
  final String? contentType;
  final DateTime createdAt;

  ClaimAttachment({
    required this.id,
    required this.claimId,
    required this.storagePath,
    required this.originalName,
    this.byteSize,
    this.contentType,
    required this.createdAt,
  });

  factory ClaimAttachment.fromMap(Map<String, dynamic> map) {
    final bs = map['byte_size'];
    return ClaimAttachment(
      id: map['id'] as String,
      claimId: map['claim_id'] as String,
      storagePath: map['storage_path'] as String,
      originalName: map['original_name'] as String? ?? '',
      byteSize: bs == null ? null : (bs is int ? bs : (bs as num).toInt()),
      contentType: map['content_type'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  String get shortName {
    final n = originalName.trim();
    if (n.isEmpty) return 'Attachment';
    if (n.length <= 36) return n;
    return '${n.substring(0, 33)}…';
  }
}

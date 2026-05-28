class LeaveAuditLog {
  final String id;
  final String leaveRequestId;
  final String action;
  final String? fromStatus;
  final String? toStatus;
  final String? comment;
  final String? actorUserId;
  final String actorName;
  final DateTime createdAt;

  const LeaveAuditLog({
    required this.id,
    required this.leaveRequestId,
    required this.action,
    this.fromStatus,
    this.toStatus,
    this.comment,
    this.actorUserId,
    required this.actorName,
    required this.createdAt,
  });

  factory LeaveAuditLog.fromMap(Map<String, dynamic> map) {
    return LeaveAuditLog(
      id: map['id'] as String,
      leaveRequestId: map['leave_request_id'] as String,
      action: map['action'] as String? ?? '',
      fromStatus: map['from_status'] as String?,
      toStatus: map['to_status'] as String?,
      comment: map['comment'] as String?,
      actorUserId: map['actor_user_id'] as String?,
      actorName: map['actor_name'] as String? ?? 'System',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

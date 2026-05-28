import '../utils/leave_catalog.dart';

class LeaveRequest {
  final String id;
  final String userId;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status; // 'pending', 'approved', 'rejected'
  final String? adminComment;
  /// Path inside Supabase Storage bucket `leave-attachments` (not a public URL).
  final String? attachmentPath;
  final DateTime createdAt;
  final String? userName; // populated via join

  LeaveRequest({
    required this.id,
    required this.userId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    this.adminComment,
    this.attachmentPath,
    required this.createdAt,
    this.userName,
  });

  factory LeaveRequest.fromMap(Map<String, dynamic> map) {
    final usersData = map['users'];
    String? userName;
    if (usersData is Map<String, dynamic>) {
      userName = usersData['name'] as String?;
    }

    return LeaveRequest(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      leaveType: map['leave_type'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      reason: map['reason'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      adminComment: map['admin_comment'] as String?,
      attachmentPath: map['attachment_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      userName: userName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'leave_type': leaveType,
      'start_date': '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
      'end_date': '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
      'reason': reason,
      'status': status,
      'admin_comment': adminComment,
      if (attachmentPath != null) 'attachment_path': attachmentPath,
    };
  }

  String get leaveTypeDisplay => LeaveCatalog.displayName(leaveType);

  int get durationDays => endDate.difference(startDate).inDays + 1;

  String get durationDisplayLabel => LeaveCatalog.durationLabel(this);
}

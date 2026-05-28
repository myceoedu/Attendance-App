import 'claim_attachment.dart';

class ExpenseClaim {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String category;
  final double amount;
  final String currency;
  final DateTime expenseDate;
  final String status;
  final String? adminComment;
  final DateTime createdAt;
  final String? userName;
  final List<ClaimAttachment> attachments;

  ExpenseClaim({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.category,
    required this.amount,
    required this.currency,
    required this.expenseDate,
    required this.status,
    this.adminComment,
    required this.createdAt,
    this.userName,
    this.attachments = const [],
  });

  factory ExpenseClaim.fromMap(
    Map<String, dynamic> map, {
    List<ClaimAttachment>? attachmentsOverride,
  }) {
    final usersData = map['users'];
    String? userName;
    if (usersData is Map<String, dynamic>) {
      userName = usersData['name'] as String?;
    }

    List<ClaimAttachment> attachments = attachmentsOverride ?? const [];
    final rawAtt = map['claim_attachments'];
    if (attachmentsOverride == null && rawAtt is List) {
      attachments = rawAtt
          .whereType<Map<String, dynamic>>()
          .map(ClaimAttachment.fromMap)
          .toList();
    }

    final amountRaw = map['amount'];
    final amount = amountRaw is num
        ? amountRaw.toDouble()
        : double.tryParse('$amountRaw') ?? 0;

    return ExpenseClaim(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? 'other',
      amount: amount,
      currency: map['currency'] as String? ?? 'MYR',
      expenseDate: DateTime.parse(map['expense_date'] as String),
      status: map['status'] as String? ?? 'pending',
      adminComment: map['admin_comment'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      userName: userName,
      attachments: attachments,
    );
  }

  String get categoryDisplay {
    switch (category) {
      case 'meal':
        return 'Meals & refreshments';
      case 'transport':
        return 'Transport & mileage';
      case 'accommodation':
        return 'Accommodation';
      case 'supplies':
        return 'Office supplies & equipment';
      case 'medical':
        return 'Medical';
      case 'communications':
        return 'Phone, data & postage';
      case 'training':
        return 'Training & courses';
      case 'client_entertainment':
        return 'Client entertainment';
      case 'other':
        return 'Other';
      default:
        return category;
    }
  }

  int get attachmentCount => attachments.length;
}

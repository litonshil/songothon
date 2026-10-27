import 'package:equatable/equatable.dart';

class NotificationModel extends Equatable {
  final String id;
  final String? orgId;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    this.orgId,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? 'general',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, orgId, userId, title, body, type, isRead, createdAt];
}

class ScheduledNotificationModel extends Equatable {
  final String id;
  final String orgId;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String repeatRule;
  final DateTime? lastSentAt;
  final bool isActive;
  final DateTime createdAt;

  const ScheduledNotificationModel({
    required this.id,
    required this.orgId,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.repeatRule,
    this.lastSentAt,
    required this.isActive,
    required this.createdAt,
  });

  factory ScheduledNotificationModel.fromJson(Map<String, dynamic> json) {
    return ScheduledNotificationModel(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      scheduledAt: DateTime.tryParse(json['scheduled_at']?.toString() ?? '') ?? DateTime.now(),
      repeatRule: json['repeat_rule']?.toString() ?? 'once',
      lastSentAt: DateTime.tryParse(json['last_sent_at']?.toString() ?? ''),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, orgId, title, body, scheduledAt, repeatRule, lastSentAt, isActive, createdAt];
}

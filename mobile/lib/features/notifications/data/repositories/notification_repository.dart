import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_constants.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final ApiClient apiClient;

  NotificationRepository({required this.apiClient});

  Future<List<NotificationModel>> listNotifications() async {
    try {
      final response = await apiClient.dio.get(ApiConstants.notifications);
      final list = response.data['data'] as List? ?? [];
      return list.map((item) => NotificationModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await apiClient.dio.patch(ApiConstants.markNotificationRead(id));
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await apiClient.dio.post(ApiConstants.notificationsReadAll);
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<void> scheduleNotification({
    required String slug,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required String repeatRule,
  }) async {
    try {
      await apiClient.dio.post(
        ApiConstants.adminScheduleNotification(slug),
        data: {
          'title': title.trim(),
          'body': body.trim(),
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'repeat_rule': repeatRule,
        },
      );
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<List<ScheduledNotificationModel>> listScheduled(String slug) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.adminScheduledNotifications(slug));
      final list = response.data['data'] as List? ?? [];
      return list.map((item) => ScheduledNotificationModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<void> deleteScheduled(String slug, String id) async {
    try {
      await apiClient.dio.delete(ApiConstants.adminDeleteScheduledNotification(slug, id));
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }
}

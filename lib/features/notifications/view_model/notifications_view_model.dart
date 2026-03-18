import 'package:flutter/material.dart';
import 'package:firebase_orscheduler/data/repositories/notification_repository.dart';
import 'package:firebase_orscheduler/data/models/notification_model.dart';
import 'package:logging/logging.dart';

/// ViewModel for the notifications screen.
/// Resolves TODO: navigation to surgery details.
class NotificationsViewModel extends ChangeNotifier {
  final NotificationRepository _notificationRepository;
  final _logger = Logger('NotificationsViewModel');

  bool _isLoading = false;
  String? _error;

  NotificationsViewModel({NotificationRepository? notificationRepository})
      : _notificationRepository =
            notificationRepository ?? NotificationRepository();

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Stream notifications for the current user.
  Stream<List<NotificationModel>> getNotificationsStream() {
    return _notificationRepository.getNotificationsStream();
  }

  /// Stream unread count.
  Stream<int> getUnreadCountStream() {
    return _notificationRepository.getUnreadCountStream();
  }

  /// Mark a notification as read.
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationRepository.markAsRead(notificationId);
    } catch (e) {
      _logger.warning('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read.
  Future<void> markAllAsRead() async {
    try {
      await _notificationRepository.markAllAsRead();
    } catch (e) {
      _logger.warning('Error marking all as read: $e');
    }
  }

  /// Delete a notification.
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationRepository.deleteNotification(notificationId);
    } catch (e) {
      _logger.warning('Error deleting notification: $e');
    }
  }

  /// Delete all notifications.
  Future<void> deleteAllNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _notificationRepository.deleteAllNotifications();
      _logger.info('All notifications deleted');
    } catch (e) {
      _error = 'Failed to delete notifications';
      _logger.warning('Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get the surgery ID from a notification for navigation.
  /// Resolves the TODO for surgery details navigation.
  String? getSurgeryId(NotificationModel notification) {
    return notification.surgeryId;
  }
}

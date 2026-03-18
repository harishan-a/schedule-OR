import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';

/// Service wrapper for flutter_local_notifications.
/// Extracted from NotificationManager.
class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin;
  final _logger = Logger('LocalNotificationService');

  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Initialize the local notification plugin.
  Future<void> initialize({
    void Function(NotificationResponse)? onSelectNotification,
  }) async {
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      final iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      final settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: onSelectNotification,
      );
      _logger.info('Local notifications initialized');
    } catch (e) {
      _logger.warning('Error initializing local notifications: $e');
    }
  }

  /// Show a local notification.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'or_scheduler_channel',
        'OR Scheduler',
        channelDescription: 'Surgery scheduling notifications',
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.show(id, title, body, details, payload: payload);
      _logger.info('Local notification shown: $title');
    } catch (e) {
      _logger.warning('Error showing local notification: $e');
    }
  }

  /// Cancel a specific notification.
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancel all notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

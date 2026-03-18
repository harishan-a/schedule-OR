import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import 'notification_manager.dart';

/// Service for scheduling and sending reminders for upcoming surgeries
/// This is a client-side implementation that should be run in a background task
/// or service if possible, though Firebase Cloud Functions would be preferred for production
class ReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationManager _notificationManager = NotificationManager();
  final _logger = Logger('ReminderService');

  Timer? _oneHourReminderTimer;
  Timer? _twentyFourHourReminderTimer;

  /// Starts the reminder service with periodic checks
  void startReminderService() {
    _logger.info('Starting reminder service');

    // Check if reminders are already running
    if (_oneHourReminderTimer != null || _twentyFourHourReminderTimer != null) {
      _logger.info('Reminder service is already running');
      return;
    }

    // Run an initial check immediately
    _logger.info('Running initial reminder check');
    _checkAndSendOneHourReminders();
    _checkAndSendTwentyFourHourReminders();

    // Check for upcoming surgeries every 15 minutes
    _oneHourReminderTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) {
        _logger.info('Checking for 1-hour reminders');
        _checkAndSendOneHourReminders();
      },
    );

    // Check for upcoming surgeries scheduled for tomorrow
    _twentyFourHourReminderTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) {
        _logger.info('Checking for 24-hour reminders');
        _checkAndSendTwentyFourHourReminders();
      },
    );

    _logger.info('Reminder service started successfully');
  }

  /// Stops the reminder service
  void stopReminderService() {
    _logger.info('Stopping reminder service');
    _oneHourReminderTimer?.cancel();
    _twentyFourHourReminderTimer?.cancel();
    _oneHourReminderTimer = null;
    _twentyFourHourReminderTimer = null;
  }

  /// Checks for surgeries in the next hour and sends reminders
  Future<void> _checkAndSendOneHourReminders() async {
    try {
      final now = DateTime.now();
      final oneHourFromNow = now.add(const Duration(hours: 1));
      final twoHoursFromNow = now.add(const Duration(hours: 2));

      _logger.info(
          'Checking for surgeries between ${oneHourFromNow.toIso8601String()} and ${twoHoursFromNow.toIso8601String()}');

      // Query surgeries happening in the next 1-2 hours
      final snapshot = await _firestore
          .collection('surgeries')
          .where('status', isEqualTo: 'Scheduled')
          .where('startTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(oneHourFromNow))
          .where('startTime', isLessThan: Timestamp.fromDate(twoHoursFromNow))
          .get();

      _logger.info(
          'Found ${snapshot.docs.length} surgeries approaching in the next hour');

      // Send notifications for each upcoming surgery
      for (final doc in snapshot.docs) {
        try {
          _logger.info('Sending 1-hour reminder for surgery: ${doc.id}');
          await _notificationManager.sendApproachingNotificationById(
            doc.id,
            hoursBeforeSurgery: 1,
          );
          _logger
              .info('Successfully sent 1-hour reminder for surgery: ${doc.id}');
        } catch (e) {
          _logger.severe(
              'Error sending 1-hour reminder for specific surgery ${doc.id}: $e');
          // Continue with next surgery even if one fails
        }
      }
    } catch (e) {
      _logger.severe('Error checking for one-hour reminders: $e');
    }
  }

  /// Checks for surgeries in the next 24 hours and sends reminders
  Future<void> _checkAndSendTwentyFourHourReminders() async {
    try {
      final now = DateTime.now();
      final twentyFourHoursFromNow = now.add(const Duration(hours: 24));
      final twentyFiveHoursFromNow = now.add(const Duration(hours: 25));

      _logger.info(
          'Checking for surgeries between ${twentyFourHoursFromNow.toIso8601String()} and ${twentyFiveHoursFromNow.toIso8601String()}');

      // Query surgeries happening in 24-25 hours
      final snapshot = await _firestore
          .collection('surgeries')
          .where('status', isEqualTo: 'Scheduled')
          .where('startTime',
              isGreaterThanOrEqualTo:
                  Timestamp.fromDate(twentyFourHoursFromNow))
          .where('startTime',
              isLessThan: Timestamp.fromDate(twentyFiveHoursFromNow))
          .get();

      _logger.info(
          'Found ${snapshot.docs.length} surgeries approaching in 24 hours');

      // Send notifications for each upcoming surgery
      for (final doc in snapshot.docs) {
        try {
          _logger.info('Sending 24-hour reminder for surgery: ${doc.id}');
          await _notificationManager.sendApproachingNotificationById(
            doc.id,
            hoursBeforeSurgery: 24,
          );
          _logger.info(
              'Successfully sent 24-hour reminder for surgery: ${doc.id}');
        } catch (e) {
          _logger.severe(
              'Error sending 24-hour reminder for specific surgery ${doc.id}: $e');
          // Continue with next surgery even if one fails
        }
      }
    } catch (e) {
      _logger.severe('Error checking for 24-hour reminders: $e');
    }
  }

  /// Manually initiates reminder checks (for testing or one-time checks)
  Future<void> manuallyCheckReminders() async {
    _logger.info('Manually checking reminders');
    await _checkAndSendOneHourReminders();
    await _checkAndSendTwentyFourHourReminders();
    _logger.info('Manual reminder check completed');
  }
}

import 'dart:async';
import 'package:logging/logging.dart';

/// Manages periodic checking and scheduling of surgery reminders.
/// Extracted from ReminderService.
///
/// This is a skeleton that will be fully implemented in Wave 3.
class ReminderScheduler {
  final _logger = Logger('ReminderScheduler');
  Timer? _reminderTimer;

  /// Start the periodic reminder checking service
  void startReminderService({Duration interval = const Duration(minutes: 15)}) {
    _logger.info(
        'Starting reminder service with ${interval.inMinutes}min interval');
    _reminderTimer?.cancel();
    _reminderTimer = Timer.periodic(interval, (_) => _checkReminders());
  }

  /// Stop the reminder service
  void stopReminderService() {
    _logger.info('Stopping reminder service');
    _reminderTimer?.cancel();
    _reminderTimer = null;
  }

  /// Manually trigger a reminder check
  Future<void> manuallyCheckReminders() async {
    _logger.info('Manual reminder check triggered');
    await _checkReminders();
  }

  Future<void> _checkReminders() async {
    _logger.fine('Checking for upcoming surgery reminders');
    // Will be fully implemented in Wave 3
  }

  /// Clean up resources
  void dispose() {
    _reminderTimer?.cancel();
    _reminderTimer = null;
  }
}

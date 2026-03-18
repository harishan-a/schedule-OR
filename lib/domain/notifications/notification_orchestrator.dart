import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';

/// Orchestrates notification delivery across multiple channels.
/// Determines what notifications to send and to whom based on surgery events.
/// Delegates actual sending to specialized services.
class NotificationOrchestrator {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final _logger = Logger('NotificationOrchestrator');

  NotificationOrchestrator({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Send notifications for a newly scheduled surgery.
  Future<void> notifySurgeryScheduled({
    required String surgeryId,
    required List<String> personnelIds,
  }) async {
    _logger.info(
        'Sending scheduled notifications for surgery $surgeryId to ${personnelIds.length} personnel');

    try {
      for (final userId in personnelIds) {
        await _createInAppNotification(
          recipientId: userId,
          title: 'New Surgery Scheduled',
          message: 'You have been assigned to a new surgery.',
          type: 'surgeryScheduled',
          surgeryId: surgeryId,
        );
      }
    } catch (e) {
      _logger.warning('Error sending scheduled notifications: $e');
    }
  }

  /// Send notifications when surgery details are updated.
  Future<void> notifySurgeryUpdated({
    required String surgeryId,
    required Map<String, dynamic> oldData,
    required Map<String, dynamic> newData,
  }) async {
    _logger.info('Sending update notifications for surgery $surgeryId');

    try {
      final personnelIds = _extractPersonnelIds(newData);
      final changeMessage = newData['changeMessage'] as String? ??
          'Surgery details have been updated.';

      for (final userId in personnelIds) {
        await _createInAppNotification(
          recipientId: userId,
          title: 'Surgery Updated',
          message: changeMessage,
          type: 'surgeryUpdated',
          surgeryId: surgeryId,
        );
      }
    } catch (e) {
      _logger.warning('Error sending update notifications: $e');
    }
  }

  /// Send notifications when surgery status changes.
  Future<void> notifyStatusChanged({
    required String surgeryId,
    required String oldStatus,
    required String newStatus,
  }) async {
    _logger
        .info('Sending status change notifications: $oldStatus -> $newStatus');

    try {
      // Get surgery data to find personnel
      final surgeryDoc =
          await _firestore.collection('surgeries').doc(surgeryId).get();
      if (!surgeryDoc.exists) return;

      final data = surgeryDoc.data() as Map<String, dynamic>;
      final personnelIds = _extractPersonnelIds(data);

      for (final userId in personnelIds) {
        await _createInAppNotification(
          recipientId: userId,
          title: 'Surgery Status Changed',
          message: 'Surgery status changed from "$oldStatus" to "$newStatus".',
          type: 'surgeryStatusChanged',
          surgeryId: surgeryId,
        );
      }
    } catch (e) {
      _logger.warning('Error sending status change notifications: $e');
    }
  }

  /// Send approaching surgery reminders.
  Future<void> notifySurgeryApproaching({
    required String surgeryId,
    required int hoursBeforeSurgery,
  }) async {
    _logger.info(
        'Sending approaching notification for surgery $surgeryId ($hoursBeforeSurgery hours)');

    try {
      final surgeryDoc =
          await _firestore.collection('surgeries').doc(surgeryId).get();
      if (!surgeryDoc.exists) return;

      final data = surgeryDoc.data() as Map<String, dynamic>;
      final personnelIds = _extractPersonnelIds(data);
      final surgeryType = data['surgeryType'] as String? ?? 'Surgery';

      for (final userId in personnelIds) {
        await _createInAppNotification(
          recipientId: userId,
          title: 'Upcoming Surgery',
          message: '$surgeryType is starting in $hoursBeforeSurgery hour(s).',
          type: 'surgeryApproaching',
          surgeryId: surgeryId,
        );
      }
    } catch (e) {
      _logger.warning('Error sending approaching notifications: $e');
    }
  }

  /// Create an in-app notification in Firestore.
  Future<void> _createInAppNotification({
    required String recipientId,
    required String title,
    required String message,
    required String type,
    String? surgeryId,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'recipientId': recipientId,
        'title': title,
        'message': message,
        'type': type,
        if (surgeryId != null) 'surgeryId': surgeryId,
        'senderId': _auth.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      _logger.warning('Error creating notification: $e');
    }
  }

  /// Extract personnel IDs from surgery data.
  List<String> _extractPersonnelIds(Map<String, dynamic> data) {
    final ids = <String>[];

    if (data['doctorId'] is String && (data['doctorId'] as String).isNotEmpty) {
      ids.add(data['doctorId'] as String);
    }

    // Note: nurses and technologists are stored by name, not ID.
    // For now, we try to match them. In a full implementation,
    // we'd look up user IDs by name from the users collection.

    return ids;
  }
}

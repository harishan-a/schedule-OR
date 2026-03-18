// =============================================================================
// Schedule Provider
// =============================================================================
// A ChangeNotifier provider that manages surgery scheduling state and operations:
// - CRUD operations for surgeries in Firestore
// - Input validation for surgery data
// - Error handling for database operations
//
// Firebase Integration:
// - Collection: 'surgeries'
// - Operations: create, read, update, delete
//
// Note: All methods include error handling and input validation to ensure
// data integrity before any Firestore operations are performed.
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/surgery.dart';
import 'package:firebase_orscheduler/services/notification_manager.dart';
import 'package:intl/intl.dart';

/// Manages the state and operations for surgery scheduling
///
/// Provides methods to:
/// - Add new surgeries
/// - Update existing surgeries
/// - Update surgery status
/// - Delete surgeries
///
/// Implements error handling and input validation for all operations
class SurgeryProvider extends ChangeNotifier {
  /// Firebase Firestore instance for database operations
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Notification Manager for sending notifications
  final NotificationManager _notificationManager = NotificationManager();

  /// Adds a new surgery to the database and sends notifications
  ///
  /// Parameters:
  /// - data: Map containing surgery details (surgeryType, startTime, etc.)
  ///
  /// Returns the ID of the newly created surgery
  /// Throws an error if validation fails or create operation fails
  Future<String> addSurgery(Map<String, dynamic> data) async {
    // Validate required fields
    if (!data.containsKey('surgeryType') || !data.containsKey('startTime')) {
      throw ArgumentError(
          'Surgery data must contain surgeryType and startTime');
    }

    // Add timestamps
    data['created'] = FieldValue.serverTimestamp();
    data['lastUpdated'] = FieldValue.serverTimestamp();

    try {
      // Add the surgery document to Firestore
      final docRef = await _firestore.collection('surgeries').add(data);
      final surgeryId = docRef.id;
      debugPrint('Added surgery with ID: $surgeryId');

      // Extract personnel IDs from data to send notifications
      try {
        final List<String> personnelIds = [];

        // Add doctor if present
        if (data.containsKey('doctor') && data['doctor'] != null) {
          personnelIds.add(data['doctor']);
        }

        // Add nurses if present
        if (data.containsKey('nurses') && data['nurses'] is List) {
          final nurses = List<String>.from(data['nurses'] as List);
          personnelIds.addAll(nurses);
        }

        // Add technologists if present
        if (data.containsKey('technologists') &&
            data['technologists'] is List) {
          final technologists =
              List<String>.from(data['technologists'] as List);
          personnelIds.addAll(technologists);
        }

        // Send notification to each personnel
        for (final userId in personnelIds) {
          await _notificationManager.sendScheduledNotificationByUserId(
            surgeryId: surgeryId,
            userId: userId,
          );
        }

        // If no personnel were assigned, we should still log this
        if (personnelIds.isEmpty) {
          debugPrint(
              'No personnel assigned to surgery $surgeryId, no notifications sent');
        } else {
          debugPrint(
              'Sent notifications to ${personnelIds.length} personnel for surgery $surgeryId');
        }
      } catch (e) {
        // Log error but don't rethrow - don't fail surgery creation due to notification failure
        debugPrint('Error sending scheduled notifications: $e');
      }

      return surgeryId;
    } catch (e) {
      debugPrint('Error adding surgery: $e');
      rethrow;
    }
  }

  /// Updates the status of a surgery
  ///
  /// Parameters:
  /// - surgeryId: The ID of the surgery to update
  /// - newStatus: The new status value
  ///
  /// Returns a Future that completes when the update is done
  /// Throws an error if the operation fails
  Future<void> updateSurgeryStatus(String surgeryId, String newStatus) async {
    try {
      // Get the surgery document from Firestore
      final surgeryDoc =
          await _firestore.collection('surgeries').doc(surgeryId).get();
      if (!surgeryDoc.exists) {
        throw Exception('Surgery not found');
      }

      final surgeryData = surgeryDoc.data() as Map<String, dynamic>;
      final oldStatus = surgeryData['status'] as String;

      // Log the complete surgery data for debugging
      debugPrint('Surgery data retrieved: $surgeryData');
      debugPrint(
          'Personnel check: surgeon=${surgeryData['surgeon']}, nurses=${surgeryData['nurses']}, technologists=${surgeryData['technologists']}');

      if (oldStatus == newStatus) {
        debugPrint('Status unchanged, skipping update');
        return; // No change needed
      }

      // Update status in Firestore
      await _firestore.collection('surgeries').doc(surgeryId).update({
        'status': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Explicitly trigger status change notification
      try {
        debugPrint(
            'Triggering status change notification: $oldStatus → $newStatus');
        await _notificationManager.sendStatusChangeNotificationById(
            surgeryId, oldStatus, newStatus);
      } catch (e) {
        debugPrint('Error sending status change notification: $e');
        // Don't rethrow as we still want to return success for the status update
      }
    } catch (e) {
      debugPrint('Error updating surgery status: $e');
      rethrow;
    }
  }

  /// Updates an existing surgery in the database
  ///
  /// Parameters:
  /// - surgery: The surgery with updated values
  ///
  /// Throws an error if validation fails or update operation fails
  Future<void> updateSurgery(Surgery surgery) async {
    // Basic validation
    if (surgery.id.isEmpty) {
      throw ArgumentError('Surgery ID cannot be empty');
    }
    if (surgery.patientName.isEmpty) {
      throw ArgumentError('Patient name cannot be empty');
    }
    if (surgery.surgeryType.isEmpty) {
      throw ArgumentError('Surgery type cannot be empty');
    }

    try {
      // Get surgery reference
      final surgeryRef = _firestore.collection('surgeries').doc(surgery.id);

      // Get current surgery data for comparison
      final oldSurgeryDoc = await surgeryRef.get();
      if (!oldSurgeryDoc.exists) {
        throw Exception('Surgery not found');
      }
      final oldData = oldSurgeryDoc.data() as Map<String, dynamic>;

      // Update surgery data
      await surgeryRef.update({
        'patientName': surgery.patientName,
        'surgeryType': surgery.surgeryType,
        'dateTime': Timestamp.fromDate(surgery.dateTime),
        'startTime': Timestamp.fromDate(surgery.startTime),
        'endTime': Timestamp.fromDate(surgery.endTime),
        'room': surgery.room,
        'doctorId': surgery.doctorId,
        'duration': surgery.duration,
        'type': surgery.type,
        'status': surgery.status,
        'surgeon': surgery.surgeon,
        'nurses': surgery.nurses,
        'technologists': surgery.technologists,
        'notes': surgery.notes,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Prepare new data for notification
      final newData = {
        'surgeryType': surgery.surgeryType,
        'room': surgery.room,
        'startTime': Timestamp.fromDate(surgery.startTime),
        'endTime': Timestamp.fromDate(surgery.endTime),
        'status': surgery.status,
        'surgeon': surgery.surgeon,
        'nurses': surgery.nurses,
        'technologists': surgery.technologists,
        'notes': surgery.notes,
      };

      // Check if there's a detailed change message
      final bool hasDetailedChanges = newData.containsKey('changes') &&
          newData.containsKey('changeMessage');

      // Determine if notification should be sent
      final bool shouldNotify = hasDetailedChanges ||
          oldData['startTime'] != newData['startTime'] ||
          oldData['endTime'] != newData['endTime'] ||
          oldData['room'] != newData['room'] ||
          oldData['surgeon'] != newData['surgeon'] ||
          !_areListsEqual(oldData['nurses'], newData['nurses']) ||
          !_areListsEqual(oldData['technologists'], newData['technologists']) ||
          oldData['status'] != newData['status'];

      // Check if status changed
      final bool statusChanged = oldData['status'] != surgery.status;
      final String oldStatus = oldData['status'] as String? ?? 'Unknown';

      // Send a single combined notification for all changes
      if (shouldNotify) {
        try {
          // If we have a detailed change message already, use it
          if (hasDetailedChanges) {
            debugPrint(
                'Triggering detailed update notification for surgery ${surgery.id}');

            // If status also changed, add it to the changes data
            if (statusChanged &&
                newData['changes'] != null &&
                !(newData['changes'] as Map<String, dynamic>)
                    .containsKey('status')) {
              (newData['changes'] as Map<String, dynamic>)['status'] = {
                'oldValue': oldStatus,
                'newValue': surgery.status,
                'fieldName': 'Status'
              };

              // Update the change message to include status
              String currentMessage = newData['changeMessage'] as String;
              String statusAddition =
                  'Status from $oldStatus to ${surgery.status}';

              // Check if the message already contains other changes
              if (currentMessage.contains('updated:')) {
                // Just add the status as another bullet point
                newData['changeMessage'] = '$currentMessage, $statusAddition';
              } else {
                // Convert to multi-change format
                newData['changeMessage'] =
                    'Surgery updated: $statusAddition, $currentMessage';
              }
            }

            await _notificationManager.sendUpdateNotificationById(
                surgery.id, oldData, newData);
          }
          // If only status changed, send a simple status notification with enhanced format
          else if (statusChanged && !hasOtherChanges(oldData, newData)) {
            debugPrint(
                'Triggering status-only change notification: $oldStatus → ${surgery.status}');

            // Create a simplified notification data with just the status change
            final notificationData = Map<String, dynamic>.from(newData);
            notificationData['changeMessage'] =
                'Surgery status updated from "$oldStatus" to "${surgery.status}".';
            notificationData['changes'] = {
              'status': {
                'oldValue': oldStatus,
                'newValue': surgery.status,
                'fieldName': 'Status'
              }
            };

            await _notificationManager.sendUpdateNotificationById(
                surgery.id, oldData, notificationData);
          }
          // Multiple fields changed including possibly status
          else {
            debugPrint(
                'Triggering combined update notification for surgery ${surgery.id}');

            // Build a structured change message
            final Map<String, dynamic> changes = {};
            final StringBuffer message = StringBuffer('Surgery updated:');

            // Add status change if present
            if (statusChanged) {
              changes['status'] = {
                'oldValue': oldStatus,
                'newValue': surgery.status,
                'fieldName': 'Status'
              };
              message.write('\n- Status: $oldStatus → ${surgery.status}');
            }

            // Check for time changes
            if (oldData['startTime'] != newData['startTime']) {
              final oldTime = (oldData['startTime'] as Timestamp).toDate();
              final newTime = (newData['startTime'] as Timestamp).toDate();
              final formatter = DateFormat('MMM d, y h:mm a');

              changes['startTime'] = {
                'oldValue': formatter.format(oldTime),
                'newValue': formatter.format(newTime),
                'fieldName': 'Start Time'
              };
              message.write(
                  '\n- Start Time: ${formatter.format(oldTime)} → ${formatter.format(newTime)}');
            }

            // Check for room changes
            if (!_areListsEqual(oldData['room'], newData['room'])) {
              final oldRoom = oldData['room'] is List
                  ? (oldData['room'] as List).join(', ')
                  : oldData['room']?.toString() ?? 'None';

              final newRoom = newData['room'] is List
                  ? (newData['room'] as List).join(', ')
                  : newData['room']?.toString() ?? 'None';

              changes['room'] = {
                'oldValue': oldRoom,
                'newValue': newRoom,
                'fieldName': 'Room'
              };
              message.write('\n- Room: $oldRoom → $newRoom');
            }

            // Check for staff changes
            if (oldData['surgeon'] != newData['surgeon']) {
              final oldSurgeon = oldData['surgeon']?.toString() ?? 'None';
              final newSurgeon = newData['surgeon']?.toString() ?? 'None';

              changes['surgeon'] = {
                'oldValue': oldSurgeon,
                'newValue': newSurgeon,
                'fieldName': 'Surgeon'
              };
              message.write('\n- Surgeon: $oldSurgeon → $newSurgeon');
            }

            // Add nurses changes
            if (!_areListsEqual(oldData['nurses'], newData['nurses'])) {
              final oldNurses = (oldData['nurses'] is List)
                  ? (oldData['nurses'] as List).join(', ')
                  : 'None';

              final newNurses = (newData['nurses'] is List)
                  ? (newData['nurses'] as List).join(', ')
                  : 'None';

              changes['nurses'] = {
                'oldValue': oldNurses,
                'newValue': newNurses,
                'fieldName': 'Nurses'
              };
              message.write('\n- Nurses: $oldNurses → $newNurses');
            }

            // Add technologists changes
            if (!_areListsEqual(
                oldData['technologists'], newData['technologists'])) {
              final oldTechs = (oldData['technologists'] is List)
                  ? (oldData['technologists'] as List).join(', ')
                  : 'None';

              final newTechs = (newData['technologists'] is List)
                  ? (newData['technologists'] as List).join(', ')
                  : 'None';

              changes['technologists'] = {
                'oldValue': oldTechs,
                'newValue': newTechs,
                'fieldName': 'Technologists'
              };
              message.write('\n- Technologists: $oldTechs → $newTechs');
            }

            // Create notification data with all changes
            final combinedData = Map<String, dynamic>.from(newData);
            combinedData['changes'] = changes;
            combinedData['changeMessage'] = message.toString();

            await _notificationManager.sendUpdateNotificationById(
                surgery.id, oldData, combinedData);
          }
        } catch (e) {
          debugPrint('Error sending combined update notification: $e');
          // Don't rethrow as we still want to return success for the update
        }
      }
    } catch (e) {
      debugPrint('Error updating surgery: $e');
      rethrow;
    }
  }

  /// Helper method to check if fields other than status have changed
  bool hasOtherChanges(
      Map<String, dynamic> oldData, Map<String, dynamic> newData) {
    return oldData['startTime'] != newData['startTime'] ||
        oldData['endTime'] != newData['endTime'] ||
        oldData['room'] != newData['room'] ||
        oldData['surgeon'] != newData['surgeon'] ||
        !_areListsEqual(oldData['nurses'], newData['nurses']) ||
        !_areListsEqual(oldData['technologists'], newData['technologists']);
  }

  /// Helper to compare lists
  bool _areListsEqual(dynamic list1, dynamic list2) {
    // Handle null cases
    if (list1 == null && list2 == null) return true;
    if (list1 == null || list2 == null) return false;

    // Convert to lists if not already
    final List<dynamic> l1 = list1 is List ? list1 : [];
    final List<dynamic> l2 = list2 is List ? list2 : [];

    if (l1.length != l2.length) return false;

    // Create sorted copies of the lists for comparison
    final sortedList1 = List<dynamic>.from(l1)
      ..sort((a, b) => a.toString().compareTo(b.toString()));
    final sortedList2 = List<dynamic>.from(l2)
      ..sort((a, b) => a.toString().compareTo(b.toString()));

    for (int i = 0; i < sortedList1.length; i++) {
      if (sortedList1[i].toString() != sortedList2[i].toString()) return false;
    }

    return true;
  }

  /// Sends reminder notifications for upcoming surgeries
  ///
  /// Parameters:
  /// - surgeryId: The unique identifier of the surgery
  /// - hoursBeforeSurgery: Hours before the surgery to send notification
  ///
  /// Throws an error if operation fails
  Future<void> sendApproachingNotification(
      String surgeryId, int hoursBeforeSurgery) async {
    try {
      await _notificationManager.sendApproachingNotificationById(surgeryId,
          hoursBeforeSurgery: hoursBeforeSurgery);
    } catch (e) {
      debugPrint('Error sending approaching notification: $e');
      rethrow;
    }
  }

  /// Deletes a surgery from the database
  ///
  /// Parameters:
  /// - surgeryId: The unique identifier of the surgery to delete
  ///
  /// Validates:
  /// - Surgery ID is not empty
  ///
  /// Throws an error if validation fails or delete operation fails
  Future<void> deleteSurgery(String surgeryId) async {
    if (surgeryId.isEmpty) {
      throw ArgumentError('Surgery ID cannot be empty');
    }

    try {
      await _firestore.collection('surgeries').doc(surgeryId).delete();
    } catch (e) {
      debugPrint('Error deleting surgery: $e');
      rethrow;
    }
  }

  /// Updates a surgery with raw data
  ///
  /// Parameters:
  /// - surgeryId: The ID of the surgery to update
  /// - data: Map containing surgery details to update
  ///
  /// Returns a Future that completes when the update is done
  /// Throws an error if validation fails or update operation fails
  Future<void> updateSurgeryData(
      String surgeryId, Map<String, dynamic> data) async {
    // Basic validation
    if (surgeryId.isEmpty) {
      throw ArgumentError('Surgery ID cannot be empty');
    }

    try {
      // Get surgery reference
      final surgeryRef = _firestore.collection('surgeries').doc(surgeryId);

      // Get current surgery data for comparison
      final oldSurgeryDoc = await surgeryRef.get();
      if (!oldSurgeryDoc.exists) {
        throw Exception('Surgery not found');
      }
      final oldData = oldSurgeryDoc.data() as Map<String, dynamic>;

      // Add last updated timestamp if not already included
      if (!data.containsKey('lastUpdated')) {
        data['lastUpdated'] = FieldValue.serverTimestamp();
      }

      // Update surgery data
      await surgeryRef.update(data);

      // Check if there's a detailed change message for notifications
      final bool hasDetailedChanges =
          data.containsKey('changes') && data.containsKey('changeMessage');

      // Send notification if there are changes to notify about
      if (hasDetailedChanges) {
        try {
          debugPrint('Triggering update notification for surgery $surgeryId');
          await _notificationManager.sendUpdateNotificationById(
              surgeryId, oldData, data);
        } catch (e) {
          debugPrint('Error sending update notification: $e');
          // Don't rethrow as we still want to return success for the update
        }
      }
    } catch (e) {
      debugPrint('Error updating surgery data: $e');
      rethrow;
    }
  }
}

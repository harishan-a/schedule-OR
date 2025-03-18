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
      throw ArgumentError('Surgery data must contain surgeryType and startTime');
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
        if (data.containsKey('technologists') && data['technologists'] is List) {
          final technologists = List<String>.from(data['technologists'] as List);
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
          debugPrint('No personnel assigned to surgery $surgeryId, no notifications sent');
        } else {
          debugPrint('Sent notifications to ${personnelIds.length} personnel for surgery $surgeryId');
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
      final surgeryDoc = await _firestore.collection('surgeries').doc(surgeryId).get();
      if (!surgeryDoc.exists) {
        throw Exception('Surgery not found');
      }
      
      final surgeryData = surgeryDoc.data() as Map<String, dynamic>;
      final oldStatus = surgeryData['status'] as String;
      
      // Log the complete surgery data for debugging
      debugPrint('Surgery data retrieved: $surgeryData');
      debugPrint('Personnel check: surgeon=${surgeryData['surgeon']}, nurses=${surgeryData['nurses']}, technologists=${surgeryData['technologists']}');
      
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
        debugPrint('Triggering status change notification: $oldStatus → $newStatus');
        await _notificationManager.sendStatusChangeNotificationById(
          surgeryId,
          oldStatus,
          newStatus
        );
      } catch (e) {
        debugPrint('Error sending status change notification: $e');
        // Don't rethrow as we still want to return success for the status update
      }
    } catch (e) {
      debugPrint('Error updating surgery status: $e');
      rethrow;
    }
  }

  /// Updates all fields of an existing surgery and sends notifications
  /// 
  /// Parameters:
  /// - surgery: The Surgery object containing updated fields
  /// 
  /// Validates:
  /// - Surgery ID exists
  /// - End time is after start time
  /// - Required fields are not empty
  /// 
  /// Throws an error if validation fails or update operation fails
  Future<void> updateSurgery(Surgery surgery) async {
    if (surgery.id.isEmpty) {
      throw ArgumentError('Surgery ID cannot be empty');
    }
    if (surgery.endTime.isBefore(surgery.startTime)) {
      throw ArgumentError('End time cannot be before start time');
    }
    if (surgery.surgeon.isEmpty) {
      throw ArgumentError('Surgeon cannot be empty');
    }
    if (surgery.room.isEmpty) {
      throw ArgumentError('Operating room cannot be empty');
    }

    try {
      // Get the current data to compare for changes
      final docSnapshot = await _firestore.collection('surgeries').doc(surgery.id).get();
      if (!docSnapshot.exists) {
        throw Exception('Surgery not found');
      }
      
      final oldData = docSnapshot.data() ?? {};
      
      // Update the surgery
      await _firestore.collection('surgeries').doc(surgery.id).update({
        'surgeryType': surgery.surgeryType,
        'room': surgery.room,
        'startTime': surgery.startTime,
        'endTime': surgery.endTime,
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
      
      // Send update notification if time, room, or status changed
      final timeChanged = (oldData['startTime'] as Timestamp?)?.toDate().toString() != 
                           surgery.startTime.toString();
      final roomChanged = oldData['room'] != surgery.room;
      final statusChanged = oldData['status'] != surgery.status;
      
      // Explicitly trigger update notification if something significant changed
      if (timeChanged || roomChanged || statusChanged) {
        try {
          debugPrint('Triggering update notification for surgery ${surgery.id}');
          await _notificationManager.sendUpdateNotificationById(
            surgery.id,
            oldData,
            newData
          );
        } catch (e) {
          debugPrint('Error sending update notification: $e');
          // Don't rethrow as we still want to return success for the update
        }
      }
      
      // If status specifically changed, also send a status change notification
      if (statusChanged) {
        try {
          final oldStatus = oldData['status'] as String? ?? 'Unknown';
          debugPrint('Triggering status change notification: $oldStatus → ${surgery.status}');
          await _notificationManager.sendStatusChangeNotificationById(
            surgery.id,
            oldStatus,
            surgery.status
          );
        } catch (e) {
          debugPrint('Error sending status change notification: $e');
        }
      }
    } catch (e) {
      debugPrint('Error updating surgery: $e');
      rethrow;
    }
  }

  /// Sends reminder notifications for upcoming surgeries
  /// 
  /// Parameters:
  /// - surgeryId: The unique identifier of the surgery
  /// - hoursBeforeSurgery: Hours before the surgery to send notification
  /// 
  /// Throws an error if operation fails
  Future<void> sendApproachingNotification(String surgeryId, int hoursBeforeSurgery) async {
    try {
      await _notificationManager.sendApproachingNotificationById(
        surgeryId, 
        hoursBeforeSurgery: hoursBeforeSurgery
      );
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
}

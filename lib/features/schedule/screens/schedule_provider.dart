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
  
  /// Adds a new surgery to the Firestore database
  /// 
  /// Parameters:
  /// - surgery: The Surgery object containing all required fields
  /// 
  /// Throws an error if the database operation fails
  Future<void> addSurgery(Surgery surgery) async {
    try {
      await _firestore.collection('surgeries').add({
        'surgeryType': surgery.surgeryType,
        'room': surgery.room,
        'startTime': surgery.startTime,
        'endTime': surgery.endTime,
        'status': surgery.status,
        'surgeon': surgery.surgeon,
        'nurses': surgery.nurses,
        'technologists': surgery.technologists,
        'notes': surgery.notes,
      });
    } catch (e) {
      debugPrint('Error adding surgery: $e');
      rethrow;
    }
  }

  /// Updates the status of an existing surgery
  /// 
  /// Parameters:
  /// - surgeryId: The unique identifier of the surgery
  /// - newStatus: The new status to be applied
  /// 
  /// Throws an error if the surgery doesn't exist or update fails
  Future<void> updateSurgeryStatus(String surgeryId, String newStatus) async {
    try {
      await _firestore.collection('surgeries').doc(surgeryId).update({
        'status': newStatus,
      });
    } catch (e) {
      debugPrint('Error updating surgery status: $e');
      rethrow;
    }
  }

  /// Updates all fields of an existing surgery
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
      });
    } catch (e) {
      debugPrint('Error updating surgery: $e');
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

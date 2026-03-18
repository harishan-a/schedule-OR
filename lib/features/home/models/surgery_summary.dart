// =============================================================================
// Surgery Summary Model
// =============================================================================
// A data model representing a surgery in the system, including:
// - Basic surgery information (type, timing, status)
// - Location and personnel details
// - Support for Firestore serialization
//
// This model is used throughout the app for:
// - Displaying surgery cards in the dashboard
// - Managing surgery schedules
// - Tracking surgery status and personnel
//
// Note: Future improvements could include:
// - copyWith method for immutable updates
// - toString override for debugging
// - equality operator overrides
// - JSON serialization methods
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a surgery in the system with all its associated details
class SurgerySummary {
  /// Unique identifier for the surgery, matches Firestore document ID
  final String id;

  /// Type or name of the surgical procedure
  final String surgeryType;

  /// Scheduled start time of the surgery
  final DateTime startTime;

  /// Expected or actual end time of the surgery
  final DateTime endTime;

  /// Current status of the surgery (e.g., 'Scheduled', 'In Progress', 'Completed')
  final String status;

  /// Operating room or location assigned for the surgery
  final String room;

  /// Name of the primary surgeon
  final String surgeon;

  /// List of assigned nursing staff
  final List<String> nurses;

  /// List of assigned technical staff
  final List<String> technologists;

  /// Additional notes or comments about the surgery
  final String notes;

  /// Creates a new surgery summary instance
  ///
  /// All parameters are required to ensure data consistency.
  /// Times should be in the local timezone of the facility.
  const SurgerySummary({
    required this.id,
    required this.surgeryType,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.room,
    required this.surgeon,
    required this.nurses,
    required this.technologists,
    required this.notes,
  });

  /// Creates a SurgerySummary instance from a Firestore document
  ///
  /// Handles null values and type conversion from Firestore Timestamps.
  /// Provides default values for missing fields to prevent runtime errors.
  factory SurgerySummary.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SurgerySummary(
      id: doc.id,
      surgeryType: data['surgeryType'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      status: data['status'] ?? 'Scheduled',
      room: data['room'] ?? '',
      surgeon: data['surgeon'] ?? '',
      nurses: List<String>.from(data['nurses'] ?? []),
      technologists: List<String>.from(data['technologists'] ?? []),
      notes: data['notes'] ?? '',
    );
  }

  // TODO: Consider adding these helper methods in future updates:
  // - copyWith() for immutable updates
  // - toString() for debugging
  // - operator == and hashCode for equality comparison
  // - toJson() for serialization
  // - validate() for data validation
}

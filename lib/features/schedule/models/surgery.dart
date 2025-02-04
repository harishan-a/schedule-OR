// =============================================================================
// Surgery Model
// =============================================================================
// A model class representing a surgical procedure in the OR scheduling system.
// Handles data representation, serialization, and validation for surgeries:
// - Core surgery details (type, patient, timing)
// - Staff assignments (surgeon, nurses, technologists)
// - Room allocation and scheduling
// - Status tracking
//
// Firebase Integration:
// - Serialization to/from Firestore documents
// - Timestamp conversion handling
// - Null-safety implementation
//
// Future Improvements Needed:
// - Add copyWith() method for immutable updates
// - Implement toString() for debugging
// - Add equality operator overrides
// - Consider adding validation methods
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a surgical procedure with all associated details
class Surgery {
  /// Unique identifier for the surgery
  /// Non-null, required for database operations
  final String id;

  /// Name of the patient undergoing surgery
  /// Non-null, required field
  final String patientName;

  /// Type/category of the surgical procedure
  /// Non-null, used for scheduling and resource allocation
  final String surgeryType;

  /// Unique identifier of the assigned doctor
  /// Non-null, used for doctor-specific queries
  final String doctorId;

  /// Name of the primary surgeon
  /// Non-null, required for staff scheduling
  final String surgeon;

  /// Date and time of the surgery (legacy field)
  /// Non-null, consider consolidating with startTime
  final DateTime dateTime;

  /// Scheduled start time of the surgery
  /// Non-null, used for scheduling
  final DateTime startTime;

  /// Expected end time of the surgery
  /// Non-null, calculated from start time + duration if not specified
  final DateTime endTime;

  /// Unique identifier of the assigned operating room
  /// Non-null, used for room allocation
  final String roomId;

  /// Room details (may include multiple values for complex procedures)
  /// Non-null list, may be empty
  final List<String> room;

  /// Expected duration in minutes
  /// Non-null, used for scheduling and end time calculation
  final int duration;

  /// Current status of the surgery (e.g., 'Scheduled', 'In Progress', 'Completed')
  /// Non-null, defaults to 'Scheduled'
  final String status;

  /// Additional categorization of the surgery
  /// Non-null, can be empty
  final String type;

  /// Optional notes about the surgery
  /// Nullable, defaults to empty string
  final String notes;

  /// List of assigned nursing staff
  /// Non-null list, may be empty
  final List<String> nurses;

  /// List of assigned technical staff
  /// Non-null list, may be empty
  final List<String> technologists;

  /// Creates a new Surgery instance with required and optional fields
  /// 
  /// All required fields must be non-null
  /// Lists default to empty if not specified
  /// Notes default to empty string if not specified
  Surgery({
    required this.id,
    required this.patientName,
    required this.surgeryType,
    required this.doctorId,
    required this.surgeon,
    required this.dateTime,
    required this.startTime,
    required this.endTime,
    required this.roomId,
    required this.room,
    required this.duration,
    required this.status,
    required this.type,
    this.notes = '',
    this.nurses = const [],
    this.technologists = const [],
  });

  /// Creates a Surgery instance from a Firestore document
  /// 
  /// Handles:
  /// - Null safety for all fields
  /// - Timestamp conversion to DateTime
  /// - Default values for optional fields
  /// - List type conversion for staff assignments
  factory Surgery.fromFirestore(String id, Map<String, dynamic> data) {
    final startTime = (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();
    final duration = (data['duration'] as num?)?.toInt() ?? 30;
    final endTime = (data['endTime'] as Timestamp?)?.toDate() ?? 
                   startTime.add(Duration(minutes: duration));
    
    return Surgery(
      id: id,
      patientName: data['patientName'] as String? ?? '',
      surgeryType: data['surgeryType'] as String? ?? '',
      doctorId: data['doctorId'] as String? ?? '',
      surgeon: data['surgeon'] as String? ?? '',
      dateTime: (data['dateTime'] as Timestamp?)?.toDate() ?? startTime,
      startTime: startTime,
      endTime: endTime,
      roomId: data['roomId'] as String? ?? '',
      room: data['room'] is List ? List<String>.from(data['room']) : [data['room'] ?? ''],
      duration: duration,
      status: data['status'] as String? ?? 'Scheduled',
      type: data['type'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      nurses: List<String>.from(data['nurses'] ?? []),
      technologists: List<String>.from(data['technologists'] ?? []),
    );
  }

  /// Converts the Surgery instance to a Firestore document
  /// 
  /// Handles:
  /// - DateTime conversion to Timestamp
  /// - List serialization
  /// - Null safety for optional fields
  Map<String, dynamic> toFirestore() {
    return {
      'patientName': patientName,
      'surgeryType': surgeryType,
      'doctorId': doctorId,
      'surgeon': surgeon,
      'dateTime': Timestamp.fromDate(dateTime),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'roomId': roomId,
      'room': room,
      'duration': duration,
      'status': status,
      'type': type,
      'notes': notes,
      'nurses': nurses,
      'technologists': technologists,
    };
  }
}

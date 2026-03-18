// =============================================================================
// Surgery Equipment Requirement Model
// =============================================================================
// A model class representing equipment requirements for a surgical procedure.
// Handles data representation for equipment needed during surgery:
// - Equipment identification and reference
// - Time requirements for setup and usage
// - Required vs optional status
//
// Integration with Surgery Model:
// - Used as part of the equipmentRequirements list in Surgery
// - Provides detailed timing information beyond simple equipment IDs
// - Allows for precise scheduling of equipment preparation and usage
//
// Firebase Integration:
// - Serialization to/from Firestore documents
// - Timestamp conversion handling
// - Null-safety implementation
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

/// Represents a piece of equipment required for a surgery with associated details
class SurgeryEquipmentRequirement {
  // Logger for this class
  static final _logger = Logger('SurgeryEquipmentRequirement');

  /// ID of the equipment from the equipment collection
  /// Non-null, used to reference the specific equipment
  final String equipmentId;

  /// Name of the equipment for display purposes
  /// Non-null, provides user-friendly identification
  final String equipmentName;

  /// Whether this equipment is mandatory for the surgery
  /// Non-null, indicates if surgery can proceed without it
  final bool isRequired;

  /// When the equipment needs to be set up
  /// Non-null, typically before surgery start time
  final DateTime setupStartTime;

  /// When the equipment is no longer needed
  /// Non-null, typically after surgery end time
  final DateTime requiredUntilTime;

  /// Creates a new SurgeryEquipmentRequirement instance
  ///
  /// All fields are required
  /// Validates that:
  /// - Equipment ID and name are not empty
  /// - Setup time is before or equal to required until time
  SurgeryEquipmentRequirement({
    required this.equipmentId,
    required this.equipmentName,
    required this.isRequired,
    required this.setupStartTime,
    required this.requiredUntilTime,
  }) {
    // Use assertions instead of throwing exceptions
    // These will be ignored in release mode but help during development
    assert(equipmentId.isNotEmpty, 'Equipment ID cannot be empty');
    assert(equipmentName.isNotEmpty, 'Equipment name cannot be empty');
    assert(!setupStartTime.isAfter(requiredUntilTime),
        'Setup start time cannot be after required until time');
  }

  /// Creates a SurgeryEquipmentRequirement instance from a Firestore document
  ///
  /// Handles:
  /// - Timestamp conversion to DateTime
  /// - Default values for optional fields
  /// - Validation of required fields
  /// - Auto-correction of inconsistent time values
  factory SurgeryEquipmentRequirement.fromFirestore(Map<String, dynamic> data) {
    try {
      // Extract equipment ID with a safe default
      final equipmentId = data['equipmentId'] as String? ?? '';
      final safeEquipmentId =
          equipmentId.isEmpty ? 'unknown_equipment' : equipmentId;

      // Extract equipment name with a safe default
      final equipmentName = data['equipmentName'] as String? ?? '';
      final safeEquipmentName =
          equipmentName.isEmpty ? 'Unknown Equipment' : equipmentName;

      // Extract and convert timestamps to DateTime safely
      DateTime setupStartTime;
      try {
        setupStartTime =
            (data['setupStartTime'] as Timestamp?)?.toDate() ?? DateTime.now();
      } catch (e) {
        _logger.warning('Invalid setupStartTime, using current time: $e');
        setupStartTime = DateTime.now();
      }

      DateTime requiredUntilTime;
      try {
        requiredUntilTime =
            (data['requiredUntilTime'] as Timestamp?)?.toDate() ??
                setupStartTime.add(const Duration(hours: 1));
      } catch (e) {
        _logger.warning(
            'Invalid requiredUntilTime, using setupStartTime + 1h: $e');
        requiredUntilTime = setupStartTime.add(const Duration(hours: 1));
      }

      // Ensure setup time is before required until time
      if (setupStartTime.isAfter(requiredUntilTime)) {
        _logger.warning(
            'Auto-correcting inconsistent time values for equipment $safeEquipmentId: '
            'setup time ($setupStartTime) is after required until time ($requiredUntilTime)');

        // Fix the issue by setting requiredUntilTime to one hour after setupStartTime
        requiredUntilTime = setupStartTime.add(const Duration(hours: 1));
      }

      // Handle isRequired field safely
      bool isRequired = true;
      if (data.containsKey('isRequired') && data['isRequired'] is bool) {
        isRequired = data['isRequired'] as bool;
      }

      return SurgeryEquipmentRequirement(
        equipmentId: safeEquipmentId,
        equipmentName: safeEquipmentName,
        isRequired: isRequired,
        setupStartTime: setupStartTime,
        requiredUntilTime: requiredUntilTime,
      );
    } catch (e) {
      _logger.severe('Error parsing equipment requirement: $e');
      // Return a safe default rather than throwing
      return SurgeryEquipmentRequirement(
        equipmentId: 'error_equipment',
        equipmentName: 'Error Loading Equipment',
        isRequired: false,
        setupStartTime: DateTime.now(),
        requiredUntilTime: DateTime.now().add(const Duration(hours: 1)),
      );
    }
  }

  /// Converts the SurgeryEquipmentRequirement instance to a Firestore document
  ///
  /// Handles:
  /// - DateTime conversion to Timestamp
  Map<String, dynamic> toFirestore() {
    return {
      'equipmentId': equipmentId,
      'equipmentName': equipmentName,
      'isRequired': isRequired,
      'setupStartTime': Timestamp.fromDate(setupStartTime),
      'requiredUntilTime': Timestamp.fromDate(requiredUntilTime),
    };
  }

  /// Creates a copy of this requirement with modified fields
  SurgeryEquipmentRequirement copyWith({
    String? equipmentId,
    String? equipmentName,
    bool? isRequired,
    DateTime? setupStartTime,
    DateTime? requiredUntilTime,
  }) {
    return SurgeryEquipmentRequirement(
      equipmentId: equipmentId ?? this.equipmentId,
      equipmentName: equipmentName ?? this.equipmentName,
      isRequired: isRequired ?? this.isRequired,
      setupStartTime: setupStartTime ?? this.setupStartTime,
      requiredUntilTime: requiredUntilTime ?? this.requiredUntilTime,
    );
  }

  /// Gets the total time this equipment is needed (in minutes)
  int get totalTimeNeededMinutes {
    return requiredUntilTime.difference(setupStartTime).inMinutes;
  }

  /// Checks if this equipment requirement overlaps with a given time range
  bool overlapsWithTimeRange(DateTime start, DateTime end) {
    return setupStartTime.isBefore(end) && requiredUntilTime.isAfter(start);
  }

  /// Provides a string representation of this requirement for debugging
  @override
  String toString() {
    return 'SurgeryEquipmentRequirement(equipmentId: $equipmentId, '
        'equipmentName: $equipmentName, isRequired: $isRequired, '
        'setupStartTime: $setupStartTime, requiredUntilTime: $requiredUntilTime)';
  }

  /// Compares this requirement with another for equality
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SurgeryEquipmentRequirement &&
        other.equipmentId == equipmentId &&
        other.equipmentName == equipmentName &&
        other.isRequired == isRequired &&
        other.setupStartTime == setupStartTime &&
        other.requiredUntilTime == requiredUntilTime;
  }

  /// Provides a consistent hash code for this requirement
  @override
  int get hashCode {
    return equipmentId.hashCode ^
        equipmentName.hashCode ^
        isRequired.hashCode ^
        setupStartTime.hashCode ^
        requiredUntilTime.hashCode;
  }
}

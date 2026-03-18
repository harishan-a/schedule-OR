// =============================================================================
// Surgery Model
// =============================================================================
// A model class representing a surgical procedure in the OR scheduling system.
// Handles data representation, serialization, and validation for surgeries:
// - Core surgery details (type, patient, timing)
// - Staff assignments (surgeon, nurses, technologists)
// - Room allocation and scheduling
// - Status tracking
// - Prep and cleanup times
// - Equipment requirements and management
// - Custom time segments for procedure phases
//
// Firebase Integration:
// - Serialization to/from Firestore documents
// - Timestamp conversion handling
// - Null-safety implementation
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import '../../surgery/models/surgery_equipment_requirement.dart';

/// Represents a surgical procedure with all associated details
class Surgery {
  // Logger for this class
  static final _logger = Logger('Surgery');

  /// Unique identifier for the surgery
  /// Non-null, required for database operations
  final String id;

  /// Name of the patient undergoing surgery
  /// Non-null, required field
  final String patientName;

  /// Patient ID number for medical record identification
  /// Nullable, optional field
  final String? patientId;

  /// Patient age
  /// Nullable, optional field
  final int? patientAge;

  /// Patient gender
  /// Nullable, optional field
  final String? patientGender;

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
  late DateTime endTime;

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

  /// Time needed before surgery for preparation (in minutes)
  /// Non-null, defaults to 0 if not specified
  final int prepTimeMinutes;

  /// Time needed after surgery for cleanup (in minutes)
  /// Non-null, defaults to 0 if not specified
  final int cleanupTimeMinutes;

  /// List of equipment IDs required for the surgery
  /// Non-null list, may be empty
  final List<String> requiredEquipment;

  /// Detailed equipment requirements with timing information
  /// Non-null list, may be empty
  final List<SurgeryEquipmentRequirement> equipmentRequirements;

  /// Custom time frames for specific surgery phases or activities
  /// Key is the name of the time frame, value contains timing details
  /// E.g., {'anesthesia': {'start': timestamp, 'end': timestamp, 'notes': 'text'}}
  final Map<String, dynamic> customTimeFrames;

  /// Custom time blocks with name and duration
  /// Contains a list of blocks where each block has a name and duration in minutes
  /// E.g., [{'name': 'Device Setup', 'durationMinutes': 15}]
  final List<Map<String, dynamic>> timeBlocks;

  /// Raw Firestore data, used to access fields that haven't been mapped to properties
  final Map<String, dynamic> firestoreData;

  /// A comprehensive surgery model with all required data
  ///
  /// Provides:
  /// - Surgery identification info (id, type, patient, doctor)
  /// - Scheduling info (startTime, endTime, duration)
  /// - Resource allocation (room, staff, equipment)
  /// - Status tracking and notes
  Surgery({
    required this.id,
    required this.patientName,
    this.patientId,
    this.patientAge,
    this.patientGender,
    required this.surgeryType,
    required this.doctorId,
    required this.surgeon,
    required this.dateTime,
    required this.startTime,
    required DateTime endTime,
    required this.roomId,
    required this.room,
    required this.duration,
    this.status = 'Scheduled',
    this.type = '',
    this.notes = '',
    this.nurses = const [],
    this.technologists = const [],
    this.prepTimeMinutes = 0,
    this.cleanupTimeMinutes = 0,
    this.requiredEquipment = const [],
    this.equipmentRequirements = const [],
    this.customTimeFrames = const {},
    this.timeBlocks = const [],
    this.firestoreData = const {},
  }) {
    // Assert validation only works in debug mode
    assert(patientName.isNotEmpty, 'Patient name cannot be empty');
    assert(surgeryType.isNotEmpty, 'Surgery type cannot be empty');
    assert(surgeon.isNotEmpty, 'Surgeon name cannot be empty');
    assert(roomId.isNotEmpty, 'Room ID cannot be empty');
    assert(duration > 0, 'Surgery duration must be positive');
    assert(prepTimeMinutes >= 0, 'Prep time cannot be negative');
    assert(cleanupTimeMinutes >= 0, 'Cleanup time cannot be negative');

    // Validate and auto-correct time relationships
    final calculatedEndTime = startTime.add(Duration(minutes: duration));

    // Check if endTime is before startTime (invalid)
    if (endTime.isBefore(startTime)) {
      _logger.warning(
          'Correcting invalid surgery time: end time before start time');
      this.endTime = calculatedEndTime;
    }
    // Check if endTime is inconsistent with duration (allow 1 minute tolerance)
    else if (calculatedEndTime.difference(endTime).inMinutes.abs() > 1) {
      _logger.warning(
          'Correcting inconsistent surgery time: end time doesn\'t match duration');
      this.endTime = calculatedEndTime;
    } else {
      this.endTime = endTime;
    }
  }

  /// Creates a Surgery instance from a Firestore document
  ///
  /// Handles:
  /// - Null safety for all fields
  /// - Timestamp conversion to DateTime
  /// - Default values for optional fields
  /// - List type conversion for staff assignments
  /// - Backward compatibility with existing data
  factory Surgery.fromFirestore(String id, Map<String, dynamic> data) {
    try {
      // Extract basic time values with defaults
      final startTime =
          (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();
      final duration = (data['duration'] as num?)?.toInt() ?? 30;

      // Handle end time calculation with validation
      DateTime endTime;
      try {
        final rawEndTime = (data['endTime'] as Timestamp?)?.toDate();
        if (rawEndTime == null) {
          // If endTime is missing, calculate from startTime + duration
          endTime = startTime.add(Duration(minutes: duration));
        } else if (rawEndTime.isBefore(startTime)) {
          // If endTime is before startTime, fix it and log warning
          _logger.warning(
              'Surgery $id has end time before start time. Fixing automatically.');
          endTime = startTime.add(Duration(minutes: duration));
        } else {
          // Check if endTime is consistent with startTime + duration
          final calculatedEndTime = startTime.add(Duration(minutes: duration));
          if (calculatedEndTime.difference(rawEndTime).inMinutes.abs() > 1) {
            // If inconsistent, prioritize duration and recalculate end time
            _logger.warning(
                'Surgery $id has inconsistent end time. Recalculating based on duration.');
            endTime = calculatedEndTime;
          } else {
            endTime = rawEndTime;
          }
        }
      } catch (e) {
        // If any error in end time calculation, use safe default
        _logger.warning('Error calculating end time for surgery $id: $e');
        endTime = startTime.add(Duration(minutes: duration));
      }

      // Extract equipment requirements if available
      List<SurgeryEquipmentRequirement> equipmentReqs = [];
      if (data['equipmentRequirements'] is List) {
        try {
          equipmentReqs = (data['equipmentRequirements'] as List)
              .where((item) => item is Map<String, dynamic>)
              .map((reqData) => SurgeryEquipmentRequirement.fromFirestore(
                  reqData as Map<String, dynamic>))
              .toList();
        } catch (e) {
          // If there's an error parsing equipment requirements, log it and continue
          // with an empty list rather than failing the whole surgery parsing
          _logger.warning(
              'Error parsing equipment requirements for surgery $id: $e');
        }
      }

      // Extract or create simple required equipment list
      List<String> requiredEquip = [];
      if (data['requiredEquipment'] is List) {
        requiredEquip = List<String>.from(data['requiredEquipment']);
      } else if (equipmentReqs.isNotEmpty) {
        // If we have detailed requirements but no simple list, extract IDs
        requiredEquip = equipmentReqs
            .where((req) => req.isRequired)
            .map((req) => req.equipmentId)
            .toList();
      }

      // Sanitize prep and cleanup times to ensure they're non-negative
      final prepTime = (data['prepTimeMinutes'] as num?)?.toInt() ?? 0;
      final cleanupTime = (data['cleanupTimeMinutes'] as num?)?.toInt() ?? 0;

      // Extract patient data
      final patientName =
          (data['patientName'] as String?)?.trim() ?? 'Unknown Patient';
      final patientId = data['patientId'] as String?;

      // Extract patient age and gender
      int? patientAge;
      if (data['patientAge'] != null) {
        if (data['patientAge'] is int) {
          patientAge = data['patientAge'] as int;
        } else if (data['patientAge'] is String) {
          patientAge = int.tryParse(data['patientAge'] as String);
        } else if (data['patientAge'] is num) {
          patientAge = (data['patientAge'] as num).toInt();
        }
      }

      final patientGender = data['patientGender'] as String?;

      final surgeryType =
          (data['surgeryType'] as String?)?.trim() ?? 'Undefined Surgery';
      final doctorId = (data['doctorId'] as String?)?.trim() ?? '';
      final surgeon = (data['surgeon'] as String?)?.trim() ?? 'Unassigned';
      final roomId = (data['roomId'] as String?)?.trim() ?? 'Unassigned';

      // For room, ensure it's a non-null list
      List<String> room;
      if (data['room'] is List) {
        room = List<String>.from(data['room']);
      } else if (data['room'] is String &&
          (data['room'] as String).isNotEmpty) {
        room = [(data['room'] as String)];
      } else {
        room = [roomId]; // Use roomId as a default if room is invalid
      }

      // Extract custom time blocks if available
      List<Map<String, dynamic>> timeBlocks = [];
      if (data['customTimeBlocks'] is List) {
        for (var block in data['customTimeBlocks']) {
          if (block is Map) {
            timeBlocks.add(Map<String, dynamic>.from(block));
          }
        }
      }

      return Surgery(
        id: id,
        patientName: patientName,
        patientId: patientId,
        patientAge: patientAge,
        patientGender: patientGender,
        surgeryType: surgeryType,
        doctorId: doctorId,
        surgeon: surgeon,
        dateTime: (data['dateTime'] as Timestamp?)?.toDate() ?? startTime,
        startTime: startTime,
        endTime: endTime,
        roomId: roomId,
        room: room,
        duration: duration > 0 ? duration : 30, // Ensure positive duration
        status: data['status'] as String? ?? 'Scheduled',
        type: data['type'] as String? ?? '',
        notes: data['notes'] as String? ?? '',
        nurses: List<String>.from(data['nurses'] ?? []),
        technologists: List<String>.from(data['technologists'] ?? []),
        prepTimeMinutes: prepTime < 0 ? 0 : prepTime,
        cleanupTimeMinutes: cleanupTime < 0 ? 0 : cleanupTime,
        requiredEquipment: requiredEquip,
        equipmentRequirements: equipmentReqs,
        customTimeFrames:
            (data['customTimeFrames'] as Map<String, dynamic>?) ?? {},
        timeBlocks: timeBlocks,
        firestoreData: Map<String, dynamic>.from(data),
      );
    } catch (e) {
      // Log the error but return a valid Surgery object with default values
      _logger.severe(
          'Error creating Surgery from Firestore data: $e. Using default values.');

      // Get current time for the default surgery
      final now = DateTime.now();
      return Surgery(
        id: id,
        patientName: 'Error Loading Patient',
        surgeryType: 'Unknown Surgery Type',
        doctorId: '',
        surgeon: 'Unknown Surgeon',
        dateTime: now,
        startTime: now,
        endTime: now.add(const Duration(minutes: 30)),
        roomId: 'Unknown Room',
        room: ['Unknown Room'],
        duration: 30,
        status: 'Error',
        type: '',
        nurses: [],
        technologists: [],
        prepTimeMinutes: 0,
        cleanupTimeMinutes: 0,
        requiredEquipment: [],
        equipmentRequirements: [],
        customTimeFrames: {},
        timeBlocks: [],
        firestoreData: {'error': e.toString()},
      );
    }
  }

  /// Converts the Surgery instance to a Firestore document
  ///
  /// Handles:
  /// - DateTime conversion to Timestamp
  /// - List serialization
  /// - Null safety for optional fields
  /// - Equipment requirement serialization
  Map<String, dynamic> toFirestore() {
    // Convert equipment requirements to Firestore format
    final List<Map<String, dynamic>> equipmentReqsData =
        equipmentRequirements.map((req) => req.toFirestore()).toList();

    return {
      'patientName': patientName,
      'patientId': patientId,
      'patientAge': patientAge,
      'patientGender': patientGender,
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
      'prepTimeMinutes': prepTimeMinutes,
      'cleanupTimeMinutes': cleanupTimeMinutes,
      'requiredEquipment': requiredEquipment,
      'equipmentRequirements': equipmentReqsData,
      'customTimeFrames': customTimeFrames,
      'customTimeBlocks': timeBlocks,
    };
  }

  /// Creates a copy of this surgery with modified fields
  Surgery copyWith({
    String? patientName,
    String? patientId,
    int? patientAge,
    String? patientGender,
    String? surgeryType,
    String? doctorId,
    String? surgeon,
    DateTime? dateTime,
    DateTime? startTime,
    DateTime? endTime,
    String? roomId,
    List<String>? room,
    int? duration,
    String? status,
    String? type,
    String? notes,
    List<String>? nurses,
    List<String>? technologists,
    int? prepTimeMinutes,
    int? cleanupTimeMinutes,
    List<String>? requiredEquipment,
    List<SurgeryEquipmentRequirement>? equipmentRequirements,
    Map<String, dynamic>? customTimeFrames,
    List<Map<String, dynamic>>? timeBlocks,
    Map<String, dynamic>? firestoreData,
  }) {
    return Surgery(
      id: this.id,
      patientName: patientName ?? this.patientName,
      patientId: patientId ?? this.patientId,
      patientAge: patientAge ?? this.patientAge,
      patientGender: patientGender ?? this.patientGender,
      surgeryType: surgeryType ?? this.surgeryType,
      doctorId: doctorId ?? this.doctorId,
      surgeon: surgeon ?? this.surgeon,
      dateTime: dateTime ?? this.dateTime,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      roomId: roomId ?? this.roomId,
      room: room ?? this.room,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      nurses: nurses ?? this.nurses,
      technologists: technologists ?? this.technologists,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      cleanupTimeMinutes: cleanupTimeMinutes ?? this.cleanupTimeMinutes,
      requiredEquipment: requiredEquipment ?? this.requiredEquipment,
      equipmentRequirements:
          equipmentRequirements ?? this.equipmentRequirements,
      customTimeFrames: customTimeFrames ?? this.customTimeFrames,
      timeBlocks: timeBlocks ?? this.timeBlocks,
      firestoreData: firestoreData ?? this.firestoreData,
    );
  }

  /// Calculates the total duration including prep and cleanup time
  int get totalDurationMinutes =>
      prepTimeMinutes + duration + cleanupTimeMinutes;

  /// Gets the actual preparation start time (surgery start time minus prep time)
  DateTime get prepStartTime =>
      startTime.subtract(Duration(minutes: prepTimeMinutes));

  /// Gets the actual cleanup end time (surgery end time plus cleanup time)
  DateTime get cleanupEndTime =>
      endTime.add(Duration(minutes: cleanupTimeMinutes));

  /// Checks if this surgery overlaps with another surgery
  bool overlaps(Surgery other) {
    // Compare with prep and cleanup times included
    return this.prepStartTime.isBefore(other.cleanupEndTime) &&
        this.cleanupEndTime.isAfter(other.prepStartTime);
  }

  /// Checks if the given equipment is required for this surgery
  bool requiresEquipment(String equipmentId) {
    return requiredEquipment.contains(equipmentId) ||
        equipmentRequirements.any((req) => req.equipmentId == equipmentId);
  }

  /// Gets equipment requirement details by equipment ID
  SurgeryEquipmentRequirement? getEquipmentRequirement(String equipmentId) {
    try {
      return equipmentRequirements
          .firstWhere((req) => req.equipmentId == equipmentId);
    } catch (e) {
      return null;
    }
  }

  /// Checks if staff availability conflicts with this surgery
  bool hasStaffConflict(String staffId) {
    return doctorId == staffId ||
        nurses.contains(staffId) ||
        technologists.contains(staffId);
  }

  /// Gets a formatted string representation of the surgery time range
  String get timeRangeString {
    final startFormat =
        '${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}';
    final endFormat =
        '${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')}';
    return '$startFormat - $endFormat';
  }

  /// Gets a formatted string representation of the total time including prep and cleanup
  String get totalTimeRangeString {
    final start = prepStartTime;
    final end = cleanupEndTime;
    final startFormat =
        '${start.hour}:${start.minute.toString().padLeft(2, '0')}';
    final endFormat = '${end.hour}:${end.minute.toString().padLeft(2, '0')}';
    return '$startFormat - $endFormat';
  }

  /// Gets a map of all time segments with their start and end times
  Map<String, Map<String, DateTime>> get allTimeSegments {
    final segments = <String, Map<String, DateTime>>{
      'prep': {'start': prepStartTime, 'end': startTime},
      'surgery': {'start': startTime, 'end': endTime},
      'cleanup': {'start': endTime, 'end': cleanupEndTime},
    };

    // Add any custom time frames
    for (final entry in customTimeFrames.entries) {
      final timeFrame = entry.value;
      if (timeFrame is Map &&
          timeFrame['start'] is Timestamp &&
          timeFrame['end'] is Timestamp) {
        segments[entry.key] = {
          'start': (timeFrame['start'] as Timestamp).toDate(),
          'end': (timeFrame['end'] as Timestamp).toDate(),
        };
      }
    }

    return segments;
  }

  /// Provides a string representation of this surgery for debugging
  @override
  String toString() {
    return 'Surgery(id: $id, patientName: $patientName, patientAge: $patientAge, '
        'patientGender: $patientGender, surgeryType: $surgeryType, '
        'surgeon: $surgeon, startTime: $startTime, endTime: $endTime, '
        'room: ${room.join(", ")}, status: $status, '
        'prepTimeMinutes: $prepTimeMinutes, cleanupTimeMinutes: $cleanupTimeMinutes, '
        'requiredEquipment: ${requiredEquipment.length} items)';
  }

  /// Gets total custom time blocks duration in minutes
  int get customTimeBlocksDuration {
    return timeBlocks.fold(
        0, (sum, block) => sum + (block['durationMinutes'] as int? ?? 0));
  }

  /// Gets total surgery time including prep, procedure, cleanup and custom blocks
  int get grandTotalDuration {
    return prepTimeMinutes +
        duration +
        cleanupTimeMinutes +
        customTimeBlocksDuration;
  }

  /// Compares this surgery with another for equality
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Surgery &&
        other.id == id &&
        other.patientName == patientName &&
        other.patientId == patientId &&
        other.patientAge == patientAge &&
        other.patientGender == patientGender &&
        other.surgeryType == surgeryType &&
        other.doctorId == doctorId &&
        other.surgeon == surgeon &&
        other.dateTime == dateTime &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.roomId == roomId &&
        _listEquals(other.room, room) &&
        other.duration == duration &&
        other.status == status &&
        other.type == type &&
        other.notes == notes &&
        _listEquals(other.nurses, nurses) &&
        _listEquals(other.technologists, technologists) &&
        other.prepTimeMinutes == prepTimeMinutes &&
        other.cleanupTimeMinutes == cleanupTimeMinutes &&
        _listEquals(other.requiredEquipment, requiredEquipment) &&
        _listEquals(other.equipmentRequirements, equipmentRequirements) &&
        _mapEquals(other.customTimeFrames, customTimeFrames) &&
        _listOfMapsEquals(other.timeBlocks, timeBlocks);
  }

  /// Provides a consistent hash code for this surgery
  @override
  int get hashCode {
    return id.hashCode ^
        patientName.hashCode ^
        patientId.hashCode ^
        patientAge.hashCode ^
        patientGender.hashCode ^
        surgeryType.hashCode ^
        doctorId.hashCode ^
        surgeon.hashCode ^
        dateTime.hashCode ^
        startTime.hashCode ^
        endTime.hashCode ^
        roomId.hashCode ^
        room.hashCode ^
        duration.hashCode ^
        status.hashCode ^
        type.hashCode ^
        notes.hashCode ^
        nurses.hashCode ^
        technologists.hashCode ^
        prepTimeMinutes.hashCode ^
        cleanupTimeMinutes.hashCode ^
        requiredEquipment.hashCode ^
        equipmentRequirements.hashCode ^
        customTimeFrames.hashCode ^
        timeBlocks.hashCode;
  }

  /// Helper to compare two lists for equality
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Helper to compare two maps for equality
  bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }

  /// Helper to compare two lists of maps for equality
  bool _listOfMapsEquals(
      List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;

    for (int i = 0; i < a.length; i++) {
      if (!_mapEquals(a[i], b[i])) return false;
    }

    return true;
  }
}

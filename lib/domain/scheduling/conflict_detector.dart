import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

/// Detects scheduling conflicts for surgeries.
class ConflictDetector {
  final FirebaseFirestore _firestore;
  final _logger = Logger('ConflictDetector');

  ConflictDetector({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Check for all types of conflicts for a proposed surgery.
  Future<List<ConflictResult>> checkConflicts({
    required String roomId,
    required DateTime startTime,
    required DateTime endTime,
    required String surgeonId,
    List<String> nurseIds = const [],
    String? technologistId,
    List<String> equipmentIds = const [],
    String? excludeSurgeryId,
  }) async {
    _logger
        .info('Checking conflicts for room $roomId at $startTime - $endTime');
    final conflicts = <ConflictResult>[];

    // Check room conflicts
    final roomConflicts = await _checkResourceConflicts(
      field: 'room',
      value: roomId,
      startTime: startTime,
      endTime: endTime,
      excludeSurgeryId: excludeSurgeryId,
      conflictType: ConflictType.roomConflict,
      resourceName: roomId,
    );
    conflicts.addAll(roomConflicts);

    // Check surgeon conflicts
    if (surgeonId.isNotEmpty) {
      final surgeonConflicts = await _checkResourceConflicts(
        field: 'surgeon',
        value: surgeonId,
        startTime: startTime,
        endTime: endTime,
        excludeSurgeryId: excludeSurgeryId,
        conflictType: ConflictType.surgeonConflict,
        resourceName: surgeonId,
      );
      conflicts.addAll(surgeonConflicts);
    }

    // Check nurse conflicts
    for (final nurseId in nurseIds) {
      final nurseConflicts = await _checkArrayResourceConflicts(
        field: 'nurses',
        value: nurseId,
        startTime: startTime,
        endTime: endTime,
        excludeSurgeryId: excludeSurgeryId,
        conflictType: ConflictType.nurseConflict,
        resourceName: nurseId,
      );
      conflicts.addAll(nurseConflicts);
    }

    // Check technologist conflicts
    if (technologistId != null && technologistId.isNotEmpty) {
      final techConflicts = await _checkArrayResourceConflicts(
        field: 'technologists',
        value: technologistId,
        startTime: startTime,
        endTime: endTime,
        excludeSurgeryId: excludeSurgeryId,
        conflictType: ConflictType.technologistConflict,
        resourceName: technologistId,
      );
      conflicts.addAll(techConflicts);
    }

    return conflicts;
  }

  Future<List<ConflictResult>> _checkResourceConflicts({
    required String field,
    required String value,
    required DateTime startTime,
    required DateTime endTime,
    String? excludeSurgeryId,
    required ConflictType conflictType,
    required String resourceName,
  }) async {
    try {
      final query = await _firestore
          .collection('surgeries')
          .where(field, isEqualTo: value)
          .where('status', whereIn: ['Scheduled', 'In Progress']).get();

      final conflicts = <ConflictResult>[];
      for (final doc in query.docs) {
        if (excludeSurgeryId != null && doc.id == excludeSurgeryId) continue;

        final data = doc.data();
        final surgeryStart = (data['startTime'] as Timestamp).toDate();
        final surgeryEnd = (data['endTime'] as Timestamp).toDate();

        if (startTime.isBefore(surgeryEnd) && endTime.isAfter(surgeryStart)) {
          conflicts.add(ConflictResult(
            type: conflictType,
            resourceId: value,
            resourceName: resourceName,
            conflictingSurgeryId: doc.id,
            message:
                '$resourceName is already booked for ${data['surgeryType'] ?? 'a surgery'}',
          ));
        }
      }
      return conflicts;
    } catch (e) {
      _logger.warning('Error checking $field conflicts: $e');
      return [];
    }
  }

  Future<List<ConflictResult>> _checkArrayResourceConflicts({
    required String field,
    required String value,
    required DateTime startTime,
    required DateTime endTime,
    String? excludeSurgeryId,
    required ConflictType conflictType,
    required String resourceName,
  }) async {
    try {
      final query = await _firestore
          .collection('surgeries')
          .where(field, arrayContains: value)
          .where('status', whereIn: ['Scheduled', 'In Progress']).get();

      final conflicts = <ConflictResult>[];
      for (final doc in query.docs) {
        if (excludeSurgeryId != null && doc.id == excludeSurgeryId) continue;

        final data = doc.data();
        final surgeryStart = (data['startTime'] as Timestamp).toDate();
        final surgeryEnd = (data['endTime'] as Timestamp).toDate();

        if (startTime.isBefore(surgeryEnd) && endTime.isAfter(surgeryStart)) {
          conflicts.add(ConflictResult(
            type: conflictType,
            resourceId: value,
            resourceName: resourceName,
            conflictingSurgeryId: doc.id,
            message:
                '$resourceName is already assigned to ${data['surgeryType'] ?? 'a surgery'}',
          ));
        }
      }
      return conflicts;
    } catch (e) {
      _logger.warning('Error checking $field conflicts: $e');
      return [];
    }
  }

  /// Check if a specific room is available.
  Future<bool> isRoomAvailable({
    required String roomId,
    required DateTime startTime,
    required DateTime endTime,
    String? excludeSurgeryId,
  }) async {
    final conflicts = await _checkResourceConflicts(
      field: 'room',
      value: roomId,
      startTime: startTime,
      endTime: endTime,
      excludeSurgeryId: excludeSurgeryId,
      conflictType: ConflictType.roomConflict,
      resourceName: roomId,
    );
    return conflicts.isEmpty;
  }

  /// Check if a staff member is available.
  Future<bool> isStaffAvailable({
    required String staffId,
    required DateTime startTime,
    required DateTime endTime,
    String? excludeSurgeryId,
  }) async {
    // Check as surgeon
    final surgeonConflicts = await _checkResourceConflicts(
      field: 'surgeon',
      value: staffId,
      startTime: startTime,
      endTime: endTime,
      excludeSurgeryId: excludeSurgeryId,
      conflictType: ConflictType.surgeonConflict,
      resourceName: staffId,
    );
    if (surgeonConflicts.isNotEmpty) return false;

    // Check as nurse
    final nurseConflicts = await _checkArrayResourceConflicts(
      field: 'nurses',
      value: staffId,
      startTime: startTime,
      endTime: endTime,
      excludeSurgeryId: excludeSurgeryId,
      conflictType: ConflictType.nurseConflict,
      resourceName: staffId,
    );
    if (nurseConflicts.isNotEmpty) return false;

    // Check as technologist
    final techConflicts = await _checkArrayResourceConflicts(
      field: 'technologists',
      value: staffId,
      startTime: startTime,
      endTime: endTime,
      excludeSurgeryId: excludeSurgeryId,
      conflictType: ConflictType.technologistConflict,
      resourceName: staffId,
    );
    return techConflicts.isEmpty;
  }
}

/// Represents a detected scheduling conflict.
class ConflictResult {
  final ConflictType type;
  final String resourceId;
  final String resourceName;
  final String conflictingSurgeryId;
  final String message;

  const ConflictResult({
    required this.type,
    required this.resourceId,
    required this.resourceName,
    required this.conflictingSurgeryId,
    required this.message,
  });
}

/// Types of scheduling conflicts.
enum ConflictType {
  roomConflict,
  surgeonConflict,
  nurseConflict,
  technologistConflict,
  equipmentConflict,
}

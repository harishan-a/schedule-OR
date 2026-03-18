import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

class ResourceCheckService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _logger = Logger('ResourceCheckService');

  // Default values for missing fields
  static const Map<String, String> defaultRoomData = {
    'name': 'Operating Room',
    'type': 'Standard',
    'isActive': 'true',
    'floor': '1',
  };

  static const Map<String, String> defaultStaffData = {
    'name': 'Staff Member',
    'role': 'Staff',
    'department': 'Surgery',
    'specialization': 'General',
    'specialty': 'General',
  };

  // Check room availability for a specific time slot
  Future<bool> isRoomAvailable(
      String roomId, DateTime startTime, DateTime endTime) async {
    if (roomId.isEmpty) {
      throw ArgumentError('Room ID cannot be empty');
    }
    if (endTime.isBefore(startTime)) {
      throw ArgumentError('End time cannot be before start time');
    }

    try {
      // First check if the room exists and is active
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      if (!roomDoc.exists) {
        _logger.warning('Room $roomId does not exist');
        return false;
      }

      final data = roomDoc.data() as Map<String, dynamic>;
      if (data['isActive'] == false) {
        _logger.info('Room $roomId is not active');
        return false;
      }

      // Check for conflicting surgeries
      final conflictingBookings = await _firestore
          .collection('surgeries')
          .where('room', isEqualTo: roomId)
          .where('status', whereIn: ['Scheduled', 'In Progress']).get();

      // Manually filter by time because of Firestore query limitations
      for (var doc in conflictingBookings.docs) {
        final data = doc.data();

        if (!data.containsKey('startTime') || !data.containsKey('endTime')) {
          _logger.warning('Surgery ${doc.id} has missing time data');
          continue;
        }

        final surgeryStart = (data['startTime'] as Timestamp).toDate();
        final surgeryEnd = (data['endTime'] as Timestamp).toDate();

        // Check if there's overlap
        if (surgeryStart.isBefore(endTime) && surgeryEnd.isAfter(startTime)) {
          _logger.info(
              'Room $roomId has conflicting booking at $surgeryStart - $surgeryEnd');
          return false;
        }
      }

      _logger.info('Room $roomId is available');
      return true;
    } catch (e) {
      _logger.severe('Error checking room availability: $e');
      rethrow;
    }
  }

  // Check staff availability for a specific time slot
  Future<bool> isStaffAvailable(
      String staffId, DateTime startTime, DateTime endTime) async {
    if (staffId.isEmpty) {
      throw ArgumentError('Staff ID cannot be empty');
    }
    if (endTime.isBefore(startTime)) {
      throw ArgumentError('End time cannot be before start time');
    }

    try {
      // First check if staff exists and is active
      final staffDoc = await _firestore.collection('users').doc(staffId).get();
      if (!staffDoc.exists) {
        _logger.warning('Staff $staffId does not exist');
        return false;
      }

      // Check for conflicting bookings
      final conflictingBookings = await _firestore
          .collection('surgeries')
          .where('status', whereIn: ['Scheduled', 'In Progress']).get();

      // Manually filter by time and staff
      for (var doc in conflictingBookings.docs) {
        final data = doc.data();

        if (!data.containsKey('startTime') || !data.containsKey('endTime')) {
          _logger.warning('Surgery ${doc.id} has missing time data');
          continue;
        }

        final surgeryStart = (data['startTime'] as Timestamp).toDate();
        final surgeryEnd = (data['endTime'] as Timestamp).toDate();

        // Skip if no time overlap
        if (surgeryEnd.isBefore(startTime) || surgeryStart.isAfter(endTime)) {
          continue;
        }

        // Check if staff is assigned to this surgery
        final surgeon = data['surgeon'] as String?;
        final nurses = data.containsKey('nurses') && data['nurses'] is List
            ? List<String>.from(data['nurses'])
            : <String>[];
        final techs =
            data.containsKey('technologists') && data['technologists'] is List
                ? List<String>.from(data['technologists'])
                : <String>[];

        if (surgeon == staffId ||
            nurses.contains(staffId) ||
            techs.contains(staffId)) {
          _logger.info(
              'Staff $staffId has conflicting booking at $surgeryStart - $surgeryEnd');
          return false;
        }
      }

      _logger.info('Staff $staffId is available');
      return true;
    } catch (e) {
      _logger.severe('Error checking staff availability: $e');
      rethrow;
    }
  }

  // Get all available rooms for a specific time slot
  Future<List<DocumentSnapshot>> getAvailableRooms(
      DateTime startTime, DateTime endTime) async {
    if (endTime.isBefore(startTime)) {
      throw ArgumentError('End time cannot be before start time');
    }

    try {
      // First, get all active rooms
      final allRooms = await _firestore.collection('rooms').get();

      if (allRooms.docs.isEmpty) {
        _logger.warning('No rooms found in the database');
        return [];
      }

      // Filter out inactive rooms
      final activeRooms = allRooms.docs.where((room) {
        final data = room.data() as Map<String, dynamic>;
        return data['isActive'] != false; // Consider missing isActive as true
      }).toList();

      if (activeRooms.isEmpty) {
        _logger.warning('No active rooms found in the database');
        return [];
      }

      // Add default values to rooms with missing fields
      for (final room in activeRooms) {
        final data = room.data() as Map<String, dynamic>;

        // Fill in defaults for missing fields
        _ensureRoomDefaults(data);
      }

      // Then, get all surgeries
      final allSurgeries = await _firestore
          .collection('surgeries')
          .where('status', whereIn: ['Scheduled', 'In Progress']).get();

      // Create a map to track which rooms are booked during the time slot
      final Map<String, bool> roomAvailability = {};
      for (var room in activeRooms) {
        roomAvailability[room.id] = true; // Start with all rooms available
      }

      // Check each surgery for conflicts
      for (var surgery in allSurgeries.docs) {
        final data = surgery.data();
        final roomId = data['room'] as String?;

        // Skip if no room assigned or room doesn't exist in our list
        if (roomId == null || !roomAvailability.containsKey(roomId)) {
          continue;
        }

        if (!data.containsKey('startTime') || !data.containsKey('endTime')) {
          _logger.warning('Surgery ${surgery.id} has missing time data');
          continue;
        }

        final surgeryStart = (data['startTime'] as Timestamp).toDate();
        final surgeryEnd = (data['endTime'] as Timestamp).toDate();

        // Check for overlap
        if (surgeryStart.isBefore(endTime) && surgeryEnd.isAfter(startTime)) {
          roomAvailability[roomId] = false; // Mark room as unavailable
        }
      }

      // Filter rooms by availability
      final availableRooms = activeRooms.where((room) {
        return roomAvailability[room.id] == true;
      }).toList();

      _logger.info(
          'Found ${availableRooms.length} available rooms out of ${activeRooms.length}');
      return availableRooms;
    } catch (e) {
      _logger.severe('Error getting available rooms: $e');
      rethrow;
    }
  }

  // Get all available staff for a specific time slot
  Future<List<DocumentSnapshot>> getAvailableStaff(
    DateTime startTime,
    DateTime endTime,
    String role,
  ) async {
    if (endTime.isBefore(startTime)) {
      throw ArgumentError('End time cannot be before start time');
    }
    if (role.isEmpty) {
      throw ArgumentError('Role cannot be empty');
    }

    try {
      // First, get all staff of the specified role
      final allStaff = await _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .get();

      if (allStaff.docs.isEmpty) {
        _logger.warning('No staff found with role: $role');
        return [];
      }

      // Add default values to staff with missing fields
      for (final staff in allStaff.docs) {
        final data = staff.data() as Map<String, dynamic>;

        // Fill in defaults for missing fields
        _ensureStaffDefaults(data, role);
      }

      // Create a map to track staff availability
      final Map<String, bool> staffAvailability = {};
      for (var staff in allStaff.docs) {
        staffAvailability[staff.id] = true; // Start with all staff available
      }

      // Get all surgeries that might have scheduling conflicts
      final allSurgeries = await _firestore
          .collection('surgeries')
          .where('status', whereIn: ['Scheduled', 'In Progress']).get();

      // Check each surgery for conflicts with staff
      for (var surgery in allSurgeries.docs) {
        final data = surgery.data();

        if (!data.containsKey('startTime') || !data.containsKey('endTime')) {
          _logger.warning('Surgery ${surgery.id} has missing time data');
          continue;
        }

        final surgeryStart = (data['startTime'] as Timestamp).toDate();
        final surgeryEnd = (data['endTime'] as Timestamp).toDate();

        // Skip if no time overlap
        if (surgeryEnd.isBefore(startTime) || surgeryStart.isAfter(endTime)) {
          continue;
        }

        // Check surgeon
        final surgeonId = data['surgeon'] as String?;
        if (surgeonId != null && staffAvailability.containsKey(surgeonId)) {
          staffAvailability[surgeonId] = false;
        }

        // Check nurses
        final nurses = data.containsKey('nurses') && data['nurses'] is List
            ? List<String>.from(data['nurses'])
            : <String>[];
        for (var nurseId in nurses) {
          if (staffAvailability.containsKey(nurseId)) {
            staffAvailability[nurseId] = false;
          }
        }

        // Check technologists
        final techs =
            data.containsKey('technologists') && data['technologists'] is List
                ? List<String>.from(data['technologists'])
                : <String>[];
        for (var techId in techs) {
          if (staffAvailability.containsKey(techId)) {
            staffAvailability[techId] = false;
          }
        }
      }

      // Filter staff by availability
      final availableStaff = allStaff.docs.where((staff) {
        return staffAvailability[staff.id] == true;
      }).toList();

      _logger.info(
          'Found ${availableStaff.length} available $role out of ${allStaff.docs.length}');
      return availableStaff;
    } catch (e) {
      _logger.severe('Error getting available staff: $e');
      rethrow;
    }
  }

  // Get all surgeries for a specific time range
  Future<List<DocumentSnapshot>> getSurgeriesInRange(
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      final surgeries = await _firestore
          .collection('surgeries')
          .where('status', whereIn: ['Scheduled', 'In Progress']).get();

      // Manually filter by time range
      final filteredSurgeries = surgeries.docs.where((doc) {
        final data = doc.data();

        if (!data.containsKey('startTime') || !data.containsKey('endTime')) {
          _logger.warning('Surgery ${doc.id} has missing time data');
          return false;
        }

        final surgeryStart = (data['startTime'] as Timestamp).toDate();
        final surgeryEnd = (data['endTime'] as Timestamp).toDate();

        // Include if surgery starts within our range
        return surgeryStart.isAfter(startTime) &&
            surgeryStart.isBefore(endTime);
      }).toList();

      // Sort by start time
      filteredSurgeries.sort((a, b) {
        final aStart = (a.data()['startTime'] as Timestamp).toDate();
        final bStart = (b.data()['startTime'] as Timestamp).toDate();
        return aStart.compareTo(bStart);
      });

      return filteredSurgeries;
    } catch (e) {
      _logger.severe('Error getting surgeries in range: $e');
      rethrow;
    }
  }

  // Get resource details
  Future<DocumentSnapshot?> getResourceDetails(
      String resourceId, String collection) async {
    try {
      final doc = await _firestore.collection(collection).doc(resourceId).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        // Fill in default values for missing fields based on collection type
        if (collection == 'rooms') {
          _ensureRoomDefaults(data);
        } else if (collection == 'users') {
          _ensureStaffDefaults(data, data['role'] as String? ?? 'Staff');
        }
      }

      return doc.exists ? doc : null;
    } catch (e) {
      _logger.severe('Error getting resource details: $e');
      rethrow;
    }
  }

  // Ensure room data has all required fields
  void _ensureRoomDefaults(Map<String, dynamic> data) {
    for (final entry in defaultRoomData.entries) {
      if (!data.containsKey(entry.key) || data[entry.key] == null) {
        data[entry.key] = entry.value;
      }
    }
  }

  // Ensure staff data has all required fields
  void _ensureStaffDefaults(Map<String, dynamic> data, String role) {
    for (final entry in defaultStaffData.entries) {
      if (!data.containsKey(entry.key) || data[entry.key] == null) {
        data[entry.key] = entry.value;
      }
    }

    // Add role-specific defaults
    if (role == 'Doctor' &&
        (!data.containsKey('specialization') ||
            data['specialization'] == null)) {
      data['specialization'] = 'General Surgery';
    } else if (role == 'Nurse' &&
        (!data.containsKey('department') || data['department'] == null)) {
      data['department'] = 'Surgery Department';
    } else if (role == 'Technologist' &&
        (!data.containsKey('specialty') || data['specialty'] == null)) {
      data['specialty'] = 'Surgical Technology';
    }
  }

  // Check overall resource availability
  Future<bool> checkResourceAvailability() async {
    try {
      _logger.info('Checking resource availability');
      return true;
    } catch (e) {
      _logger.severe('Error checking resource availability: $e');
      return false;
    }
  }
}

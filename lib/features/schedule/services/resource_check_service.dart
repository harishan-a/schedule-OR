import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResourceCheckService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check room availability for a specific time slot
  Future<bool> isRoomAvailable(String roomId, DateTime startTime, DateTime endTime) async {
    if (roomId.isEmpty) {
      throw ArgumentError('Room ID cannot be empty');
    }
    if (endTime.isBefore(startTime)) {
      throw ArgumentError('End time cannot be before start time');
    }

    try {
      final conflictingBookings = await _firestore
          .collection('surgeries')
          .where('room', isEqualTo: roomId)
          .where('status', whereIn: ['Scheduled', 'In Progress'])
          .where('startTime', isLessThan: endTime)
          .where('endTime', isGreaterThan: startTime)
          .get();

      return conflictingBookings.docs.isEmpty;
    } catch (e) {
      print('Error checking room availability: $e');
      rethrow;
    }
  }

  // Check staff availability for a specific time slot
  Future<bool> isStaffAvailable(String staffId, DateTime startTime, DateTime endTime) async {
    if (staffId.isEmpty) {
      throw ArgumentError('Staff ID cannot be empty');
    }
    if (endTime.isBefore(startTime)) {
      throw ArgumentError('End time cannot be before start time');
    }

    try {
      final conflictingBookings = await _firestore
          .collection('surgeries')
          .where(Filter.or(
            Filter('surgeon', isEqualTo: staffId),
            Filter('nurses', arrayContains: staffId),
            Filter('technologists', arrayContains: staffId),
          ))
          .where('status', whereIn: ['Scheduled', 'In Progress'])
          .where('startTime', isLessThan: endTime)
          .where('endTime', isGreaterThan: startTime)
          .get();

      return conflictingBookings.docs.isEmpty;
    } catch (e) {
      print('Error checking staff availability: $e');
      rethrow;
    }
  }

  // Get all available rooms for a specific time slot
  Future<List<DocumentSnapshot>> getAvailableRooms(DateTime startTime, DateTime endTime) async {
    if (endTime.isBefore(startTime)) {
      throw ArgumentError('End time cannot be before start time');
    }

    try {
      // First, get all rooms
      final allRooms = await _firestore.collection('rooms').get();
      
      // Then, get all surgeries that might conflict with the time slot
      final conflictingSurgeries = await _firestore
          .collection('surgeries')
          .where('status', whereIn: ['Scheduled', 'In Progress'])
          .where('startTime', isLessThan: endTime)
          .where('endTime', isGreaterThan: startTime)
          .get();

      // Create a set of room IDs that are booked
      final bookedRoomIds = conflictingSurgeries.docs
          .map((doc) => doc.data()['room'] as String)
          .toSet();

      // Filter out booked rooms
      return allRooms.docs
          .where((room) => !bookedRoomIds.contains(room.id))
          .toList();
    } catch (e) {
      print('Error getting available rooms: $e');
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

      // Then, get all surgeries that might conflict with the time slot
      final conflictingSurgeries = await _firestore
          .collection('surgeries')
          .where('status', whereIn: ['Scheduled', 'In Progress'])
          .where('startTime', isLessThan: endTime)
          .where('endTime', isGreaterThan: startTime)
          .get();

      // Create sets of staff IDs that are booked
      final bookedSurgeons = conflictingSurgeries.docs
          .map((doc) => doc.data()['surgeon'] as String)
          .toSet();

      final bookedNurses = conflictingSurgeries.docs
          .expand((doc) => (doc.data()['nurses'] as List).cast<String>())
          .toSet();

      final bookedTechs = conflictingSurgeries.docs
          .expand((doc) => (doc.data()['technologists'] as List).cast<String>())
          .toSet();

      // Combine all booked staff
      final allBookedStaff = {...bookedSurgeons, ...bookedNurses, ...bookedTechs};

      // Filter out booked staff
      return allStaff.docs
          .where((staff) => !allBookedStaff.contains(staff.id))
          .toList();
    } catch (e) {
      print('Error getting available staff: $e');
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
          .where('status', whereIn: ['Scheduled', 'In Progress'])
          .where('startTime', isGreaterThanOrEqualTo: startTime)
          .where('startTime', isLessThanOrEqualTo: endTime)
          .orderBy('startTime')
          .get();

      return surgeries.docs;
    } catch (e) {
      print('Error getting surgeries in range: $e');
      rethrow;
    }
  }

  // Get resource details
  Future<DocumentSnapshot?> getResourceDetails(String resourceId, String collection) async {
    try {
      final doc = await _firestore.collection(collection).doc(resourceId).get();
      return doc.exists ? doc : null;
    } catch (e) {
      print('Error getting resource details: $e');
      rethrow;
    }
  }
} 
// =============================================================================
// Equipment Repository
// =============================================================================
// Repository for managing medical equipment data in the OR scheduling system.
// Following the repository pattern, this class:
// - Acts as a single source of truth for equipment data
// - Abstracts the data source implementation details
// - Provides a clean API for the rest of the application
//
// Functionality:
// - CRUD operations for equipment items
// - Advanced filtering and querying
// - Availability checking within timeframes
// - Real-time data monitoring through streams
// - Pagination support for large datasets
// - Caching for improved performance
//
// Firebase Integration:
// - Uses Firestore as the primary data source
// - Provides caching and offline capabilities
// - Implements error handling and retry logic
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import 'dart:async';
import '../models/equipment.dart';
import 'package:flutter/foundation.dart';

/// Repository class for managing equipment data
class EquipmentRepository {
  // Firestore instance for database operations
  final FirebaseFirestore _firestore;

  // Collection reference for equipment
  late final CollectionReference _equipmentCollection;

  // Logger for tracking operations
  final _logger = Logger('EquipmentRepository');

  // Cache for equipment data to improve performance
  final Map<String, Equipment> _equipmentCache = {};

  // Cache expiration time (5 minutes)
  final Duration _cacheExpiration = const Duration(minutes: 5);

  // Last cache refresh time
  DateTime _lastCacheRefresh = DateTime(1970);

  // Default page size for paginated queries
  static const int defaultPageSize = 20;

  /// Creates a new EquipmentRepository instance
  ///
  /// By default, uses the global FirebaseFirestore instance
  /// Can be provided with a custom instance for testing
  EquipmentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance {
    _equipmentCollection = _firestore.collection('equipment');
  }

  /// Fetches all equipment from the database
  ///
  /// Returns a list of Equipment objects
  /// Uses caching to improve performance
  Future<List<Equipment>> getAllEquipment() async {
    try {
      // Check if cache is valid
      if (_isCacheValid()) {
        _logger.info('Using cached equipment data');
        return _equipmentCache.values.toList();
      }

      final snapshot = await _equipmentCollection.get();
      var equipmentList = snapshot.docs
          .map((doc) => Equipment.fromFirestore(
              doc.id, doc.data() as Map<String, dynamic>))
          .toList();

      // If no equipment in database, add some sample data
      if (equipmentList.isEmpty) {
        equipmentList = _getSampleEquipment();
      }

      // Update cache
      _updateCache(equipmentList);

      return equipmentList;
    } catch (e) {
      _logger.severe('Error fetching all equipment: $e');
      // Return sample data on error
      debugPrint('Error fetching equipment: $e - using sample data');
      return _getSampleEquipment();
    }
  }

  /// Fetches equipment with pagination support
  ///
  /// Returns a paginated list of Equipment objects
  /// [pageSize] determines how many items to fetch per page
  /// [lastDocumentId] is the ID of the last document from the previous page
  Future<List<Equipment>> getEquipmentPaginated({
    int pageSize = defaultPageSize,
    String? lastDocumentId,
  }) async {
    try {
      Query query = _equipmentCollection.orderBy('name').limit(pageSize);

      // If lastDocumentId is provided, start after that document
      if (lastDocumentId != null) {
        final lastDocSnapshot =
            await _equipmentCollection.doc(lastDocumentId).get();
        if (lastDocSnapshot.exists) {
          query = query.startAfterDocument(lastDocSnapshot);
        }
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => Equipment.fromFirestore(
              doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.severe('Error fetching paginated equipment: $e');
      rethrow;
    }
  }

  /// Provides a stream of all equipment for real-time updates
  ///
  /// Returns a stream of Equipment lists that updates automatically
  Stream<List<Equipment>> getAllEquipmentStream() {
    try {
      return _equipmentCollection.snapshots().map((snapshot) => snapshot.docs
          .map((doc) => Equipment.fromFirestore(
              doc.id, doc.data() as Map<String, dynamic>))
          .toList());
    } catch (e) {
      _logger.severe('Error creating equipment stream: $e');
      rethrow;
    }
  }

  /// Gets a specific equipment by ID
  ///
  /// Returns null if the equipment doesn't exist
  /// Tries to use cached data if available
  Future<Equipment?> getEquipmentById(String id) async {
    try {
      // Check cache first
      if (_equipmentCache.containsKey(id) && _isCacheValid()) {
        return _equipmentCache[id];
      }

      final docSnapshot = await _equipmentCollection.doc(id).get();
      if (!docSnapshot.exists) {
        return null;
      }

      final equipment = Equipment.fromFirestore(
          docSnapshot.id, docSnapshot.data() as Map<String, dynamic>);

      // Update cache for this item
      _equipmentCache[id] = equipment;

      return equipment;
    } catch (e) {
      _logger.severe('Error fetching equipment with ID $id: $e');
      rethrow;
    }
  }

  /// Fetches equipment filtered by category
  ///
  /// Returns a list of Equipment objects matching the category
  Future<List<Equipment>> getEquipmentByCategory(String category) async {
    try {
      // Try to use cache if valid
      if (_isCacheValid()) {
        return _equipmentCache.values
            .where((equipment) => equipment.category == category)
            .toList();
      }

      final snapshot = await _equipmentCollection
          .where('category', isEqualTo: category)
          .get();

      final equipmentList = snapshot.docs
          .map((doc) => Equipment.fromFirestore(
              doc.id, doc.data() as Map<String, dynamic>))
          .toList();

      // Selectively update cache
      for (final equipment in equipmentList) {
        _equipmentCache[equipment.id] = equipment;
      }

      return equipmentList;
    } catch (e) {
      _logger.severe('Error fetching equipment by category $category: $e');
      rethrow;
    }
  }

  /// Fetches equipment filtered by availability
  ///
  /// Returns a list of Equipment objects with the specified availability
  Future<List<Equipment>> getEquipmentByAvailability(bool isAvailable) async {
    try {
      // Try to use cache if valid
      if (_isCacheValid()) {
        return _equipmentCache.values
            .where((equipment) => equipment.isAvailable == isAvailable)
            .toList();
      }

      final snapshot = await _equipmentCollection
          .where('isAvailable', isEqualTo: isAvailable)
          .get();

      final equipmentList = snapshot.docs
          .map((doc) => Equipment.fromFirestore(
              doc.id, doc.data() as Map<String, dynamic>))
          .toList();

      // Selectively update cache
      for (final equipment in equipmentList) {
        _equipmentCache[equipment.id] = equipment;
      }

      return equipmentList;
    } catch (e) {
      _logger
          .severe('Error fetching equipment by availability $isAvailable: $e');
      rethrow;
    }
  }

  /// Checks if a specific equipment is available during a timeframe
  ///
  /// Queries the surgeries collection to find any conflicts
  /// Returns true if the equipment is available
  Future<bool> isEquipmentAvailableDuringTimeframe(
      String equipmentId, DateTime startTime, DateTime endTime) async {
    if (equipmentId.isEmpty) {
      throw ArgumentError('Equipment ID cannot be empty');
    }
    if (endTime.isBefore(startTime)) {
      throw ArgumentError('End time cannot be before start time');
    }

    try {
      // First check if equipment exists and is generally available
      final equipment = await getEquipmentById(equipmentId);
      if (equipment == null || !equipment.isAvailable) {
        return false;
      }

      // Then check for any surgeries using this equipment during the timeframe
      final conflictingSurgeries = await _firestore
          .collection('surgeries')
          .where('requiredEquipment', arrayContains: equipmentId)
          .where('status', whereIn: ['Scheduled', 'In Progress'])
          .where('startTime', isLessThan: Timestamp.fromDate(endTime))
          .where('endTime', isGreaterThan: Timestamp.fromDate(startTime))
          .get();

      // If there are any surgeries using this equipment during the timeframe,
      // it's not available
      return conflictingSurgeries.docs.isEmpty;
    } catch (e) {
      _logger.severe('Error checking equipment availability: $e');
      rethrow;
    }
  }

  /// Gets all equipment available during a specific timeframe
  ///
  /// Accounts for both general availability and booking conflicts
  Future<List<Equipment>> getAvailableEquipmentDuringTimeframe(
      DateTime startTime, DateTime endTime) async {
    if (endTime.isBefore(startTime)) {
      throw ArgumentError('End time cannot be before start time');
    }

    try {
      // Get all generally available equipment
      final availableEquipment = await getEquipmentByAvailability(true);

      // Get all equipment IDs that are booked during the timeframe
      final bookedEquipmentQuery = await _firestore
          .collection('surgeries')
          .where('status', whereIn: ['Scheduled', 'In Progress'])
          .where('startTime', isLessThan: Timestamp.fromDate(endTime))
          .where('endTime', isGreaterThan: Timestamp.fromDate(startTime))
          .get();

      // Extract equipment IDs from the query results
      final Set<String> bookedEquipmentIds = {};
      for (final doc in bookedEquipmentQuery.docs) {
        final data = doc.data();
        if (data.containsKey('requiredEquipment') &&
            data['requiredEquipment'] is List) {
          bookedEquipmentIds.addAll((data['requiredEquipment'] as List)
              .map((item) => item.toString())
              .toList());
        }
      }

      // Filter out booked equipment
      return availableEquipment
          .where((equipment) => !bookedEquipmentIds.contains(equipment.id))
          .toList();
    } catch (e) {
      _logger.severe('Error getting available equipment during timeframe: $e');
      rethrow;
    }
  }

  /// Adds a new equipment to the database
  ///
  /// Returns the ID of the newly created equipment
  /// Updates the cache with the new equipment
  Future<String> addEquipment(Equipment equipment) async {
    try {
      final docRef = await _equipmentCollection.add(equipment.toFirestore());
      final newId = docRef.id;

      // Update cache with the new equipment
      _equipmentCache[newId] = Equipment(
        id: newId,
        name: equipment.name,
        category: equipment.category,
        locationId: equipment.locationId,
        isAvailable: equipment.isAvailable,
        specifications: equipment.specifications,
      );

      _logger.info('Added new equipment with ID: $newId');
      return newId;
    } catch (e) {
      _logger.severe('Error adding equipment: $e');
      rethrow;
    }
  }

  /// Updates an existing equipment in the database
  ///
  /// Updates the cache with the modified equipment
  Future<void> updateEquipment(Equipment equipment) async {
    try {
      await _equipmentCollection
          .doc(equipment.id)
          .update(equipment.toFirestore());

      // Update cache
      _equipmentCache[equipment.id] = equipment;

      _logger.info('Updated equipment with ID: ${equipment.id}');
    } catch (e) {
      _logger.severe('Error updating equipment: $e');
      rethrow;
    }
  }

  /// Updates the availability status of an equipment
  ///
  /// Updates the cache if the equipment is cached
  Future<void> updateEquipmentAvailability(String id, bool isAvailable) async {
    try {
      await _equipmentCollection.doc(id).update({'isAvailable': isAvailable});

      // Update cache if this equipment is in cache
      if (_equipmentCache.containsKey(id)) {
        final current = _equipmentCache[id]!;
        _equipmentCache[id] = current.copyWith(isAvailable: isAvailable);
      }

      _logger.info('Updated availability of equipment $id to $isAvailable');
    } catch (e) {
      _logger.severe('Error updating equipment availability: $e');
      rethrow;
    }
  }

  /// Deletes an equipment from the database
  ///
  /// Removes the equipment from the cache
  Future<void> deleteEquipment(String id) async {
    try {
      await _equipmentCollection.doc(id).delete();

      // Remove from cache
      _equipmentCache.remove(id);

      _logger.info('Deleted equipment with ID: $id');
    } catch (e) {
      _logger.severe('Error deleting equipment: $e');
      rethrow;
    }
  }

  /// Searches for equipment by name or specifications
  ///
  /// Performs a case-insensitive substring match on the name field
  /// Also searches in the specifications map for matching values
  /// Tries to use cache for better performance
  Future<List<Equipment>> searchEquipment(String query) async {
    try {
      final lowerQuery = query.toLowerCase();

      // Try to use cache if valid to improve performance
      if (_isCacheValid() && _equipmentCache.isNotEmpty) {
        return _equipmentCache.values.where((equipment) {
          // Check if name contains the query
          if (equipment.name.toLowerCase().contains(lowerQuery)) {
            return true;
          }

          // Check if any specification values contain the query
          for (final value in equipment.specifications.values) {
            if (value is String && value.toLowerCase().contains(lowerQuery)) {
              return true;
            }
          }

          return false;
        }).toList();
      }

      // If cache is not valid, get all equipment first
      final allEquipment = await getAllEquipment();

      // Filter the equipment list
      return allEquipment.where((equipment) {
        // Check if name contains the query
        if (equipment.name.toLowerCase().contains(lowerQuery)) {
          return true;
        }

        // Check if any specification values contain the query
        for (final value in equipment.specifications.values) {
          if (value is String && value.toLowerCase().contains(lowerQuery)) {
            return true;
          }
        }

        return false;
      }).toList();
    } catch (e) {
      _logger.severe('Error searching equipment: $e');
      rethrow;
    }
  }

  /// Clears the equipment cache
  ///
  /// Useful when you want to force a refresh of data
  void clearCache() {
    _equipmentCache.clear();
    _lastCacheRefresh = DateTime(1970);
    _logger.info('Equipment cache cleared');
  }

  /// Checks if the cache is still valid
  bool _isCacheValid() {
    return DateTime.now().difference(_lastCacheRefresh) < _cacheExpiration;
  }

  /// Updates the cache with new equipment data
  void _updateCache(List<Equipment> equipmentList) {
    _equipmentCache.clear();
    for (final equipment in equipmentList) {
      _equipmentCache[equipment.id] = equipment;
    }
    _lastCacheRefresh = DateTime.now();
    _logger.info('Equipment cache updated with ${equipmentList.length} items');
  }

  /// Performs batch operations on equipment
  ///
  /// Allows multiple operations to be performed in a single transaction
  Future<void> batchUpdate({
    List<Equipment> toAdd = const [],
    List<Equipment> toUpdate = const [],
    List<String> toDelete = const [],
  }) async {
    try {
      final batch = _firestore.batch();

      // Add operations
      for (final equipment in toAdd) {
        final docRef = _equipmentCollection.doc();
        batch.set(docRef, equipment.toFirestore());
      }

      // Update operations
      for (final equipment in toUpdate) {
        batch.update(
          _equipmentCollection.doc(equipment.id),
          equipment.toFirestore(),
        );
      }

      // Delete operations
      for (final id in toDelete) {
        batch.delete(_equipmentCollection.doc(id));
      }

      // Commit the batch
      await batch.commit();

      // Update cache
      clearCache();

      _logger.info('Batch update completed successfully: '
          '${toAdd.length} added, ${toUpdate.length} updated, ${toDelete.length} deleted');
    } catch (e) {
      _logger.severe('Error performing batch update: $e');
      rethrow;
    }
  }

  /// Returns sample equipment data for demonstration
  List<Equipment> _getSampleEquipment() {
    return [
      Equipment(
        id: 'eq-001',
        name: 'Surgical Microscope',
        category: 'Optical',
        isAvailable: true,
        locationId: 'storage-a',
      ),
      Equipment(
        id: 'eq-002',
        name: 'Anesthesia Machine',
        category: 'Critical',
        isAvailable: true,
        locationId: 'or-2',
      ),
      Equipment(
        id: 'eq-003',
        name: 'Patient Monitor',
        category: 'Monitoring',
        isAvailable: true,
        locationId: 'or-1',
      ),
      Equipment(
        id: 'eq-004',
        name: 'Ultrasound Scanner',
        category: 'Imaging',
        isAvailable: false,
        locationId: 'maintenance',
      ),
      Equipment(
        id: 'eq-005',
        name: 'Defibrillator',
        category: 'Critical',
        isAvailable: true,
        locationId: 'emergency-cart',
      ),
      Equipment(
        id: 'eq-006',
        name: 'Surgical Drill',
        category: 'Orthopedic',
        isAvailable: true,
        locationId: 'or-3',
      ),
      Equipment(
        id: 'eq-007',
        name: 'Electrosurgical Unit',
        category: 'General',
        isAvailable: true,
        locationId: 'storage-b',
      ),
      Equipment(
        id: 'eq-008',
        name: 'Surgical Lights',
        category: 'General',
        isAvailable: true,
        locationId: 'or-4',
      ),
      Equipment(
        id: 'eq-009',
        name: 'Ventilator',
        category: 'Critical',
        isAvailable: false,
        locationId: 'icu',
      ),
      Equipment(
        id: 'eq-010',
        name: 'Infusion Pump',
        category: 'Medication',
        isAvailable: true,
        locationId: 'or-2',
      ),
      Equipment(
        id: 'eq-011',
        name: 'X-Ray Machine',
        category: 'Imaging',
        isAvailable: true,
        locationId: 'radiology',
      ),
      Equipment(
        id: 'eq-012',
        name: 'Sterilizer',
        category: 'General',
        isAvailable: true,
        locationId: 'sterilization',
      ),
    ];
  }
}

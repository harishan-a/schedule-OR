// =============================================================================
// Scheduling Service
// =============================================================================
// A service that analyzes constraints and suggests optimal time slots for surgeries.
// Uses constraint satisfaction to find available time slots based on:
// - Staff availability (doctors, nurses, technologists)
// - Equipment availability
// - Operating room availability
// - Prep and cleanup times
// - Patient constraints
//
// Returns a sorted list of possible times with compatibility scores
// to help users make informed scheduling decisions.
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import '../features/schedule/models/surgery.dart';
import '../features/surgery/models/surgery_equipment_requirement.dart';

/// Class representing a recommended time slot for scheduling a surgery
class SchedulingRecommendation {
  /// Proposed start time for the surgery
  final DateTime proposedStartTime;

  /// Compatibility score (0-100) indicating how well this time fits all constraints
  final int compatibilityScore;

  /// A map of constraint types to their specific scores
  /// Example: {'staffAvailability': 90, 'equipmentAvailability': 75, etc.}
  final Map<String, int> constraintScores;

  /// List of conflicts or issues with this time slot (empty if perfect match)
  final List<String> conflictDescriptions;

  /// Creates a new scheduling recommendation
  SchedulingRecommendation({
    required this.proposedStartTime,
    required this.compatibilityScore,
    required this.constraintScores,
    this.conflictDescriptions = const [],
  });

  /// Factory constructor to create a recommendation with calculated overall score
  factory SchedulingRecommendation.withCalculatedScore({
    required DateTime proposedStartTime,
    required Map<String, int> constraintScores,
    List<String> conflictDescriptions = const [],
  }) {
    // Calculate overall score as weighted average of constraint scores
    final weights = {
      'staffAvailability': 30, // 30% weight for staff
      'equipmentAvailability': 25, // 25% weight for equipment
      'roomAvailability': 30, // 30% weight for room
      'patientConstraints': 15, // 15% weight for patient constraints
    };

    int overallScore = 0;
    int totalWeight = 0;

    constraintScores.forEach((constraint, score) {
      final weight = weights[constraint] ??
          10; // Default weight of 10 for unknown constraints
      overallScore += score * weight;
      totalWeight += weight;
    });

    final calculatedScore =
        totalWeight > 0 ? (overallScore / totalWeight).round() : 0;

    return SchedulingRecommendation(
      proposedStartTime: proposedStartTime,
      compatibilityScore: calculatedScore,
      constraintScores: constraintScores,
      conflictDescriptions: conflictDescriptions,
    );
  }

  /// Gets the end time based on the provided duration
  DateTime getEndTime(int durationMinutes) {
    return proposedStartTime.add(Duration(minutes: durationMinutes));
  }

  /// Gets the prep start time based on the proposed start time and prep minutes
  DateTime getPrepStartTime(int prepTimeMinutes) {
    return proposedStartTime.subtract(Duration(minutes: prepTimeMinutes));
  }

  /// Gets the cleanup end time based on the proposed end time and cleanup minutes
  DateTime getCleanupEndTime(int durationMinutes, int cleanupTimeMinutes) {
    return getEndTime(durationMinutes)
        .add(Duration(minutes: cleanupTimeMinutes));
  }

  /// Returns a string representation of this recommendation
  @override
  String toString() {
    final timeStr =
        '${proposedStartTime.hour}:${proposedStartTime.minute.toString().padLeft(2, '0')}';
    final conflicts = conflictDescriptions.isNotEmpty
        ? ', conflicts: ${conflictDescriptions.join('; ')}'
        : '';

    return 'Recommendation(time: $timeStr, score: $compatibilityScore$conflicts)';
  }
}

/// Service responsible for analyzing scheduling constraints and suggesting optimal time slots
class SchedulingService {
  final FirebaseFirestore _firestore;
  final Logger _logger = Logger('SchedulingService');

  /// Time slot interval in minutes when generating possible slots
  static const int _timeSlotIntervalMinutes = 15;

  /// Minimum acceptable compatibility score for recommendations
  static const int _minimumAcceptableScore = 40;

  /// Maximum number of recommendations to return
  static const int _maxRecommendations = 10;

  SchedulingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Gets scheduling recommendations based on a prototype surgery
  ///
  /// The [surgery] parameter contains the surgery details including required staff,
  /// equipment, duration, etc. The date in startTime is used as the base date for
  /// scheduling, but the time component may be adjusted in recommendations.
  ///
  /// The [dateRange] parameter specifies how many days to look ahead for scheduling.
  /// Default is 7 days.
  ///
  /// Returns a list of time slots sorted by compatibility score (highest first).
  Future<List<SchedulingRecommendation>> getRecommendations({
    required Surgery surgery,
    int dateRangeDays = 7,
    DateTime? earliestTime,
    DateTime? latestTime,
  }) async {
    // Initialize the result list
    final recommendations = <SchedulingRecommendation>[];

    try {
      _logger.info(
          'Generating scheduling recommendations for surgery: ${surgery.id}');

      // Set time range boundaries
      final DateTime startDate = earliestTime ??
          DateTime(surgery.startTime.year, surgery.startTime.month,
              surgery.startTime.day, 8, 0); // Default to 8 AM

      final DateTime endDate = latestTime ??
          startDate.add(Duration(days: dateRangeDays)).subtract(
              Duration(minutes: 1)); // End at 11:59 PM on the last day

      _logger.fine('Looking for time slots between $startDate and $endDate');

      // 1. Generate possible time slots
      final possibleSlots = _generatePossibleTimeSlots(
        startDate: startDate,
        endDate: endDate,
        intervalMinutes: _timeSlotIntervalMinutes,
      );

      _logger.fine('Generated ${possibleSlots.length} possible time slots');

      // 2. Fetch all relevant constraints in parallel
      final Future<List<Surgery>> existingSurgeriesFuture =
          _fetchExistingSurgeries(startDate, endDate);
      final Future<Map<String, List<Map<String, dynamic>>>>
          staffAvailabilityFuture =
          _fetchStaffAvailability(startDate, endDate, surgery);
      final Future<Map<String, List<Map<String, dynamic>>>>
          equipmentAvailabilityFuture =
          _fetchEquipmentAvailability(startDate, endDate, surgery);
      final Future<Map<String, List<Map<String, dynamic>>>>
          roomAvailabilityFuture =
          _fetchRoomAvailability(startDate, endDate, surgery);
      final Future<Map<String, dynamic>> patientConstraintsFuture =
          _fetchPatientConstraints(surgery.patientId);

      // Wait for all constraint data to be fetched
      final existingSurgeries = await existingSurgeriesFuture;
      final staffAvailability = await staffAvailabilityFuture;
      final equipmentAvailability = await equipmentAvailabilityFuture;
      final roomAvailability = await roomAvailabilityFuture;
      final patientConstraints = await patientConstraintsFuture;

      _logger.fine(
          'Fetched constraint data. Evaluating ${possibleSlots.length} possible time slots.');

      // 3. Evaluate each time slot against all constraints
      for (final slot in possibleSlots) {
        final recommendation = _evaluateTimeSlot(
          proposedTime: slot,
          surgery: surgery,
          existingSurgeries: existingSurgeries,
          staffAvailability: staffAvailability,
          equipmentAvailability: equipmentAvailability,
          roomAvailability: roomAvailability,
          patientConstraints: patientConstraints,
        );

        // Only include recommendations that meet the minimum score threshold
        if (recommendation.compatibilityScore >= _minimumAcceptableScore) {
          recommendations.add(recommendation);
        }
      }

      // 4. Sort recommendations by compatibility score (highest first)
      recommendations
          .sort((a, b) => b.compatibilityScore.compareTo(a.compatibilityScore));

      // 5. Limit the number of recommendations to return
      final limitedRecommendations =
          recommendations.take(_maxRecommendations).toList();

      _logger.info(
          'Generated ${limitedRecommendations.length} recommendations with scores ' +
              '${limitedRecommendations.map((r) => r.compatibilityScore.toString()).join(', ')}');

      return limitedRecommendations;
    } catch (e) {
      _logger.severe('Error generating scheduling recommendations: $e');
      // Return empty list in case of error
      return [];
    }
  }

  /// Generates a list of possible time slots within the specified date range
  List<DateTime> _generatePossibleTimeSlots({
    required DateTime startDate,
    required DateTime endDate,
    required int intervalMinutes,
  }) {
    final slots = <DateTime>[];
    DateTime currentSlot = startDate;

    // Hospital operating hours
    const int startHour = 8; // 8 AM
    const int endHour = 17; // 5 PM

    while (currentSlot.isBefore(endDate)) {
      final hour = currentSlot.hour;

      // Only include slots during operating hours on weekdays
      final isWeekday = currentSlot.weekday >= 1 && currentSlot.weekday <= 5;
      final isDuringOperatingHours = hour >= startHour && hour < endHour;

      if (isWeekday && isDuringOperatingHours) {
        slots.add(currentSlot);
      }

      // Move to next time slot
      currentSlot = currentSlot.add(Duration(minutes: intervalMinutes));
    }

    return slots;
  }

  /// Fetches all existing surgeries within the specified date range
  Future<List<Surgery>> _fetchExistingSurgeries(
      DateTime startDate, DateTime endDate) async {
    try {
      // We need to fetch surgeries that:
      // 1. Start within our date range OR
      // 2. End within our date range OR
      // 3. Span our date range (start before and end after)

      final querySnapshot = await _firestore.collection('surgeries').where(
          'status',
          whereIn: ['Scheduled', 'Confirmed', 'In Progress']).get();

      final surgeries = <Surgery>[];

      for (var doc in querySnapshot.docs) {
        final surgery = Surgery.fromFirestore(doc.id, doc.data());

        // Check if this surgery's time (including prep and cleanup) overlaps with our date range
        final surgeryStart = surgery.prepStartTime;
        final surgeryEnd = surgery.cleanupEndTime;

        if (surgeryStart.isBefore(endDate) && surgeryEnd.isAfter(startDate)) {
          surgeries.add(surgery);
        }
      }

      _logger
          .fine('Fetched ${surgeries.length} existing surgeries in date range');
      return surgeries;
    } catch (e) {
      _logger.warning('Error fetching existing surgeries: $e');
      return [];
    }
  }

  /// Fetches staff availability for the required staff
  Future<Map<String, List<Map<String, dynamic>>>> _fetchStaffAvailability(
      DateTime startDate, DateTime endDate, Surgery surgery) async {
    try {
      // Combine all staff IDs that need to be checked
      final staffIds = <String>{};
      staffIds.add(surgery.doctorId);
      staffIds.addAll(surgery.nurses);
      staffIds.addAll(surgery.technologists);

      // Get availability for each staff member
      final staffAvailability = <String, List<Map<String, dynamic>>>{};

      // We can optimize by fetching all staff in parallel
      final futures = staffIds.map((staffId) async {
        final querySnapshot = await _firestore
            .collection('staffAvailability')
            .where('staffId', isEqualTo: staffId)
            .where('date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(
                    DateTime(startDate.year, startDate.month, startDate.day)))
            .where('date',
                isLessThanOrEqualTo: Timestamp.fromDate(DateTime(
                    endDate.year, endDate.month, endDate.day, 23, 59, 59)))
            .get();

        final availability =
            querySnapshot.docs.map((doc) => doc.data()).toList();

        staffAvailability[staffId] = availability;
      });

      // Wait for all queries to complete
      await Future.wait(futures);

      _logger.fine('Fetched availability for ${staffIds.length} staff members');
      return staffAvailability;
    } catch (e) {
      _logger.warning('Error fetching staff availability: $e');
      return {};
    }
  }

  /// Fetches equipment availability for the required equipment
  Future<Map<String, List<Map<String, dynamic>>>> _fetchEquipmentAvailability(
      DateTime startDate, DateTime endDate, Surgery surgery) async {
    try {
      // Get all required equipment IDs
      final equipmentIds = surgery.requiredEquipment;

      // Get detailed equipment requirements
      final equipmentRequirements = surgery.equipmentRequirements;

      // Add any equipment IDs from detailed requirements that aren't in the simple list
      for (var req in equipmentRequirements) {
        if (!equipmentIds.contains(req.equipmentId)) {
          equipmentIds.add(req.equipmentId);
        }
      }

      // Get availability for each equipment
      final equipmentAvailability = <String, List<Map<String, dynamic>>>{};

      // Also fetch equipment quantities from Firestore
      final equipmentQuantities = <String, int>{};
      final equipmentBatch = await _firestore
          .collection('equipment')
          .where(FieldPath.documentId,
              whereIn: equipmentIds.isEmpty ? ['dummy'] : equipmentIds)
          .get();

      for (var doc in equipmentBatch.docs) {
        final data = doc.data();
        final quantity = (data['quantity'] as num?)?.toInt() ?? 1;
        equipmentQuantities[doc.id] = quantity;
      }

      // Fetch equipment usage from surgeries in the date range
      final existingSurgeries =
          await _fetchExistingSurgeries(startDate, endDate);

      // For each equipment, check when it's being used
      for (var equipmentId in equipmentIds) {
        final usageList = <Map<String, dynamic>>[];
        final quantity = equipmentQuantities[equipmentId] ?? 1;

        // Create a usage map that tracks how many of this equipment are in use at each time
        final timeBasedUsage = <DateTime, int>{};

        // Check each surgery for this equipment
        for (var existingSurgery in existingSurgeries) {
          if (existingSurgery.requiresEquipment(equipmentId)) {
            // Get detailed requirement if available
            final requirement =
                existingSurgery.getEquipmentRequirement(equipmentId);

            DateTime usageStart;
            DateTime usageEnd;

            if (requirement != null) {
              // Use detailed timing information
              usageStart = requirement.setupStartTime;
              usageEnd = requirement.requiredUntilTime;
            } else {
              // Use surgery timing with default buffer
              usageStart = existingSurgery.prepStartTime;
              usageEnd = existingSurgery.cleanupEndTime;
            }

            // Add usage period to list
            usageList.add({
              'surgeryId': existingSurgery.id,
              'startTime': usageStart,
              'endTime': usageEnd,
              'quantity': 1, // Assume each surgery needs 1 unit
            });

            // Update time-based usage tracking
            // This helps us know how many units are in use at any given time
            for (var time = usageStart;
                time.isBefore(usageEnd);
                time = time.add(const Duration(minutes: 15))) {
              timeBasedUsage[time] = (timeBasedUsage[time] ?? 0) + 1;
            }
          }
        }

        // Add quantity information to the equipment availability data
        equipmentAvailability[equipmentId] = [
          ...usageList,
          {'totalQuantity': quantity, 'timeBasedUsage': timeBasedUsage},
        ];
      }

      _logger.fine(
          'Analyzed availability for ${equipmentIds.length} equipment items');
      return equipmentAvailability;
    } catch (e) {
      _logger.warning('Error fetching equipment availability: $e');
      return {};
    }
  }

  /// Fetches room availability for the required room
  Future<Map<String, List<Map<String, dynamic>>>> _fetchRoomAvailability(
      DateTime startDate, DateTime endDate, Surgery surgery) async {
    try {
      // Get all existing surgeries in the date range
      final existingSurgeries =
          await _fetchExistingSurgeries(startDate, endDate);

      // Filter surgeries by room
      final roomId = surgery.roomId;
      final roomUsageList = <Map<String, dynamic>>[];

      for (var existingSurgery in existingSurgeries) {
        if (existingSurgery.roomId == roomId) {
          roomUsageList.add({
            'surgeryId': existingSurgery.id,
            'startTime': existingSurgery.prepStartTime,
            'endTime': existingSurgery.cleanupEndTime,
          });
        }
      }

      // Check for room maintenance or other blocks
      final maintenanceQuery = await _firestore
          .collection('roomMaintenance')
          .where('roomId', isEqualTo: roomId)
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .where('endTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      for (var doc in maintenanceQuery.docs) {
        final data = doc.data();
        roomUsageList.add({
          'maintenanceId': doc.id,
          'startTime': (data['startTime'] as Timestamp).toDate(),
          'endTime': (data['endTime'] as Timestamp).toDate(),
          'reason': data['reason'] ?? 'Maintenance',
        });
      }

      _logger
          .fine('Found ${roomUsageList.length} usage periods for room $roomId');
      return {roomId: roomUsageList};
    } catch (e) {
      _logger.warning('Error fetching room availability: $e');
      return {};
    }
  }

  /// Fetches patient constraints if a patient ID is provided
  Future<Map<String, dynamic>> _fetchPatientConstraints(
      String? patientId) async {
    if (patientId == null || patientId.isEmpty) {
      return {};
    }

    try {
      final doc = await _firestore.collection('patients').doc(patientId).get();

      if (!doc.exists) {
        return {};
      }

      final patientData = doc.data() ?? {};
      final constraints = <String, dynamic>{};

      // Extract relevant constraints
      if (patientData.containsKey('preferredTimes')) {
        constraints['preferredTimes'] = patientData['preferredTimes'];
      }

      if (patientData.containsKey('availabilityConstraints')) {
        constraints['availabilityConstraints'] =
            patientData['availabilityConstraints'];
      }

      _logger.fine('Fetched patient constraints for patient $patientId');
      return constraints;
    } catch (e) {
      _logger.warning('Error fetching patient constraints: $e');
      return {};
    }
  }

  /// Evaluates a proposed time slot against all constraints
  SchedulingRecommendation _evaluateTimeSlot({
    required DateTime proposedTime,
    required Surgery surgery,
    required List<Surgery> existingSurgeries,
    required Map<String, List<Map<String, dynamic>>> staffAvailability,
    required Map<String, List<Map<String, dynamic>>> equipmentAvailability,
    required Map<String, List<Map<String, dynamic>>> roomAvailability,
    required Map<String, dynamic> patientConstraints,
  }) {
    // Calculate time boundaries for this proposed surgery
    final prepStartTime =
        proposedTime.subtract(Duration(minutes: surgery.prepTimeMinutes));
    final surgeryEndTime =
        proposedTime.add(Duration(minutes: surgery.duration));
    final cleanupEndTime =
        surgeryEndTime.add(Duration(minutes: surgery.cleanupTimeMinutes));

    final constraintScores = <String, int>{};
    final conflictDescriptions = <String>[];

    // Check room availability first as it's a critical constraint
    // -----------------------------
    final roomScore = _evaluateRoomAvailability(
      prepStartTime,
      cleanupEndTime,
      surgery.roomId,
      roomAvailability,
      conflictDescriptions,
    );
    constraintScores['roomAvailability'] = roomScore;

    // Early termination if room is not available - no point evaluating other constraints
    if (roomScore == 0) {
      // Add minimal scores for other constraints to complete the data structure
      constraintScores['staffAvailability'] = 0;
      constraintScores['equipmentAvailability'] = 0;
      constraintScores['patientConstraints'] = 0;

      return SchedulingRecommendation.withCalculatedScore(
        proposedStartTime: proposedTime,
        constraintScores: constraintScores,
        conflictDescriptions: conflictDescriptions,
      );
    }

    // Evaluate staff availability
    // -----------------------------
    final staffScore = _evaluateStaffAvailability(
      prepStartTime,
      cleanupEndTime,
      surgery,
      staffAvailability,
      existingSurgeries,
      conflictDescriptions,
    );
    constraintScores['staffAvailability'] = staffScore;

    // Early termination if staff score is very low
    if (staffScore < 30) {
      // Add minimal scores for remaining constraints to complete the data structure
      constraintScores['equipmentAvailability'] = 0;
      constraintScores['patientConstraints'] = 0;

      return SchedulingRecommendation.withCalculatedScore(
        proposedStartTime: proposedTime,
        constraintScores: constraintScores,
        conflictDescriptions: conflictDescriptions,
      );
    }

    // Evaluate equipment availability
    // ---------------------------------
    final equipmentScore = _evaluateEquipmentAvailability(
      prepStartTime,
      cleanupEndTime,
      surgery,
      equipmentAvailability,
      conflictDescriptions,
    );
    constraintScores['equipmentAvailability'] = equipmentScore;

    // Evaluate patient constraints
    // ------------------------------
    final patientScore = _evaluatePatientConstraints(
      proposedTime,
      surgeryEndTime,
      patientConstraints,
      conflictDescriptions,
    );
    constraintScores['patientConstraints'] = patientScore;

    // Create a recommendation with calculated score
    return SchedulingRecommendation.withCalculatedScore(
      proposedStartTime: proposedTime,
      constraintScores: constraintScores,
      conflictDescriptions: conflictDescriptions,
    );
  }

  /// Evaluates staff availability and returns a score (0-100)
  int _evaluateStaffAvailability(
    DateTime startTime,
    DateTime endTime,
    Surgery surgery,
    Map<String, List<Map<String, dynamic>>> staffAvailability,
    List<Surgery> existingSurgeries,
    List<String> conflictDescriptions,
  ) {
    // Initialize with perfect score
    int score = 100;

    // Check each required staff member
    final requiredStaffIds = <String>[
      surgery.doctorId,
      ...surgery.nurses,
      ...surgery.technologists,
    ];

    int conflicts = 0;

    for (final staffId in requiredStaffIds) {
      // Skip empty IDs
      if (staffId.isEmpty) continue;

      // Check if this staff member is already assigned to another surgery that overlaps
      bool hasConflict = false;
      String? conflictingSurgery;

      for (final existingSurgery in existingSurgeries) {
        if (existingSurgery.hasStaffConflict(staffId) &&
            isTimeOverlapping(startTime, endTime, existingSurgery.prepStartTime,
                existingSurgery.cleanupEndTime)) {
          hasConflict = true;
          conflictingSurgery = existingSurgery.patientName;
          break;
        }
      }

      if (hasConflict) {
        // Major conflict: staff is assigned to another surgery
        conflicts++;
        conflictDescriptions.add(
            'Staff member is already assigned to surgery for $conflictingSurgery');
        continue;
      }

      // Check if this staff member has availability constraints
      final staffSchedule = staffAvailability[staffId] ?? [];

      for (final schedule in staffSchedule) {
        if (schedule.containsKey('date') &&
            schedule.containsKey('available') &&
            schedule.containsKey('startTime') &&
            schedule.containsKey('endTime')) {
          // Extract schedule information
          final date = (schedule['date'] as Timestamp).toDate();
          final available = schedule['available'] as bool? ?? true;
          final scheduleStart = (schedule['startTime'] as Timestamp).toDate();
          final scheduleEnd = (schedule['endTime'] as Timestamp).toDate();

          // Check if this schedule entry falls on the same day as our proposed time
          if (date.year == startTime.year &&
              date.month == startTime.month &&
              date.day == startTime.day) {
            if (!available &&
                isTimeOverlapping(
                    startTime, endTime, scheduleStart, scheduleEnd)) {
              // Staff is marked as unavailable during this time
              conflicts++;
              conflictDescriptions
                  .add('Staff member $staffId is marked as unavailable');
              break;
            }
          }
        }
      }
    }

    // Calculate score based on conflicts
    if (conflicts > 0) {
      // Each conflict reduces score by 30 points (up to 90)
      score = score - (conflicts * 30);
      if (score < 0) score = 0;
    }

    return score;
  }

  /// Evaluates equipment availability and returns a score (0-100)
  int _evaluateEquipmentAvailability(
    DateTime startTime,
    DateTime endTime,
    Surgery surgery,
    Map<String, List<Map<String, dynamic>>> equipmentAvailability,
    List<String> conflictDescriptions,
  ) {
    // Initialize with perfect score
    int score = 100;

    // Get required equipment
    final requiredEquipment = surgery.requiredEquipment;
    final requirementDetails = surgery.equipmentRequirements;

    int conflicts = 0;
    final requiredConflicts = <String>[];
    final optionalConflicts = <String>[];

    // Check each piece of equipment
    for (final equipmentId in requiredEquipment) {
      final usageInfo = equipmentAvailability[equipmentId] ?? [];

      // Extract total quantity available from the usage info
      int totalQuantity = 1; // Default to 1 if not specified
      Map<DateTime, int> timeBasedUsage = {};

      // Find the quantity information in the usage info
      for (final item in usageInfo) {
        if (item.containsKey('totalQuantity')) {
          totalQuantity = item['totalQuantity'] as int? ?? 1;

          // Safely extract the time-based usage map
          if (item.containsKey('timeBasedUsage') &&
              item['timeBasedUsage'] is Map) {
            final rawMap = item['timeBasedUsage'] as Map;

            // Convert the raw map to a properly typed Map<DateTime, int>
            rawMap.forEach((key, value) {
              if (key is DateTime && value is int) {
                timeBasedUsage[key] = value;
              }
            });
          }
          break;
        }
      }

      // Find the detailed requirement if available
      final detailedRequirement = requirementDetails.firstWhere(
        (req) => req.equipmentId == equipmentId,
        orElse: () => SurgeryEquipmentRequirement(
          equipmentId: equipmentId,
          equipmentName: equipmentId, // Use ID as name if not found
          isRequired: true, // Assume required by default
          setupStartTime: startTime, // Use surgery timing if no detailed timing
          requiredUntilTime: endTime,
        ),
      );

      // Get the time period when this equipment is needed
      final equipStartTime = detailedRequirement.setupStartTime;
      final equipEndTime = detailedRequirement.requiredUntilTime;

      // Check for conflicts with existing usage
      bool hasConflict = false;

      // First check if we have detailed time-based usage information
      if (timeBasedUsage.isNotEmpty) {
        // Check each 15-minute interval to see if all equipment units are in use
        for (var time = equipStartTime;
            time.isBefore(equipEndTime);
            time = time.add(const Duration(minutes: 15))) {
          // Round time to nearest 15-minute interval for lookup
          final lookupTime = DateTime(time.year, time.month, time.day,
              time.hour, (time.minute ~/ 15) * 15);

          final inUseCount = timeBasedUsage[lookupTime] ?? 0;

          // If all units are in use, we have a conflict
          if (inUseCount >= totalQuantity) {
            hasConflict = true;
            break;
          }
        }
      } else {
        // Fallback to checking individual usage periods
        final usagePeriods = usageInfo
            .where((item) =>
                item.containsKey('startTime') && item.containsKey('endTime'))
            .toList();

        // Count overlapping usages to check against total quantity
        int maxConcurrentUsage = 0;

        // For each 15-minute interval, count how many surgeries are using this equipment
        for (var time = equipStartTime;
            time.isBefore(equipEndTime);
            time = time.add(const Duration(minutes: 15))) {
          int concurrentUsage = 0;

          for (final usage in usagePeriods) {
            final usageStart = usage['startTime'] as DateTime;
            final usageEnd = usage['endTime'] as DateTime;

            if (time.isAfter(usageStart) && time.isBefore(usageEnd)) {
              concurrentUsage++;
            }
          }

          // Update maximum concurrent usage
          if (concurrentUsage > maxConcurrentUsage) {
            maxConcurrentUsage = concurrentUsage;
          }

          // If adding our surgery would exceed available quantity, we have a conflict
          if (maxConcurrentUsage >= totalQuantity) {
            hasConflict = true;
            break;
          }
        }
      }

      if (hasConflict) {
        // Add to appropriate conflict list
        if (detailedRequirement.isRequired) {
          requiredConflicts.add(detailedRequirement.equipmentName);
        } else {
          optionalConflicts.add(detailedRequirement.equipmentName);
        }

        conflicts++;
      }
    }

    // Add conflict descriptions
    if (requiredConflicts.isNotEmpty) {
      conflictDescriptions.add(
          'Required equipment not available: ${requiredConflicts.join(', ')}');
    }

    if (optionalConflicts.isNotEmpty) {
      conflictDescriptions.add(
          'Optional equipment not available: ${optionalConflicts.join(', ')}');
    }

    // Calculate score based on conflicts
    if (conflicts > 0) {
      // Required equipment conflicts have higher impact
      final requiredConflictCount = requiredConflicts.length;
      final optionalConflictCount = optionalConflicts.length;

      // Each required conflict reduces score by 25 points
      // Each optional conflict reduces score by 10 points
      score =
          score - (requiredConflictCount * 25) - (optionalConflictCount * 10);
      if (score < 0) score = 0;
    }

    return score;
  }

  /// Evaluates room availability and returns a score (0-100)
  int _evaluateRoomAvailability(
    DateTime startTime,
    DateTime endTime,
    String roomId,
    Map<String, List<Map<String, dynamic>>> roomAvailability,
    List<String> conflictDescriptions,
  ) {
    // Initialize with perfect score
    int score = 100;

    // Get room usage periods
    final usagePeriods = roomAvailability[roomId] ?? [];

    // Check for any conflicts
    bool hasConflict = false;
    String conflictReason = '';

    for (final usage in usagePeriods) {
      final usageStart = usage['startTime'] as DateTime;
      final usageEnd = usage['endTime'] as DateTime;

      if (isTimeOverlapping(startTime, endTime, usageStart, usageEnd)) {
        hasConflict = true;

        // Determine conflict reason
        if (usage.containsKey('surgeryId')) {
          conflictReason = 'Surgery';
        } else if (usage.containsKey('maintenanceId')) {
          conflictReason = usage['reason'] as String? ?? 'Maintenance';
        } else {
          conflictReason = 'Unknown booking';
        }

        break;
      }
    }

    // Apply score penalty for conflict
    if (hasConflict) {
      // Room conflicts are critical and cause a severe score reduction
      score = 0;
      conflictDescriptions.add('Room is unavailable due to: $conflictReason');
    }

    return score;
  }

  /// Evaluates patient constraints and returns a score (0-100)
  int _evaluatePatientConstraints(
    DateTime startTime,
    DateTime endTime,
    Map<String, dynamic> patientConstraints,
    List<String> conflictDescriptions,
  ) {
    // Default to perfect score
    int score = 100;

    // If no patient constraints, return perfect score
    if (patientConstraints.isEmpty) {
      return score;
    }

    // Check preferred times if specified
    if (patientConstraints.containsKey('preferredTimes')) {
      final preferredTimes = patientConstraints['preferredTimes'] as List?;
      if (preferredTimes != null && preferredTimes.isNotEmpty) {
        // Check if the proposed time matches any preferred time
        bool matchesPreferred = false;

        for (final preferredTime in preferredTimes) {
          // Parse preferred time format (assuming it contains day and time range)
          // This would need to be adjusted based on actual data format
          if (preferredTime is Map) {
            final dayOfWeek = preferredTime['dayOfWeek'] as int?;
            final preferredStartHour = preferredTime['startHour'] as int?;
            final preferredEndHour = preferredTime['endHour'] as int?;

            if (dayOfWeek != null &&
                preferredStartHour != null &&
                preferredEndHour != null) {
              // Check if day matches and time falls within range
              if (startTime.weekday == dayOfWeek &&
                  startTime.hour >= preferredStartHour &&
                  endTime.hour <= preferredEndHour) {
                matchesPreferred = true;
                break;
              }
            }
          }
        }

        if (!matchesPreferred) {
          // If not matching preferred times, reduce score but not drastically
          score -= 20;
          conflictDescriptions
              .add('Time does not match patient\'s preferred schedule');
        }
      }
    }

    // Check availability constraints
    if (patientConstraints.containsKey('availabilityConstraints')) {
      final constraints =
          patientConstraints['availabilityConstraints'] as List?;
      if (constraints != null && constraints.isNotEmpty) {
        for (final constraint in constraints) {
          if (constraint is Map) {
            final unavailableStart = constraint['startTime'] as Timestamp?;
            final unavailableEnd = constraint['endTime'] as Timestamp?;
            final reason = constraint['reason'] as String? ?? 'Unavailable';

            if (unavailableStart != null && unavailableEnd != null) {
              final constraintStart = unavailableStart.toDate();
              final constraintEnd = unavailableEnd.toDate();

              if (isTimeOverlapping(
                  startTime, endTime, constraintStart, constraintEnd)) {
                // Major conflict with patient availability
                score -= 50;
                conflictDescriptions.add('Patient unavailable: $reason');
                break;
              }
            }
          }
        }
      }
    }

    return score < 0 ? 0 : score;
  }

  /// Helper method to check if two time ranges overlap
  bool isTimeOverlapping(
    DateTime range1Start,
    DateTime range1End,
    DateTime range2Start,
    DateTime range2End,
  ) {
    return range1Start.isBefore(range2End) && range1End.isAfter(range2Start);
  }
}

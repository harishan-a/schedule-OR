import 'package:logging/logging.dart';

/// Checks availability of various OR resources.
/// Extracted from ResourceCheckService.
///
/// This is a skeleton that will be fully implemented in Wave 3.
class ResourceChecker {
  final _logger = Logger('ResourceChecker');

  /// Check availability of all resources for a proposed time range
  Future<ResourceAvailabilityResult> checkAllResources({
    required DateTime startTime,
    required DateTime endTime,
    String? roomId,
    String? surgeonId,
    List<String> nurseIds = const [],
    String? technologistId,
  }) async {
    _logger.info('Checking all resources for $startTime - $endTime');
    // Will be fully implemented in Wave 3
    return ResourceAvailabilityResult(
      conflicts: [],
      futureBookings: [],
    );
  }

  /// Get all future bookings for a specific resource
  Future<List<Map<String, dynamic>>> getFutureBookings({
    required String resourceType,
    required String resourceId,
    DateTime? afterDate,
  }) async {
    _logger.info('Getting future bookings for $resourceType: $resourceId');
    // Will be fully implemented in Wave 3
    return [];
  }
}

/// Result of a resource availability check
class ResourceAvailabilityResult {
  final List<String> conflicts;
  final List<Map<String, dynamic>> futureBookings;

  bool get hasConflicts => conflicts.isNotEmpty;

  const ResourceAvailabilityResult({
    required this.conflicts,
    required this.futureBookings,
  });
}

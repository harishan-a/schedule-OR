// =============================================================================
// User Statistics Model
// =============================================================================
// A data model that tracks a user's surgery-related statistics, including:
// - Number of scheduled surgeries
// - Number of completed surgeries
// - Number of cancelled surgeries
// - Number of surgeries in progress
//
// This model is used for:
// - Dashboard statistics display
// - User activity tracking
// - Performance metrics
//
// Note: Future improvements could include:
// - Additional statistics (e.g., success rate, average duration)
// - Serialization methods for persistence
// - Time-based filtering (daily, weekly, monthly stats)
// =============================================================================

/// Represents a collection of surgery-related statistics for a user
class UserStats {
  /// Number of surgeries scheduled for the future
  final int scheduledSurgeries;

  /// Number of successfully completed surgeries
  final int completedSurgeries;

  /// Number of cancelled or terminated surgeries
  final int cancelledSurgeries;

  /// Number of surgeries currently in progress
  final int inProgressSurgeries;

  /// Creates a new user statistics instance
  ///
  /// All parameters are required and should be non-negative integers.
  /// Used when loading actual statistics from the data source.
  const UserStats({
    required this.scheduledSurgeries,
    required this.completedSurgeries,
    required this.cancelledSurgeries,
    required this.inProgressSurgeries,
  });

  /// Creates an empty statistics instance with all values set to zero
  ///
  /// Used as a fallback when data is not available or during initialization.
  factory UserStats.empty() {
    return const UserStats(
      scheduledSurgeries: 0,
      completedSurgeries: 0,
      cancelledSurgeries: 0,
      inProgressSurgeries: 0,
    );
  }

  // TODO: Consider adding these helper methods in future updates:
  // - copyWith() for immutable updates
  // - operator + for combining stats
  // - toString() for debugging
  // - toJson()/fromJson() for serialization
  // - validate() for data validation
  // - getTotal() for total surgery count
  // - getSuccessRate() for completion percentage
}

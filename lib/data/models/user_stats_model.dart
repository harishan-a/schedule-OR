/// User surgery statistics with helper methods (fixes TODO).
class UserStats {
  final int scheduledSurgeries;
  final int completedSurgeries;
  final int cancelledSurgeries;
  final int inProgressSurgeries;

  const UserStats({
    required this.scheduledSurgeries,
    required this.completedSurgeries,
    required this.cancelledSurgeries,
    required this.inProgressSurgeries,
  });

  factory UserStats.empty() {
    return const UserStats(
      scheduledSurgeries: 0,
      completedSurgeries: 0,
      cancelledSurgeries: 0,
      inProgressSurgeries: 0,
    );
  }

  /// Total number of all surgeries (was TODO)
  int get totalSurgeries =>
      scheduledSurgeries +
      completedSurgeries +
      cancelledSurgeries +
      inProgressSurgeries;

  /// Completion rate as a percentage (was TODO)
  double get successRate {
    if (totalSurgeries == 0) return 0.0;
    return (completedSurgeries / totalSurgeries) * 100;
  }

  /// Creates a copy with modified fields (was TODO)
  UserStats copyWith({
    int? scheduledSurgeries,
    int? completedSurgeries,
    int? cancelledSurgeries,
    int? inProgressSurgeries,
  }) {
    return UserStats(
      scheduledSurgeries: scheduledSurgeries ?? this.scheduledSurgeries,
      completedSurgeries: completedSurgeries ?? this.completedSurgeries,
      cancelledSurgeries: cancelledSurgeries ?? this.cancelledSurgeries,
      inProgressSurgeries: inProgressSurgeries ?? this.inProgressSurgeries,
    );
  }

  /// Combine two UserStats (was TODO)
  UserStats operator +(UserStats other) {
    return UserStats(
      scheduledSurgeries: scheduledSurgeries + other.scheduledSurgeries,
      completedSurgeries: completedSurgeries + other.completedSurgeries,
      cancelledSurgeries: cancelledSurgeries + other.cancelledSurgeries,
      inProgressSurgeries: inProgressSurgeries + other.inProgressSurgeries,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scheduledSurgeries': scheduledSurgeries,
      'completedSurgeries': completedSurgeries,
      'cancelledSurgeries': cancelledSurgeries,
      'inProgressSurgeries': inProgressSurgeries,
    };
  }

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      scheduledSurgeries: json['scheduledSurgeries'] as int? ?? 0,
      completedSurgeries: json['completedSurgeries'] as int? ?? 0,
      cancelledSurgeries: json['cancelledSurgeries'] as int? ?? 0,
      inProgressSurgeries: json['inProgressSurgeries'] as int? ?? 0,
    );
  }

  @override
  String toString() {
    return 'UserStats(scheduled: $scheduledSurgeries, completed: $completedSurgeries, '
        'cancelled: $cancelledSurgeries, inProgress: $inProgressSurgeries, '
        'total: $totalSurgeries, successRate: ${successRate.toStringAsFixed(1)}%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserStats &&
        other.scheduledSurgeries == scheduledSurgeries &&
        other.completedSurgeries == completedSurgeries &&
        other.cancelledSurgeries == cancelledSurgeries &&
        other.inProgressSurgeries == inProgressSurgeries;
  }

  @override
  int get hashCode =>
      scheduledSurgeries.hashCode ^
      completedSurgeries.hashCode ^
      cancelledSurgeries.hashCode ^
      inProgressSurgeries.hashCode;
}

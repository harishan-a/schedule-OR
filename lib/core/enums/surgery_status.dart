import 'package:flutter/material.dart';

enum SurgeryStatus {
  scheduled('Scheduled', Colors.blue, Icons.schedule),
  inProgress('In Progress', Colors.orange, Icons.play_circle_outline),
  completed('Completed', Colors.green, Icons.check_circle_outline),
  cancelled('Cancelled', Colors.red, Icons.cancel_outlined);

  const SurgeryStatus(this.displayName, this.color, this.icon);

  final String displayName;
  final Color color;
  final IconData icon;

  static SurgeryStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return SurgeryStatus.scheduled;
      case 'in progress':
        return SurgeryStatus.inProgress;
      case 'completed':
        return SurgeryStatus.completed;
      case 'cancelled':
        return SurgeryStatus.cancelled;
      default:
        return SurgeryStatus.scheduled;
    }
  }

  /// Get color for a status string without converting to enum
  static Color colorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'in progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

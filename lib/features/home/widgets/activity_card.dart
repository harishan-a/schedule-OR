// =============================================================================
// Activity Card Widget
// =============================================================================
// A customizable card widget that displays surgery activity information with:
// - Status-based color coding and icons
// - Interactive tap behavior
// - Consistent styling with the app's design system
// - Responsive layout for different screen sizes
//
// The card shows:
// - Surgery type and status
// - Timestamp information
// - Room assignment
// - Surgeon details
//
// Usage:
// ```dart
// ActivityCard(
//   surgery: surgerySummary,
//   onTap: () => handleTap(),
// )
// ```
// =============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/surgery_summary.dart';

/// A card widget that displays surgery activity information with status-based
/// styling and interactive behavior.
class ActivityCard extends StatelessWidget {
  /// The surgery data to display in the card
  final SurgerySummary surgery;
  
  /// Optional callback for when the card is tapped
  final VoidCallback? onTap;

  /// Creates an activity card with surgery information
  /// 
  /// The [surgery] parameter must not be null and contains all the
  /// information to be displayed in the card.
  const ActivityCard({
    super.key,
    required this.surgery,
    this.onTap,
  });

  /// Returns the appropriate color for the given surgery status
  /// Used for status indicators and accents throughout the card
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;    // Upcoming surgery
      case 'in progress':
        return Colors.orange;  // Currently active
      case 'completed':
        return Colors.green;   // Successfully finished
      case 'cancelled':
        return Colors.red;     // Cancelled or terminated
      default:
        return Colors.grey;    // Unknown or undefined status
    }
  }

  /// Returns the appropriate icon for the given surgery status
  /// Provides visual indicators matching the status color
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Icons.schedule;      // Clock icon for upcoming
      case 'in progress':
        return Icons.sync;          // Rotating arrows for active
      case 'completed':
        return Icons.check_circle;  // Checkmark for completed
      case 'cancelled':
        return Icons.cancel;        // X mark for cancelled
      default:
        return Icons.info;          // Info icon for unknown status
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(surgery.status);
    final statusIcon = _getStatusIcon(surgery.status);

    // Card with consistent border radius and subtle elevation
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with surgery type and status
              Row(
                children: [
                  Icon(statusIcon, color: statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      surgery.surgeryType,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Status indicator chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      surgery.status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Time information row
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM d, y - h:mm a').format(surgery.startTime),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Room information row
              Row(
                children: [
                  const Icon(Icons.room, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    surgery.room,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Surgeon information row
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Dr. ${surgery.surgeon}',
                      style: const TextStyle(color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

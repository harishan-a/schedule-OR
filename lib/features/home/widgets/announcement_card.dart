// =============================================================================
// Announcement Card Widget
// =============================================================================
// A customizable card widget that displays announcements with:
// - Priority-based color coding and icons
// - Visual hierarchy for announcement content
// - Gradient background effects
// - Consistent styling with the app's design system
//
// The card shows:
// - Announcement title and message
// - Priority level indicator
// - Timestamp information
//
// Usage:
// ```dart
// AnnouncementCard(
//   title: 'Important Update',
//   message: 'System maintenance scheduled',
//   timestamp: Timestamp.now(),
//   priority: 'high',
// )
// ```
// =============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A card widget that displays announcements with priority-based styling
/// and visual hierarchy for important information.
class AnnouncementCard extends StatelessWidget {
  /// The title of the announcement
  final String title;

  /// The main message content
  final String message;

  /// Timestamp when the announcement was created
  final Timestamp timestamp;

  /// Priority level of the announcement ('high', 'medium', 'low')
  final String priority;

  /// Creates an announcement card
  ///
  /// All parameters are required and must not be null.
  /// The [priority] parameter should be one of: 'high', 'medium', 'low'
  const AnnouncementCard({
    super.key,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.priority,
  });

  /// Returns the appropriate color based on announcement priority
  /// Used for priority indicators and accents throughout the card
  Color _getPriorityColor() {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red; // Critical announcements
      case 'medium':
        return Colors.orange; // Important but not critical
      case 'low':
        return Colors.blue; // Informational updates
      default:
        return Colors.grey; // Default for unknown priority
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getPriorityColor();
    final date = DateFormat('MMM d, y').format(timestamp.toDate());

    // Card with consistent border radius and subtle elevation
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          // Subtle gradient background for visual interest
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with title and priority indicator
              Row(
                children: [
                  Icon(Icons.announcement, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Priority indicator chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      priority.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Main message content
              Text(
                message,
                style: TextStyle(
                  color: Colors.grey[700],
                  height: 1.5, // Improved readability for longer text
                ),
              ),
              const SizedBox(height: 8),
              // Timestamp footer
              Text(
                date,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

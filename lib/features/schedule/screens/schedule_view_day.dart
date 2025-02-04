// =============================================================================
// Schedule Day View
// =============================================================================
// A widget that displays surgeries scheduled for the current day, organized by:
// - In Progress surgeries (highlighted)
// - Upcoming surgeries (chronologically ordered)
// - Completed surgeries
//
// Layout Features:
// - CustomScrollView with sliver-based sections
// - Status-based color coding
// - Collapsible surgery details
// - Empty state handling
//
// Note: Some utility functions (e.g., status color mapping) are duplicated
// across views for maintainability. Consider extracting to a shared utility
// in future updates.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_orscheduler/features/schedule/models/surgery.dart';

/// Displays a list of surgeries for the current day, organized by status
class DayListView extends StatelessWidget {
  /// List of all surgeries to be filtered and displayed
  final List<Surgery> surgeries;

  const DayListView({
    super.key,
    required this.surgeries,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    
    // Filter surgeries for today's date only
    final todaySurgeries = surgeries.where((surgery) {
      final surgeryDate = surgery.startTime;
      return surgeryDate.year == now.year &&
          surgeryDate.month == now.month &&
          surgeryDate.day == now.day;
    }).toList();

    // Organize surgeries by status for display sections
    final inProgressSurgeries = todaySurgeries
        .where((s) => s.status.toLowerCase() == 'in progress')
        .toList();
    final upcomingSurgeries = todaySurgeries
        .where((s) => s.status.toLowerCase() == 'scheduled')
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final completedSurgeries = todaySurgeries
        .where((s) => s.status.toLowerCase() == 'completed')
        .toList();

    return CustomScrollView(
      slivers: [
        // Date header with current date in formatted style
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Text(
              DateFormat('EEEE, MMMM d').format(now),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),

        // In Progress surgeries section - highlighted and elevated
        if (inProgressSurgeries.isNotEmpty) ...[
          _buildSectionHeader('In Progress'),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSurgeryCard(
                context,
                inProgressSurgeries[index],
                isInProgress: true,
              ),
              childCount: inProgressSurgeries.length,
            ),
          ),
        ],

        // Upcoming surgeries section - chronologically ordered
        if (upcomingSurgeries.isNotEmpty) ...[
          _buildSectionHeader('Upcoming'),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSurgeryCard(
                context,
                upcomingSurgeries[index],
              ),
              childCount: upcomingSurgeries.length,
            ),
          ),
        ],

        // Completed surgeries section - with strikethrough styling
        if (completedSurgeries.isNotEmpty) ...[
          _buildSectionHeader('Completed'),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSurgeryCard(
                context,
                completedSurgeries[index],
                isCompleted: true,
              ),
              childCount: completedSurgeries.length,
            ),
          ),
        ],

        // Empty state display when no surgeries are scheduled
        if (todaySurgeries.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No surgeries scheduled for today',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Builds a section header with consistent styling
  /// 
  /// Parameters:
  /// - title: The section title to display
  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Builds a card displaying surgery information
  /// 
  /// Parameters:
  /// - context: Build context for theme access
  /// - surgery: Surgery data to display
  /// - isInProgress: Whether to highlight as in-progress
  /// - isCompleted: Whether to apply completed styling
  Widget _buildSurgeryCard(
    BuildContext context,
    Surgery surgery, {
    bool isInProgress = false,
    bool isCompleted = false,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isInProgress ? 4 : 1, // Higher elevation for in-progress
      child: Container(
        decoration: BoxDecoration(
          border: isInProgress
              ? Border.all(
                  color: _getStatusColor(surgery.status),
                  width: 2,
                )
              : null,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  surgery.surgeryType,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
              ),
              // Status indicator chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(surgery.status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  surgery.status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Time range display
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 16, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 4),
                  Text(
                    '${DateFormat('h:mm a').format(surgery.startTime)} - ${DateFormat('h:mm a').format(surgery.endTime)}',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Room information
              Row(
                children: [
                  Icon(Icons.meeting_room,
                      size: 16, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Room ${surgery.room.join(", ")}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Surgeon information
              Row(
                children: [
                  Icon(Icons.person,
                      size: 16, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Dr. ${surgery.surgeon}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
          onTap: () => _showSurgeryDetails(context, surgery),
        ),
      ),
    );
  }

  /// Maps surgery status to color for visual indication
  /// Note: This is duplicated across views for maintainability
  Color _getStatusColor(String status) {
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

  /// Shows a modal bottom sheet with detailed surgery information
  void _showSurgeryDetails(BuildContext context, Surgery surgery) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Surgery title
            Text(
              surgery.surgeryType,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            // Core surgery details
            _buildDetailRow(context, Icons.person, 'Patient: ${surgery.patientName}'),
            _buildDetailRow(context, Icons.medical_services, 'Surgeon: Dr. ${surgery.surgeon}'),
            _buildDetailRow(context, Icons.access_time, 'Time: ${DateFormat('h:mm a').format(surgery.startTime)} - ${DateFormat('h:mm a').format(surgery.endTime)}'),
            _buildDetailRow(context, Icons.timer, 'Duration: ${surgery.duration} minutes'),
            _buildDetailRow(context, Icons.meeting_room, 'Room: ${surgery.room.join(", ")}'),
            // Optional staff details
            if (surgery.nurses.isNotEmpty)
              _buildDetailRow(context, Icons.people, 'Nurses: ${surgery.nurses.join(", ")}'),
            if (surgery.technologists.isNotEmpty)
              _buildDetailRow(context, Icons.engineering, 'Technologists: ${surgery.technologists.join(", ")}'),
            // Optional notes section
            if (surgery.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Notes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(surgery.notes),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds a consistent detail row for the modal sheet
  Widget _buildDetailRow(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
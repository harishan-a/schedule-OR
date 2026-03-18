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
import 'package:firebase_orscheduler/features/surgery/utils/surgery_detail_utils.dart';

/// Displays a list of surgeries for the current day, organized by status
class DayListView extends StatelessWidget {
  /// List of all surgeries to be filtered and displayed
  final List<Surgery> surgeries;

  /// The date to focus on, allowing navigation between days
  final DateTime focusedDate;

  const DayListView({
    super.key,
    required this.surgeries,
    required this.focusedDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter surgeries for the focused date
    final focusedDateSurgeries = surgeries.where((surgery) {
      final surgeryDate = surgery.startTime;
      return surgeryDate.year == focusedDate.year &&
          surgeryDate.month == focusedDate.month &&
          surgeryDate.day == focusedDate.day;
    }).toList();

    // Organize surgeries by status for display sections
    final inProgressSurgeries = focusedDateSurgeries
        .where((s) => s.status.toLowerCase() == 'in progress')
        .toList();
    final upcomingSurgeries = focusedDateSurgeries
        .where((s) => s.status.toLowerCase() == 'scheduled')
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final completedSurgeries = focusedDateSurgeries
        .where((s) => s.status.toLowerCase() == 'completed')
        .toList();

    return CustomScrollView(
      slivers: [
        // Date header with current date in formatted style
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.primary.withOpacity(0.15),
                  theme.colorScheme.primary.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE').format(focusedDate),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  DateFormat('MMMM d, y').format(focusedDate),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatusCounter(
                        'In Progress',
                        inProgressSurgeries.length,
                        Colors.orange.shade600,
                        Icons.directions_run),
                    const SizedBox(width: 12),
                    _buildStatusCounter('Upcoming', upcomingSurgeries.length,
                        Colors.blue.shade600, Icons.upcoming),
                    const SizedBox(width: 12),
                    _buildStatusCounter('Completed', completedSurgeries.length,
                        Colors.green.shade600, Icons.check_circle),
                  ],
                ),
              ],
            ),
          ),
        ),

        // In Progress surgeries section - highlighted and elevated
        if (inProgressSurgeries.isNotEmpty) ...[
          _buildSectionHeader(
              'In Progress', Icons.directions_run, Colors.orange.shade600),
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
          _buildSectionHeader('Upcoming', Icons.upcoming, Colors.blue.shade600),
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
          _buildSectionHeader(
              'Completed', Icons.check_circle, Colors.green.shade600),
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
        if (focusedDateSurgeries.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.event_busy,
                        size: 64,
                        color: theme.colorScheme.primary.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No surgeries scheduled for today',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'There are no procedures on the schedule for ${DateFormat('EEEE, MMMM d').format(focusedDate)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/add-surgery');
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Schedule a Surgery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Builds a status counter chip with icon and count
  Widget _buildStatusCounter(
      String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: color,
                    ),
                  ),
                  SizedBox(
                    height: 12,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: color.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  /// Builds a section header with consistent styling
  ///
  /// Parameters:
  /// - title: The section title to display
  /// - icon: Icon to display next to title
  /// - color: Accent color for the header
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
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
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(surgery.status);
    final isPastDue = surgery.startTime.isBefore(DateTime.now()) &&
        surgery.status.toLowerCase() == 'scheduled';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        elevation: isInProgress ? 4 : 1,
        child: InkWell(
          onTap: () => _showSurgeryDetails(context, surgery),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isInProgress
                    ? statusColor
                    : theme.colorScheme.outline.withOpacity(0.2),
                width: isInProgress ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Status indicator bar
                Container(
                  width: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: Surgery type and status
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                surgery.surgeryType,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  color: isCompleted
                                      ? theme.colorScheme.onSurface
                                          .withOpacity(0.7)
                                      : theme.colorScheme.onSurface,
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
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: statusColor, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    surgery.status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Time range display
                        Wrap(
                          spacing: 6, // horizontal space between items
                          runSpacing: 4, // vertical space between lines
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Icon(Icons.access_time,
                                size: 16,
                                color:
                                    theme.colorScheme.primary.withOpacity(0.7)),
                            Text(
                              '${DateFormat('h:mm a').format(surgery.startTime)} - ${DateFormat('h:mm a').format(surgery.endTime)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.8),
                              ),
                            ),
                            if (isPastDue)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning,
                                        size: 12, color: Colors.red.shade700),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Delayed',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Room and Surgeon info
                        Wrap(
                          spacing: 12, // horizontal space between items
                          runSpacing: 8, // vertical space between lines
                          children: [
                            // Room information
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.meeting_room,
                                    size: 16,
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.7)),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Room ${surgery.room.join(", ")}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.8),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            // Surgeon information
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person,
                                    size: 16,
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.7)),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Dr. ${surgery.surgeon}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.8),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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

  /// Shows surgery details using the unified approach
  void _showSurgeryDetails(BuildContext context, Surgery surgery) {
    showSurgeryDetailBottomSheet(context, surgery.id);
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

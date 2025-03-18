// =============================================================================
// Schedule TV View
// =============================================================================
// A widget that displays surgeries in a TV-optimized layout with:
// - Landscape orientation enforcement
// - Split view (calendar + status panels)
// - Real-time surgery status tracking
// - Interactive surgery details
//
// Layout Features:
// - 2/3 calendar, 1/3 status panels
// - Color-coded status sections
// - Responsive design for large displays
// - Touch-enabled interaction
//
// Note: Status color mapping is duplicated across views for maintainability.
// Consider extracting to a shared utility in future updates.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/surgery.dart';
import 'schedule_view_week.dart';
import '../../../features/schedule/screens/surgery_details.dart';

/// Displays surgeries in a TV-optimized layout with split view
class TVViewContent extends StatefulWidget {
  /// List of surgeries to display in both calendar and status panels
  final List<Surgery> surgeries;
  
  /// The date to focus on, allows navigation between days
  final DateTime focusedDate;

  const TVViewContent({
    super.key, 
    required this.surgeries,
    required this.focusedDate,
  });

  @override
  _TVViewContentState createState() => _TVViewContentState();
}

class _TVViewContentState extends State<TVViewContent> {
  @override
  void initState() {
    super.initState();
    // Force landscape orientation for TV display
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  @override
  void didUpdateWidget(TVViewContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Force refresh when focusedDate changes
    if (widget.focusedDate != oldWidget.focusedDate) {
      setState(() {
        // State update to trigger rebuild
      });
    }
  }

  @override
  void dispose() {
    // Reset orientation constraints when view is disposed
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todaySurgeries = _getTodaySurgeries();
    final inProgressSurgeries = _getInProgressSurgeries();
    final upcomingSurgeries = _getUpcomingSurgeries();
    final theme = Theme.of(context);

    return Row(
      children: [
        // Main calendar section (2/3 width)
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: WeekViewContent(
              surgeries: widget.surgeries,
              focusedDate: widget.focusedDate,
            ),
          ),
        ),
        // Status panels section (1/3 width)
        Expanded(
          child: Container(
            color: theme.colorScheme.surface.withOpacity(0.95),
            child: Column(
              children: [
                // Header for status panel
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    border: Border(
                      bottom: BorderSide(color: theme.colorScheme.primary.withOpacity(0.1), width: 1.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.monitor, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Status Dashboard',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                // In Progress surgeries panel
                _buildTVSection(
                  'In Progress',
                  inProgressSurgeries,
                  headerColor: Colors.orange.shade600,
                  icon: Icons.directions_run,
                  isExpanded: false,
                ),
                // Upcoming surgeries panel (next 3)
                _buildTVSection(
                  'Up Next',
                  upcomingSurgeries.take(3).toList(),
                  headerColor: Colors.blue.shade600,
                  icon: Icons.upcoming,
                  isExpanded: false,
                ),
                // Today's schedule panel
                Expanded(
                  child: _buildTVSection(
                    'Today\'s Schedule',
                    todaySurgeries,
                    headerColor: Colors.green.shade600,
                    icon: Icons.today,
                    isExpanded: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a section in the status panel with header and surgery list
  /// 
  /// Parameters:
  /// - title: Section header text
  /// - surgeries: List of surgeries for this section
  /// - headerColor: Color for the section header
  /// - icon: Icon to display in the header
  /// - isExpanded: Whether the section should expand to fill available space
  Widget _buildTVSection(
    String title,
    List<Surgery> surgeries, {
    required Color headerColor,
    IconData icon = Icons.circle,
    bool isExpanded = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header with consistent styling
        Container(
          decoration: BoxDecoration(
            color: headerColor,
            boxShadow: [
              BoxShadow(
                color: headerColor.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${surgeries.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Scrollable surgery list
        if (isExpanded)
          Expanded(
            child: _buildSurgeryList(surgeries),
          )
        else
          SizedBox(
            height: 140, // Slightly taller for better visibility
            child: _buildSurgeryList(surgeries),
          ),
      ],
    );
  }

  /// Builds a surgery list widget
  Widget _buildSurgeryList(List<Surgery> surgeries) {
    final theme = Theme.of(context);
    
    return surgeries.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 32, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  'No surgeries',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: surgeries.length,
            itemBuilder: (context, index) {
              final surgery = surgeries[index];
              return TVSurgeryCard(
                surgery: surgery,
                theme: theme,
              );
            },
          );
  }

  /// Filters surgeries to show only today's procedures
  List<Surgery> _getTodaySurgeries() {
    return widget.surgeries.where((surgery) {
      return surgery.startTime.year == widget.focusedDate.year &&
          surgery.startTime.month == widget.focusedDate.month &&
          surgery.startTime.day == widget.focusedDate.day;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// Filters surgeries to show only those in progress
  List<Surgery> _getInProgressSurgeries() {
    return widget.surgeries
        .where((surgery) => surgery.status.toLowerCase() == 'in progress')
        .toList();
  }

  /// Filters and sorts upcoming surgeries
  List<Surgery> _getUpcomingSurgeries() {
    return widget.surgeries
        .where((surgery) => 
            surgery.startTime.isAfter(widget.focusedDate) &&
            surgery.status.toLowerCase() == 'scheduled')
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }
}

/// Card widget for displaying surgery information in TV view
class TVSurgeryCard extends StatelessWidget {
  /// Surgery to display in the card
  final Surgery surgery;
  final ThemeData theme;

  const TVSurgeryCard({
    super.key, 
    required this.surgery,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(surgery.status);
    final isPastDue = surgery.startTime.isBefore(DateTime.now()) && 
                      surgery.status.toLowerCase() == 'scheduled';
    
    return InkWell(
      onTap: () => _showSurgeryDetails(context, surgery),
      child: Card(
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isPastDue ? Colors.red.shade300 : Colors.transparent,
            width: isPastDue ? 1.5 : 0,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: statusColor,
                width: 6,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Surgery type and status header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        surgery.surgeryType,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: theme.colorScheme.onSurface,
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
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor, width: 1),
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
                const SizedBox(height: 8),
                // Time information with improved styling
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: theme.colorScheme.primary.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(
                      '${DateFormat('h:mm a').format(surgery.startTime)} - '
                      '${DateFormat('h:mm a').format(surgery.endTime)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                    if (isPastDue) 
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning, size: 12, color: Colors.red.shade700),
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
                const SizedBox(height: 4),
                // Room information
                Row(
                  children: [
                    Icon(Icons.room, size: 16, color: theme.colorScheme.primary.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(
                      'Room ${surgery.room.join(", ")}',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Surgeon information
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: theme.colorScheme.primary.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(
                      'Dr. ${surgery.surgeon}',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shows detailed surgery information in a modal bottom sheet
  void _showSurgeryDetails(BuildContext context, Surgery surgery) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, controller) => SurgeryDetails(
          surgery: surgery,
          scrollController: controller,
        ),
      ),
    );
  }

  /// Maps surgery status to color for visual indication
  /// Note: This is duplicated across views for maintainability
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue.shade600;
      case 'in progress':
        return Colors.orange.shade600;
      case 'completed':
        return Colors.green.shade600;
      case 'cancelled':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
}

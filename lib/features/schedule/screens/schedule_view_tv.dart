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

  const TVViewContent({super.key, required this.surgeries});

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

    return Row(
      children: [
        // Main calendar section (2/3 width)
        Expanded(
          flex: 2,
          child: WeekViewContent(surgeries: widget.surgeries),
        ),
        // Status panels section (1/3 width)
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                left: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              children: [
                // In Progress surgeries panel
                _buildTVSection(
                  'In Progress',
                  inProgressSurgeries,
                  headerColor: Colors.orange,
                ),
                // Upcoming surgeries panel (next 3)
                _buildTVSection(
                  'Up Next',
                  upcomingSurgeries.take(3).toList(),
                  headerColor: Colors.blue,
                ),
                // Today's schedule panel
                Expanded(
                  child: _buildTVSection(
                    'Today\'s Schedule',
                    todaySurgeries,
                    headerColor: Colors.green,
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
  Widget _buildTVSection(
    String title,
    List<Surgery> surgeries, {
    required Color headerColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header with consistent styling
        Container(
          color: headerColor,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Scrollable surgery list
        Expanded(
          child: ListView.builder(
            itemCount: surgeries.length,
            itemBuilder: (context, index) {
              final surgery = surgeries[index];
              return TVSurgeryCard(surgery: surgery);
            },
          ),
        ),
      ],
    );
  }

  /// Filters surgeries to show only today's procedures
  List<Surgery> _getTodaySurgeries() {
    final now = DateTime.now();
    return widget.surgeries.where((surgery) {
      return surgery.startTime.year == now.year &&
          surgery.startTime.month == now.month &&
          surgery.startTime.day == now.day;
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
    final now = DateTime.now();
    return widget.surgeries
        .where((surgery) => 
            surgery.startTime.isAfter(now) &&
            surgery.status.toLowerCase() == 'scheduled')
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }
}

/// Card widget for displaying surgery information in TV view
class TVSurgeryCard extends StatelessWidget {
  /// Surgery to display in the card
  final Surgery surgery;

  const TVSurgeryCard({super.key, required this.surgery});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showSurgeryDetails(context, surgery),
      child: Card(
        margin: const EdgeInsets.all(8),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
              const SizedBox(height: 8),
              // Time information
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${DateFormat('h:mm a').format(surgery.startTime)} - '
                    '${DateFormat('h:mm a').format(surgery.endTime)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Room information
              Row(
                children: [
                  Icon(Icons.room, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Room ${surgery.room.join(", ")}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Surgeon information
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Dr. ${surgery.surgeon}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ],
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

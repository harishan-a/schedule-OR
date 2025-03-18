// =============================================================================
// Schedule Week View
// =============================================================================
// A widget that displays surgeries in a work week calendar format using
// SfCalendar. Features include:
// - Work week view (Monday-Friday)
// - Custom time slots (6 AM to 8 PM)
// - Status-based color coding
// - Interactive surgery appointments
//
// Layout Features:
// - Customized appointment display
// - Detailed surgery information on tap
// - Visual status indicators
//
// Note: Status color mapping is duplicated across views for maintainability.
// Consider extracting to a shared utility in future updates.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:firebase_orscheduler/features/schedule/models/surgery.dart';

import 'surgery_details.dart';

/// Displays surgeries in a work week calendar format
class WeekViewContent extends StatefulWidget {
  /// List of surgeries to display in the calendar
  final List<Surgery> surgeries;
  
  /// The date to focus on, allows navigation between weeks
  final DateTime focusedDate;

  const WeekViewContent({
    super.key, 
    required this.surgeries,
    required this.focusedDate,
  });

  @override
  State<WeekViewContent> createState() => _WeekViewContentState();
}

class _WeekViewContentState extends State<WeekViewContent> {
  /// Calendar controller to manage the view
  late CalendarController _calendarController;

  @override
  void initState() {
    super.initState();
    _calendarController = CalendarController();
  }

  @override
  void didUpdateWidget(WeekViewContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update the view when the focused date changes
    if (widget.focusedDate != oldWidget.focusedDate) {
      _calendarController.displayDate = widget.focusedDate;
    }
  }

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(12),
      child: SfCalendar(
        view: CalendarView.workWeek,
        controller: _calendarController,
        dataSource: _getSurgeryDataSource(),
        initialDisplayDate: widget.focusedDate,
        initialSelectedDate: widget.focusedDate,
        cellBorderColor: theme.colorScheme.outline.withOpacity(0.1),
        backgroundColor: theme.colorScheme.surface,
        headerStyle: CalendarHeaderStyle(
          textStyle: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
          backgroundColor: theme.colorScheme.primary.withOpacity(0.05),
        ),
        viewHeaderStyle: ViewHeaderStyle(
          dayTextStyle: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          dateTextStyle: theme.textTheme.bodyMedium,
        ),
        todayHighlightColor: theme.colorScheme.primary,
        selectionDecoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.8),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        // Configure work week display settings
        timeSlotViewSettings: TimeSlotViewSettings(
          startHour: 6,  // Start at 6 AM
          endHour: 20,   // End at 8 PM
          nonWorkingDays: const <int>[DateTime.saturday, DateTime.sunday],
          timeInterval: const Duration(minutes: 30),
          timeFormat: 'h:mm a',
          timeTextStyle: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
          dateFormat: 'dd',
          dayFormat: 'EEE',
        ),
        // Handle surgery selection
        onTap: (CalendarTapDetails details) {
          if (details.appointments != null && details.appointments!.isNotEmpty) {
            final Surgery surgery = details.appointments!.first as Surgery;
            _showSurgeryDetails(context, surgery);
          }
        },
        // Custom appointment display builder
        appointmentBuilder: (context, calendarAppointmentDetails) {
          final Surgery surgery = 
              calendarAppointmentDetails.appointments.first as Surgery;
          final Color statusColor = _getStatusColor(surgery.status);
          final bool isPastDue = surgery.startTime.isBefore(DateTime.now()) && 
                      surgery.status.toLowerCase() == 'scheduled';
          
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  statusColor.withOpacity(0.8),
                  statusColor.withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.3),
                  blurRadius: 3,
                  offset: const Offset(1, 1),
                ),
              ],
              border: isPastDue ? Border.all(
                color: Colors.red.shade400,
                width: 1.5,
              ) : null,
            ),
            margin: const EdgeInsets.all(1),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row with surgery type and status indicator
                Row(
                  children: [
                    if (isPastDue)
                      Icon(Icons.warning, size: 12, color: Colors.red.shade100),
                    if (isPastDue)
                      const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        surgery.surgeryType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Patient name if available
                if (surgery.patientName.isNotEmpty && calendarAppointmentDetails.bounds.height > 60)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      'Patient: ${surgery.patientName}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                // Room information
                Row(
                  children: [
                    Icon(Icons.room, size: 10, color: Colors.white.withOpacity(0.9)),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        'Room ${surgery.room.join(", ")}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // Surgeon information
                Row(
                  children: [
                    Icon(Icons.person, size: 10, color: Colors.white.withOpacity(0.9)),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        'Dr. ${surgery.surgeon}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Creates a data source for the calendar from the surgery list
  SurgeryDataSource _getSurgeryDataSource() {
    return SurgeryDataSource(widget.surgeries);
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

  /// Shows detailed surgery information in a modal bottom sheet
  void _showSurgeryDetails(BuildContext context, Surgery surgery) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(surgery.status);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle indicator
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header with status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        surgery.surgeryType,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            surgery.status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Surgery details content
              Expanded(
                child: SurgeryDetails(
                  surgery: surgery,
                  scrollController: controller,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom calendar data source for surgery appointments
class SurgeryDataSource extends CalendarDataSource {
  /// Creates a new data source from a list of surgeries
  SurgeryDataSource(List<Surgery> source) {
    appointments = source;
  }

  @override
  DateTime getStartTime(int index) {
    return appointments![index].startTime;
  }

  @override
  DateTime getEndTime(int index) {
    return appointments![index].endTime;
  }

  @override
  String getSubject(int index) {
    return appointments![index].surgeryType;
  }

  /// Maps surgery status to display color
  /// Note: This is duplicated from the main view for consistency
  @override
  Color getColor(int index) {
    final status = appointments![index].status.toLowerCase();
    switch (status) {
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

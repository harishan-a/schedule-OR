// =============================================================================
// Schedule Month View
// =============================================================================
// A widget that displays surgeries in a monthly calendar format using
// SfCalendar. Features include:
// - Month view with agenda
// - Indicator-based surgery display
// - Status-based color coding
// - Interactive surgery appointments
//
// Layout Features:
// - Compact surgery indicators
// - Agenda view for daily details
// - Visual status indicators
//
// Note: Status color mapping is duplicated across views for maintainability.
// Consider extracting to a shared utility in future updates.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:firebase_orscheduler/features/schedule/models/surgery.dart';
import 'package:intl/intl.dart';

import 'surgery_details.dart';

/// Displays surgeries in a monthly calendar format with agenda
class MonthViewContent extends StatefulWidget {
  /// List of surgeries to display in the calendar
  final List<Surgery> surgeries;
  
  /// The date to focus on, allows navigation between months
  final DateTime focusedDate;

  const MonthViewContent({
    super.key, 
    required this.surgeries,
    required this.focusedDate,
  });

  @override
  State<MonthViewContent> createState() => _MonthViewContentState();
}

class _MonthViewContentState extends State<MonthViewContent> {
  /// Calendar controller to manage the view
  late CalendarController _calendarController;

  @override
  void initState() {
    super.initState();
    _calendarController = CalendarController();
  }

  @override
  void didUpdateWidget(MonthViewContent oldWidget) {
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
        view: CalendarView.month,
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
          dayTextStyle: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        todayHighlightColor: theme.colorScheme.primary,
        todayTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        selectionDecoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.8),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        // Configure month view settings with agenda
        monthViewSettings: MonthViewSettings(
          showAgenda: true,
          agendaViewHeight: 350,
          agendaStyle: AgendaStyle(
            backgroundColor: theme.colorScheme.surface,
            appointmentTextStyle: theme.textTheme.bodyMedium!,
            dateTextStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            dayTextStyle: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          appointmentDisplayMode: MonthAppointmentDisplayMode.indicator,
          appointmentDisplayCount: 3,
          monthCellStyle: MonthCellStyle(
            textStyle: theme.textTheme.bodyMedium,
            leadingDatesTextStyle: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            trailingDatesTextStyle: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ),
        // Handle surgery selection
        onTap: (CalendarTapDetails details) {
          if (details.appointments != null && details.appointments!.isNotEmpty) {
            final Surgery surgery = details.appointments!.first as Surgery;
            _showSurgeryDetails(context, surgery);
          }
        },
        // Custom appointment display builder for indicators
        appointmentBuilder: (context, calendarAppointmentDetails) {
          final Surgery surgery = 
              calendarAppointmentDetails.appointments.first as Surgery;
          final Color statusColor = _getStatusColor(surgery.status);
          
          // Different styling for month cell indicators vs agenda view
          if (calendarAppointmentDetails.isMoreAppointmentRegion) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '+${calendarAppointmentDetails.appointments.length - 2}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          } else if (calendarAppointmentDetails.bounds.width > 30) {
            // Regular agenda view item
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    statusColor,
                    statusColor.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.3),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              margin: const EdgeInsets.fromLTRB(1, 1, 1, 2),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 4,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    surgery.surgeryType,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${DateFormat('h:mm a').format(surgery.startTime)} • Room ${surgery.room.join(", ")}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                surgery.status,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            // Month cell indicator
            return Container(
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            );
          }
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

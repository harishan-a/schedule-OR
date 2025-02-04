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
class WeekViewContent extends StatelessWidget {
  /// List of surgeries to display in the calendar
  final List<Surgery> surgeries;

  const WeekViewContent({super.key, required this.surgeries});

  @override
  Widget build(BuildContext context) {
    return SfCalendar(
      view: CalendarView.workWeek,
      dataSource: _getSurgeryDataSource(),
      // Configure work week display settings
      timeSlotViewSettings: const TimeSlotViewSettings(
        startHour: 6,  // Start at 6 AM
        endHour: 20,   // End at 8 PM
        nonWorkingDays: <int>[DateTime.saturday, DateTime.sunday],
        timeInterval: Duration(minutes: 30),
        timeFormat: 'h:mm a',
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
        return Container(
          decoration: BoxDecoration(
            color: _getStatusColor(surgery.status).withOpacity(0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Surgery type with emphasis
              Text(
                surgery.surgeryType,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // Room information
              Text(
                'Room: ${surgery.room.join(", ")}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
                maxLines: 1,
              ),
              // Surgeon information
              Text(
                'Dr. ${surgery.surgeon}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Creates a data source for the calendar from the surgery list
  SurgeryDataSource _getSurgeryDataSource() {
    return SurgeryDataSource(surgeries);
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

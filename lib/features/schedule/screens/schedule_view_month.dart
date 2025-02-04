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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_orscheduler/features/schedule/models/surgery.dart';

import 'schedule.dart';
import 'schedule_view_week.dart';
import 'surgery_details.dart';

/// Displays surgeries in a monthly calendar format with agenda
class MonthViewContent extends StatelessWidget {
  /// List of surgeries to display in the calendar
  final List<Surgery> surgeries;

  const MonthViewContent({super.key, required this.surgeries});

  @override
  Widget build(BuildContext context) {
    return SfCalendar(
      view: CalendarView.month,
      dataSource: _getSurgeryDataSource(),
      // Configure month view settings with agenda
      monthViewSettings: const MonthViewSettings(
        showAgenda: true,
        agendaViewHeight: 300,
        appointmentDisplayMode: MonthAppointmentDisplayMode.indicator,
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
        return Container(
          decoration: BoxDecoration(
            color: _getStatusColor(surgery.status),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            surgery.surgeryType,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

import 'package:firebase_orscheduler/screens/schedule.dart';
import 'package:firebase_orscheduler/utils/schedule/schedule_view_week.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import 'surgery_details.dart';

class MonthViewContent extends StatelessWidget {
  final List<Surgery> surgeries;

  const MonthViewContent({super.key, required this.surgeries});

  @override
  Widget build(BuildContext context) {
    return SfCalendar(
      view: CalendarView.month,
      dataSource: _getSurgeryDataSource(),
      monthViewSettings: const MonthViewSettings(
        showAgenda: true,
        agendaViewHeight: 300,
        appointmentDisplayMode: MonthAppointmentDisplayMode.indicator,
      ),
      onTap: (CalendarTapDetails details) {
        if (details.appointments != null && details.appointments!.isNotEmpty) {
          final Surgery surgery = details.appointments!.first as Surgery;
          _showSurgeryDetails(context, surgery);
        }
      },
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

  SurgeryDataSource _getSurgeryDataSource() {
    return SurgeryDataSource(surgeries);
  }

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
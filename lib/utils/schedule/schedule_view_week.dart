import 'package:firebase_orscheduler/screens/schedule.dart';
import 'package:firebase_orscheduler/utils/schedule/surgery_details.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class WeekViewContent extends StatelessWidget {
  final List<Surgery> surgeries;

  const WeekViewContent({super.key, required this.surgeries});

  @override
  Widget build(BuildContext context) {
    return SfCalendar(
      view: CalendarView.workWeek,
      dataSource: _getSurgeryDataSource(),
      timeSlotViewSettings: const TimeSlotViewSettings(
        startHour: 6,
        endHour: 20,
        nonWorkingDays: <int>[DateTime.saturday, DateTime.sunday],
        timeInterval: Duration(minutes: 30),
        timeFormat: 'h:mm a',
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
            color: _getStatusColor(surgery.status).withOpacity(0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Text(
                'Room: ${surgery.room.first}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
                maxLines: 1,
              ),
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

class SurgeryDataSource extends CalendarDataSource {
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
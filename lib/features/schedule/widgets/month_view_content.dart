import 'package:flutter/material.dart';
import 'package:firebase_orscheduler/features/schedule/models/surgery.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class MonthViewContent extends StatefulWidget {
  final List<Surgery> surgeries;

  const MonthViewContent({
    super.key,
    required this.surgeries,
  });

  @override
  State<MonthViewContent> createState() => _MonthViewContentState();
}

class _MonthViewContentState extends State<MonthViewContent> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late Map<DateTime, List<Surgery>> _surgeryMap;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _updateSurgeryMap();
  }

  void _updateSurgeryMap() {
    _surgeryMap = {};
    for (final surgery in widget.surgeries) {
      final date = DateTime(
        surgery.dateTime.year,
        surgery.dateTime.month,
        surgery.dateTime.day,
      );
      _surgeryMap[date] = [...(_surgeryMap[date] ?? []), surgery];
    }
  }

  List<Surgery> _getEventsForDay(DateTime day) {
    return _surgeryMap[day] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TableCalendar<Surgery>(
          firstDay: DateTime.utc(2024, 1, 1),
          lastDay: DateTime.utc(2025, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: _getEventsForDay,
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          calendarStyle: CalendarStyle(
            markersMaxCount: 3,
            markerDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildEventList(),
        ),
      ],
    );
  }

  Widget _buildEventList() {
    final events = _getEventsForDay(_selectedDay);
    if (events.isEmpty) {
      return const Center(
        child: Text('No surgeries scheduled for this day'),
      );
    }

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final surgery = events[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            title: Text(surgery.patientName),
            subtitle: Text(DateFormat('h:mm a').format(surgery.dateTime)),
            trailing: Text('Room ${surgery.roomId}'),
          ),
        );
      },
    );
  }
} 
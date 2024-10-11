import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'add_surgery.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String? selectedSurgeryId;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _isFullScreen = false;
  DateTime _selectedDay = DateTime.now();
  String _selectedRole = 'All'; // State to hold the selected role for filtering
  late Map<DateTime, List<dynamic>> _surgeriesByDate = {};

  @override
  void initState() {
    super.initState();
    _fetchSurgeries();
  }

  // Fetch surgeries from Firestore and group them by date
  Future<void> _fetchSurgeries() async {
    final surgeriesSnapshot =
        await FirebaseFirestore.instance.collection('surgeries').get();

    final Map<DateTime, List<dynamic>> surgeriesMap = {};

    for (var doc in surgeriesSnapshot.docs) {
      var data = doc.data();
      DateTime startTime = (data['startTime'] as Timestamp).toDate();
      DateTime dateOnly = DateTime(startTime.year, startTime.month, startTime.day);

      if (surgeriesMap[dateOnly] == null) {
        surgeriesMap[dateOnly] = [];
      }

      surgeriesMap[dateOnly]!.add({
        'id': doc.id,
        'surgeryType': data['surgeryType'],
        'room': data['room'],
        'surgeon': data['surgeon'],
        'startTime': data['startTime'],
        'endTime': data['endTime'],
        'status': data['status'],
        'nurses': data['nurses'],
        'technologists': data['technologists'],
        'notes': data['notes'],
      });
    }

    setState(() {
      _surgeriesByDate = surgeriesMap;
    });
  }

  // Get the surgeries scheduled for a specific day
  List<dynamic> _getEventsForDay(DateTime day) {
    var surgeries = _surgeriesByDate[DateTime(day.year, day.month, day.day)] ?? [];
    if (_selectedRole == 'All') {
      return surgeries;
    }
    return surgeries.where((surgery) {
      if (_selectedRole == 'Doctor') {
        return surgery['surgeon'] != null;
      } else if (_selectedRole == 'Nurse') {
        return surgery['nurses'] != null && surgery['nurses'].isNotEmpty;
      } else if (_selectedRole == 'Technologist') {
        return surgery['technologists'] != null && surgery['technologists'].isNotEmpty;
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Surgery Schedule'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => AddSurgeryScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
            onPressed: () {
              setState(() {
                _isFullScreen = !_isFullScreen;
              });
            },
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: _isFullScreen ? 1 : 2,
            child: Column(
              children: [
                // Calendar Selector Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownButton<CalendarFormat>(
                      value: _calendarFormat,
                      items: const [
                        DropdownMenuItem(
                          value: CalendarFormat.week,
                          child: Text('1 Week'),
                        ),
                        DropdownMenuItem(
                          value: CalendarFormat.twoWeeks,
                          child: Text('2 Weeks'),
                        ),
                        DropdownMenuItem(
                          value: CalendarFormat.month,
                          child: Text('Month'),
                        ),
                      ],
                      onChanged: (CalendarFormat? format) {
                        setState(() {
                          if (format != null) {
                            _calendarFormat = format;
                          }
                        });
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 10, 16),
                    lastDay: DateTime.utc(2030, 3, 14),
                    focusedDay: _selectedDay,
                    calendarFormat: _calendarFormat,
                    eventLoader: _getEventsForDay,
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                      });
                    },
                    calendarStyle: CalendarStyle(
                      selectedDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                if (_getEventsForDay(_selectedDay).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Surgeries on ${DateFormat('MMMM dd, yyyy').format(_selectedDay)}:',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          if (!_isFullScreen)
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  // Role Filter added here
                  RoleFilter(
                    selectedRole: _selectedRole,
                    onRoleChanged: (newRole) {
                      setState(() {
                        _selectedRole = newRole!;
                      });
                    },
                  ),
                  Expanded(
                    child: SurgeryDetailsPanel(
                      surgeries: _getEventsForDay(_selectedDay),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class SurgeryDetailsPanel extends StatelessWidget {
  final List<dynamic> surgeries;

  const SurgeryDetailsPanel({super.key, required this.surgeries});

  @override
  Widget build(BuildContext context) {
    if (surgeries.isEmpty) {
      return const Center(child: Text('No surgeries for this date.'));
    }

    return ListView.builder(
      itemCount: surgeries.length,
      itemBuilder: (ctx, index) {
        var surgery = surgeries[index];

        return Card(
          margin: const EdgeInsets.all(8.0),
          child: ListTile(
            title: Text('${surgery['surgeryType']} - Room: ${surgery['room'][0]}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Surgeon: ${surgery['surgeon']}'),
                Text('Start Time: ${DateFormat('hh:mm a').format((surgery['startTime'] as Timestamp).toDate())}'),
                Text('End Time: ${DateFormat('hh:mm a').format((surgery['endTime'] as Timestamp).toDate())}'),
                Text('Status: ${surgery['status']}'),
                Text('Notes: ${surgery['notes']}'),
                const SizedBox(height: 5),
                Text('Nurses: ${surgery['nurses'].join(', ')}'),
                Text('Technologists: ${surgery['technologists'].join(', ')}'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class RoleFilter extends StatelessWidget {
  final String selectedRole;
  final Function(String?) onRoleChanged;

  const RoleFilter({super.key, required this.selectedRole, required this.onRoleChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Filter by Role:', style: TextStyle(fontSize: 16)),
          DropdownButton<String>(
            value: selectedRole,
            items: ['All', 'Doctor', 'Nurse', 'Technologist']
                .map((role) => DropdownMenuItem(
                      value: role,
                      child: Text(role),
                    ))
                .toList(),
            onChanged: onRoleChanged,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'add_surgery.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String? selectedSurgeryId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Surgery Schedule'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => AddSurgeryScreen()),
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                RoleFilter(), // Role-based filter for surgeries
                Expanded(
                  child: SurgeryCalendar(
                    onSurgerySelected: (surgeryId) {
                      setState(() {
                        selectedSurgeryId = surgeryId;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: selectedSurgeryId == null
                ? Center(child: Text('Select a surgery to view details'))
                : SurgeryDetailsPanel(surgeryId: selectedSurgeryId!),
          ),
        ],
      ),
    );
  }
}

class SurgeryCalendar extends StatelessWidget {
  final Function(String) onSurgerySelected;

  const SurgeryCalendar({super.key, required this.onSurgerySelected});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('surgeries').snapshots(),
      builder: (ctx, snapshot) {
        // Show a loading indicator while waiting for data
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Handle errors and null data
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const Center(
            child: Text('Something went wrong or no surgeries available.'),
          );
        }

        // Safely access surgeries data
        final surgeries = snapshot.data!.docs;

        // Handle the case where there are no surgeries
        if (surgeries.isEmpty) {
          return const Center(
            child: Text('No surgeries scheduled at the moment.'),
          );
        }

        return ListView.builder(
          itemCount: surgeries.length,
          itemBuilder: (ctx, index) {
            var surgeryData = surgeries[index].data() as Map<String, dynamic>;

            // Safely access data in surgeryData and provide fallback values
            final surgeryType = surgeryData['surgeryType'] ?? 'Unknown Surgery';
            final room = surgeryData['room'] ?? 'Unknown Room';
            final startTime = surgeryData['startTime'] != null
                ? DateFormat('MMM dd, yyyy - hh:mm a').format(surgeryData['startTime'].toDate())
                : 'Unknown Time';

            return ListTile(
              title: Text('$surgeryType - Room $room'),
              subtitle: Text('Time: $startTime'),
              onTap: () => onSurgerySelected(surgeries[index].id),
            );
          },
        );
      },
    );
  }
}


class SurgeryDetailsPanel extends StatelessWidget {
  final String surgeryId;

  const SurgeryDetailsPanel({super.key, required this.surgeryId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('surgeries').doc(surgeryId).get(),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        var surgeryData = snapshot.data!.data() as Map<String, dynamic>;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Surgery: ${surgeryData['surgeryType']}'),
            Text('Room: ${surgeryData['room']}'),
            Text('Start Time: ${DateFormat('MMM dd, yyyy - hh:mm a').format(surgeryData['startTime'].toDate())}'),
            Text('End Time: ${DateFormat('MMM dd, yyyy - hh:mm a').format(surgeryData['endTime'].toDate())}'),
            Text('Status: ${surgeryData['status']}'),
            SizedBox(height: 10),
            Text('Assigned Staff:'),
            Text('Surgeon: ${surgeryData['surgeon']}'),
            Text('Nurses: ${surgeryData['nurses'].join(', ')}'),
            Text('Technologists: ${surgeryData['technologists'].join(', ')}'),
          ],
        );
      },
    );
  }
}

class RoleFilter extends StatelessWidget {
  const RoleFilter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Filter by Role:', style: TextStyle(fontSize: 16)),
          DropdownButton<String>(
            value: 'All',
            items: ['All', 'Doctor', 'Nurse', 'Technologist']
                .map((role) => DropdownMenuItem(
                      value: role,
                      child: Text(role),
                    ))
                .toList(),
            onChanged: (value) {
              // Implement filter logic here
            },
          ),
        ],
      ),
    );
  }
}

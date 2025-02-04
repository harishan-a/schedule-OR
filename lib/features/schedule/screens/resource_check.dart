// =============================================================================
// Resource Check Screen
// =============================================================================
// A screen that checks availability and conflicts for OR resources:
// - Operating Rooms
// - Surgeons
// - Nursing Staff
// - Technical Staff
//
// Conflict Detection:
// - Time overlap checking for each resource
// - Future bookings display
// - Status-based filtering (Scheduled/In-Progress only)
//
// Query Structure:
// - Parallel Firestore queries for each resource type
// - Nested time range validation
// - Real-time staff list population
//
// Note: Each resource type is queried separately to allow for:
// - Independent conflict detection
// - Granular error handling
// - Specific conflict messaging
// =============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';

/// Screen for checking resource availability and conflicts
class ResourceCheck extends StatefulWidget {
  const ResourceCheck({super.key});

  @override
  ResourceCheckScreenState createState() => ResourceCheckScreenState();
}

class ResourceCheckScreenState extends State<ResourceCheck> {
  // Selected resource values
  String? _operatingRoom;
  String? _selectedDoctor;
  List<String> _selectedNurses = [];
  String? _selectedTechnologist;
  
  // Time range for checking
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 1));

  // Available resources
  final List<String> _room = [
    'OperatingRoom1',
    'OperatingRoom2',
    'OperatingRoom3',
    'OperatingRoom4',
    'OperatingRoom5'
  ];

  // Staff lists populated from Firestore
  List<String> _technologists = [];
  List<String> _doctors = [];
  List<String> _nurses = [];
  
  // Conflict tracking
  List<String> _conflicts = [];
  List<Map<String, dynamic>> _futureBookings = [];

  @override
  void initState() {
    super.initState();
    // Load staff lists on initialization
    _fetchDoctors();
    _fetchNurses();
    _fetchTechnologists();
  }

  /// Fetches list of technologists from Firestore
  /// Filters users by role and formats full names
  Future<void> _fetchTechnologists() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Technologist')
          .get();
      List<String> technologistsName = [];
      for (var doc in snapshot.docs) {
        String fullName = '${doc['firstName']} ${doc['lastName']}';
        technologistsName.add(fullName);
      }
      setState(() {
        _technologists = technologistsName;
      });
    } catch (error) {
      debugPrint("Error fetching technologists: $error");
    }
  }

  /// Fetches list of doctors from Firestore
  /// Filters users by role and formats full names
  Future<void> _fetchDoctors() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Doctor')
          .get();
      List<String> doctorName = [];
      for (var doc in snapshot.docs) {
        String fullName = '${doc['firstName']} ${doc['lastName']}';
        doctorName.add(fullName);
      }
      setState(() {
        _doctors = doctorName;
      });
    } catch (error) {
      debugPrint("Error fetching doctors: $error");
    }
  }

  /// Fetches list of nurses from Firestore
  /// Filters users by role and formats full names
  Future<void> _fetchNurses() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Nurse')
          .get();
      List<String> nurseName = [];
      for (var doc in snapshot.docs) {
        String fullName = '${doc['firstName']} ${doc['lastName']}';
        nurseName.add(fullName);
      }
      setState(() {
        _nurses = nurseName;
      });
    } catch (error) {
      debugPrint("Error fetching nurses: $error");
    }
  }

  /// Checks for scheduling conflicts across all selected resources
  /// 
  /// Process:
  /// 1. Clear previous results
  /// 2. Check each resource type separately
  /// 3. Collect both conflicts and future bookings
  /// 4. Update UI with results
  Future<void> _checkConflicts() async {
    _conflicts.clear();
    _futureBookings.clear();

    try {
      final query = FirebaseFirestore.instance.collection('surgeries');

      // Check Operating Room conflicts
      if (_operatingRoom != null) {
        final roomConflicts = await query
            .where('room', isEqualTo: _operatingRoom)
            .get();

        for (var doc in roomConflicts.docs) {
          final surgery = doc.data();
          final surgeryStartTime = (surgery['startTime'] as Timestamp).toDate();
          final surgeryEndTime = (surgery['endTime'] as Timestamp).toDate();
          final surgeryStatus = surgery['status'];

          // Track future bookings for room
          if (surgeryStartTime.isAfter(DateTime.now()) &&
              (surgeryStatus == "Scheduled" || surgeryStatus == "In-Progress")) {
            _futureBookings.add({
              'resource': 'Operating Room',
              'name': _operatingRoom,
              'startTime': surgeryStartTime,
              'endTime': surgeryEndTime,
            });
          }

          // Check for time overlap
          if (_startTime.isBefore(surgeryEndTime) &&
              _endTime.isAfter(surgeryStartTime) &&
              (surgeryStatus == "Scheduled" || surgeryStatus == "In-Progress")) {
            _conflicts.add(
                '$_operatingRoom is already scheduled from ${DateFormat('MMM dd, yyyy - hh:mm a').format(surgeryStartTime)} to ${DateFormat('MMM dd, yyyy - hh:mm a').format(surgeryEndTime)}.');
          }
        }
      }

      // Check Doctor conflicts
      if (_selectedDoctor != null) {
        final doctorConflicts = await query
            .where('surgeon', isEqualTo: _selectedDoctor)
            .get();

        for (var doc in doctorConflicts.docs) {
          final surgery = doc.data();
          final surgeryStartTime = (surgery['startTime'] as Timestamp).toDate();
          final surgeryEndTime = (surgery['endTime'] as Timestamp).toDate();
          final surgeryStatus = surgery['status'];

          // Track future bookings for doctor
          if (surgeryStartTime.isAfter(DateTime.now()) &&
              (surgeryStatus == "Scheduled" || surgeryStatus == "In-Progress")) {
            _futureBookings.add({
              'resource': 'Doctor',
              'name': _selectedDoctor,
              'startTime': surgeryStartTime,
              'endTime': surgeryEndTime,
            });
          }

          // Check for time overlap
          if (_startTime.isBefore(surgeryEndTime) &&
              _endTime.isAfter(surgeryStartTime) &&
              (surgeryStatus == "Scheduled" || surgeryStatus == "In-Progress")) {
            _conflicts.add(
                'Doctor $_selectedDoctor is already scheduled from ${DateFormat('MMM dd, yyyy - hh:mm a').format(surgeryStartTime)} to ${DateFormat('MMM dd, yyyy - hh:mm a').format(surgeryEndTime)}.');
          }
        }
      }

      // Check Nurse conflicts
      for (var nurse in _selectedNurses) {
        final nurseConflicts = await query
            .where('nurses', arrayContains: nurse)
            .get();

        for (var doc in nurseConflicts.docs) {
          final surgery = doc.data();
          final surgeryStartTime = (surgery['startTime'] as Timestamp).toDate();
          final surgeryEndTime = (surgery['endTime'] as Timestamp).toDate();
          final surgeryStatus = surgery['status'];

          // Track future bookings for nurse
          if (surgeryStartTime.isAfter(DateTime.now()) &&
              (surgeryStatus == "Scheduled" || surgeryStatus == "In-Progress")) {
            _futureBookings.add({
              'resource': 'Nurse',
              'name': nurse,
              'startTime': surgeryStartTime,
              'endTime': surgeryEndTime,
            });
          }

          // Check for time overlap
          if (_startTime.isBefore(surgeryEndTime) &&
              _endTime.isAfter(surgeryStartTime) &&
              (surgeryStatus == "Scheduled" || surgeryStatus == "In-Progress")) {
            _conflicts.add(
                'Nurse $nurse is already scheduled from ${DateFormat('MMM dd, yyyy - hh:mm a').format(surgeryStartTime)} to ${DateFormat('MMM dd, yyyy - hh:mm a').format(surgeryEndTime)}.');
          }
        }
      }

      // Check Technologist conflicts
      if (_selectedTechnologist != null) {
        final techConflicts = await query
            .where('technologists', arrayContains: _selectedTechnologist)
            .get();

        for (var doc in techConflicts.docs) {
          final surgery = doc.data();
          final surgeryStartTime = (surgery['startTime'] as Timestamp).toDate();
          final surgeryEndTime = (surgery['endTime'] as Timestamp).toDate();
          final surgeryStatus = surgery['status'];

          // Track future bookings for technologist
          if (surgeryStartTime.isAfter(DateTime.now()) &&
              (surgeryStatus == "Scheduled" || surgeryStatus == "In-Progress")) {
            _futureBookings.add({
              'resource': 'Technologist',
              'name': _selectedTechnologist,
              'startTime': surgeryStartTime,
              'endTime': surgeryEndTime,
            });
          }

          // Check for time overlap
          if (_startTime.isBefore(surgeryEndTime) &&
              _endTime.isAfter(surgeryStartTime) &&
              (surgeryStatus == "Scheduled" || surgeryStatus == "In-Progress")) {
            _conflicts.add(
                'Technologist $_selectedTechnologist is already scheduled from ${DateFormat('MMM dd, yyyy - hh:mm a').format(surgeryStartTime)} to ${DateFormat('MMM dd, yyyy - hh:mm a').format(surgeryEndTime)}.');
          }
        }
      }

      setState(() {});
    } catch (error) {
      debugPrint('Error checking conflicts: $error');
      _conflicts.add('An error occurred while checking for conflicts.');
      setState(() {});
    }
  }

  /// Builds a table showing future bookings for a specific resource type
  /// 
  /// Parameters:
  /// - resourceType: Type of resource to display bookings for
  /// 
  /// Returns empty widget if no bookings exist for the resource
  Widget _buildFutureBookingsTable(String resourceType) {
    final bookings = _futureBookings
        .where((booking) => booking['resource'] == resourceType)
        .toList();

    if (bookings.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            resourceType,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.blueAccent,
            ),
          ),
        ),
        Table(
          border: TableBorder.all(color: Colors.grey),
          columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(2)},
          children: bookings.map((booking) {
            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(booking['name'] ?? ''),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                      '${DateFormat('MMM dd, yyyy - hh:mm a').format(booking['startTime'])} to ${DateFormat('MMM dd, yyyy - hh:mm a').format(booking['endTime'])}'),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Check Resource Usage'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Operating Room selection
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Operating Room'),
              value: _operatingRoom,
              onChanged: (String? newValue) {
                setState(() {
                  _operatingRoom = newValue;
                });
              },
              items: _room.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            // Surgeon selection with search
            DropdownSearch<String>(
              items: _doctors,
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Select Surgeon',
                  hintText: 'Search and select a surgeon',
                ),
              ),
              popupProps: const PopupProps.menu(showSearchBox: true),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedDoctor = newValue;
                });
              },
              selectedItem: _selectedDoctor,
            ),
            // Multiple nurse selection with search
            DropdownSearch<String>.multiSelection(
              items: _nurses,
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Select Nurses',
                  hintText: 'Search and select nurses',
                ),
              ),
              popupProps: const PopupPropsMultiSelection.menu(
                showSearchBox: true,
              ),
              onChanged: (List<String> selected) {
                setState(() {
                  _selectedNurses = selected;
                });
              },
              selectedItems: _selectedNurses,
            ),
            // Technologist selection with search
            DropdownSearch<String>(
              items: _technologists,
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Select Technologist',
                  hintText: 'Search and select a technologist',
                ),
              ),
              popupProps: const PopupProps.menu(showSearchBox: true),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedTechnologist = newValue;
                });
              },
              selectedItem: _selectedTechnologist,
            ),
            const SizedBox(height: 20),
            // Start time selection
            ListTile(
              title: const Text('Start Time'),
              subtitle: Text(
                  DateFormat('MMM dd, yyyy - hh:mm a').format(_startTime)),
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _startTime,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_startTime),
                  );
                  if (pickedTime != null) {
                    setState(() {
                      _startTime = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );
                    });
                  }
                }
              },
            ),
            // End time selection
            ListTile(
              title: const Text('End Time'),
              subtitle:
              Text(DateFormat('MMM dd, yyyy - hh:mm a').format(_endTime)),
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _endTime,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_endTime),
                  );
                  if (pickedTime != null) {
                    setState(() {
                      _endTime = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );

                      // Ensure end time is after start time
                      if (_endTime.isBefore(_startTime)) {
                        _startTime = _endTime.subtract(const Duration(hours: 1));
                      }
                    });
                  }
                }
              },
            ),
            const SizedBox(height: 20),
            // Check conflicts button
            ElevatedButton(
              onPressed: _checkConflicts,
              style: ElevatedButton.styleFrom(
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: Colors.lightBlueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Check Usage',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Display conflicts if any exist
            if (_conflicts.isNotEmpty)
              ..._conflicts.map(
                    (conflict) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    conflict,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            // Display future bookings if any exist
            if (_futureBookings.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Future bookings for the selected resource(s) are shown below. Please choose a time slot different those listed to avoid conflict.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildFutureBookingsTable('Operating Room'),
                  _buildFutureBookingsTable('Doctor'),
                  _buildFutureBookingsTable('Nurse'),
                  _buildFutureBookingsTable('Technologist'),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

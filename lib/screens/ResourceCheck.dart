import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';

class ResourceCheck extends StatefulWidget {
  const ResourceCheck({super.key});

  @override
  ResourceCheckScreenState createState() => ResourceCheckScreenState();
}

class ResourceCheckScreenState extends State<ResourceCheck> {
  String? _surgeryType;
  String? _operatingRoom;
  String? _selectedDoctor;
  List<String> _selectedNurses = [];
  String? _selectedTechnologist;
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 1));

  // final List<String> _surgeryTypes = [
  //   'Cardiac Surgery',
  //   'Orthopedic Surgery',
  //   'Neurosurgery',
  //   'General Surgery',
  //   'Plastic Surgery'
  // ];

  final List<String> _room = [
    'OperatingRoom1',
    'OperatingRoom2',
    'OperatingRoom3',
    'OperatingRoom4',
    'OperatingRoom5'
  ];

  List<String> _technologists = [];
  List<String> _doctors = [];
  List<String> _nurses = [];
  List<String> _conflicts = []; // To store conflict messages

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
    _fetchNurses();
    _fetchTechnologists();
  }

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
      print("Error fetching technologists: $error");
    }
  }

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
      print("Error fetching doctors: $error");
    }
  }

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
      print("Error fetching nurses: $error");
    }
  }

  Future<void> _checkConflicts() async {
    _conflicts.clear(); // Clear previous results

    try {
      final query = FirebaseFirestore.instance.collection('surgeries');
      final startTimestamp = Timestamp.fromDate(_startTime);
      final endTimestamp = Timestamp.fromDate(_endTime);

      if (_startTime.isAfter(_endTime)) {
        _conflicts.add("Start time must be before end time.");
        setState(() {});
        return;
      }

      if (_operatingRoom != null) {
        final roomConflicts = await query
            .where('room', isEqualTo: _operatingRoom)
            .get();

        for (var doc in roomConflicts.docs) {
          final surgery = doc.data();
          final surgeryStartTime = (surgery['startTime'] as Timestamp).toDate();
          final surgeryEndTime = (surgery['endTime'] as Timestamp).toDate();

          if (_startTime.isBefore(surgeryEndTime) && _endTime.isAfter(surgeryStartTime)) {
            _conflicts.add('$_operatingRoom is already scheduled during the selected time.');
            break;
          }
        }
      }

      if (_selectedDoctor != null) {
        final doctorConflicts = await query
            .where('surgeon', isEqualTo: _selectedDoctor)
            .get();

        for (var doc in doctorConflicts.docs) {
          final surgery = doc.data();
          final surgeryStartTime = (surgery['startTime'] as Timestamp).toDate();
          final surgeryEndTime = (surgery['endTime'] as Timestamp).toDate();

          if (_startTime.isBefore(surgeryEndTime) && _endTime.isAfter(surgeryStartTime)) {
            _conflicts.add('Doctor $_selectedDoctor is already scheduled during the selected time.');
            break;
          }
        }
      }

      for (var nurse in _selectedNurses) {
        final nurseConflicts = await query
            .where('nurses', arrayContains: nurse)
            .get();

        for (var doc in nurseConflicts.docs) {
          final surgery = doc.data();
          final surgeryStartTime = (surgery['startTime'] as Timestamp).toDate();
          final surgeryEndTime = (surgery['endTime'] as Timestamp).toDate();

          if (_startTime.isBefore(surgeryEndTime) && _endTime.isAfter(surgeryStartTime)) {
            _conflicts.add('Nurse $nurse is already scheduled during the selected time.');
            break;
          }
        }
      }

      if (_selectedTechnologist != null) {
        final techConflicts = await query
            .where('technologists', arrayContains: _selectedTechnologist)
            .get();

        for (var doc in techConflicts.docs) {
          final surgery = doc.data();
          final surgeryStartTime = (surgery['startTime'] as Timestamp).toDate();
          final surgeryEndTime = (surgery['endTime'] as Timestamp).toDate();

          if (_startTime.isBefore(surgeryEndTime) && _endTime.isAfter(surgeryStartTime)) {
            _conflicts.add('Technologist $_selectedTechnologist is already scheduled during the selected time.');
            break;
          }
        }
      }

      setState(() {});
    } catch (error) {
      print("Error checking conflicts: $error");
      _conflicts.add('An error occurred while checking for conflicts.');
      setState(() {});
    }
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
            // DropdownButtonFormField<String>(
            //   decoration: const InputDecoration(labelText: 'Surgery Type'),
            //   value: _surgeryType,
            //   onChanged: (String? newValue) {
            //     setState(() {
            //       _surgeryType = newValue;
            //     });
            //   },
            //   items: _surgeryTypes.map<DropdownMenuItem<String>>((String value) {
            //     return DropdownMenuItem<String>(
            //       value: value,
            //       child: Text(value),
            //     );
            //   }).toList(),
            // ),
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
            DropdownSearch<String>.multiSelection(
              items: _technologists,
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Select Technologists',
                  hintText: 'Search and select technologists',
                ),
              ),
              popupProps: const PopupPropsMultiSelection.menu(
                showSearchBox: true,
              ),
              onChanged: (List<String> selected) {
                setState(() {
                  _selectedTechnologist =
                  selected.isNotEmpty ? selected[0] : null;
                });
              },
              selectedItems: _selectedTechnologist != null
                  ? [_selectedTechnologist!]
                  : [],
            ),
            const SizedBox(height: 20),
            ListTile(
              title: const Text('Start Time'),
              subtitle: Text(DateFormat('MMM dd, yyyy - hh:mm a').format(_startTime)),
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
            ListTile(
              title: const Text('End Time'),
              subtitle: Text(DateFormat('MMM dd, yyyy - hh:mm a').format(_endTime)),
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

                      // Ensure _endTime is after _startTime
                      if (_endTime.isBefore(_startTime)) {
                        _startTime = _endTime.subtract(const Duration(hours: 1));
                      }
                    });
                  }
                }
              },
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _checkConflicts,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
            if (_conflicts.isNotEmpty) ..._conflicts.map((conflict) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                conflict,
                style: const TextStyle(color: Colors.red),
              ),
            )),

          ],
        ),
      ),
    );
  }
}

import 'package:firebase_orscheduler/screens/profile.dart';
import 'package:firebase_orscheduler/screens/schedule.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'resource_check.dart';


class AddSurgeryScreen extends StatefulWidget {
  const AddSurgeryScreen({super.key});

  @override
  AddSurgeryScreenState createState() => AddSurgeryScreenState();
}

class AddSurgeryScreenState extends State<AddSurgeryScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _surgeryType;
  String? _operatingRoom;
  String? _selectedDoctor;
  List<String> _selectedNurses = [];
  String? _notes;
  String? _selectedTechnologist;
  int _selectedIndex = 2;

  final List<String> _surgeryTypes = [
    'Cardiac Surgery',
    'Orthopedic Surgery',
    'Neurosurgery',
    'General Surgery',
    'Plastic Surgery'
  ];
  final List<String> _room = [
    'OperatingRoom1',
    'OperatingRoom2',
    'OperatingRoom3',
    'OperatingRoom4',
    'OperatingRoom5'
  ];
  var _startTime = DateTime.now();
  var _endTime = DateTime.now().add(Duration(hours: 1));
  //var _surgeon = '';
  //var _nurses = [];
  List<String> _technologists = [];
  var _status = 'Scheduled';

  List<String> _doctors = [];
  List<String> _nurses = [];

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
    _fetchNurses();
    _fetchTechnologists();
  }

  // Handles navigation based on the selected index in the BottomNavigationBar.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (ctx) => const ScheduleScreen()));
        break;
      case 1:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (ctx) => ScheduleScreen()));
        break;
      case 2:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (ctx) => AddSurgeryScreen()));
        break;
      case 3:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (ctx) => const ProfileScreen()));
        break;
      case 4:
      // Stay on the current screen
        break;
    }
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

  Future<bool> _checkForConflicts() async {
    try {
      //check for room conflict
      var roomConflict = await FirebaseFirestore.instance
          .collection('surgeries')
          .where('room', isEqualTo: _operatingRoom)
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(_endTime))
          .where('endTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(_startTime))
          .get();

      if (roomConflict.docs.isNotEmpty) {
        return true; //room is already booked
      }

      //check for doctor conflict
      var doctorConflict = await FirebaseFirestore.instance
          .collection('surgeries')
          .where('surgeon', isEqualTo: _selectedDoctor)
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(_endTime))
          .where('endTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(_startTime))
          .get();

      if (doctorConflict.docs.isNotEmpty) {
        return true; //doctor is already booked
      }

      //check for nurse conflicts
      for (var nurse in _selectedNurses) {
        var nurseConflict = await FirebaseFirestore.instance
            .collection('surgeries')
            .where('nourse', arrayContains: nurse)
            .where('startTime',
                isLessThanOrEqualTo: Timestamp.fromDate(_endTime))
            .where('endTime',
                isGreaterThanOrEqualTo: Timestamp.fromDate(_startTime))
            .get();

        if (nurseConflict.docs.isNotEmpty) {
          return true; //nurse is already booked
        }
      }

      return false; //no conflicts
    } catch (error) {
      print("Error checking conflicts: $error");
      return true; // Return true in case of an error to prevent the surgery from being added
    }
  }

  Future<void> _submitForm() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) return;

    _formKey.currentState!.save();

    //check for scheduling conflictss

    bool hasConflict = await _checkForConflicts();
    if (hasConflict) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Conflict Detected'),
          content: Text(
              'There is a conflict with the provided information. Please enter another acceptable resource.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: Text(
                'OK',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      );
      return;
    }

    try {
      // Save to Firestore
      await FirebaseFirestore.instance.collection('surgeries').add({
        'surgeryType': _surgeryType,
        'room': _operatingRoom,
        'startTime': Timestamp.fromDate(_startTime),
        'endTime': Timestamp.fromDate(_endTime),
        'surgeon': _selectedDoctor,
        'nurses': _selectedNurses,
        'technologists': _technologists,
        'status': _status,
        'notes': _notes,
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Surgery Added'),
          content: Text('The surgery has been successfully added!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: Text(
                'OK',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      );

      //Navigator.of(context).pop(); // Go back after adding surgery
    } catch (error) {
      print("Error adding surgery: $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Surgery'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ResourceCheck(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.lightBlueAccent,
                  ),
                  child: const Text(
                    'Check Resource Usage',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Surgery Type'),
                value: _surgeryType,
                onChanged: (String? newValue) {
                  setState(() {
                    _surgeryType = newValue;
                  });
                },
                items:
                    _surgeryTypes.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the surgery type';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Choose Operating Room'),
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the room';
                  }
                  return null;
                },
              ),
              ListTile(
                title: Text('Start Time'),
                subtitle: Text(
                    DateFormat('MMM dd, yyyy - hh:mm a').format(_startTime)),
                onTap: () async {
                  var pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _startTime,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                    builder: (BuildContext context, Widget? child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          textButtonTheme: TextButtonThemeData(
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Colors.black, // Customize button text color
                            ),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (pickedDate != null) {
                    var pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_startTime),
                      //colour changing
                      builder: (BuildContext context, Widget? child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            timePickerTheme: TimePickerThemeData(
                              dialTextColor: Colors.blue,
                              hourMinuteTextColor: Colors.blue,
                              dayPeriodTextColor: Colors.white,
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    Colors.black, // Customize button text color
                              ),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (pickedTime != null) {
                      setState(() {
                        _startTime = DateTime(pickedDate.year, pickedDate.month,
                            pickedDate.day, pickedTime.hour, pickedTime.minute);
                      });
                    }
                  }
                },
              ),
              ListTile(
                title: Text('End Time'),
                subtitle:
                    Text(DateFormat('MMM dd, yyyy - hh:mm a').format(_endTime)),
                onTap: () async {
                  var pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _endTime,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                    builder: (BuildContext context, Widget? child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          textButtonTheme: TextButtonThemeData(
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Colors.black, // Customize button text color
                            ),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (pickedDate != null) {
                    var pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_endTime),
                      builder: (BuildContext context, Widget? child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    Colors.green, // Customize button text color
                              ),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (pickedTime != null) {
                      setState(() {
                        _endTime = DateTime(pickedDate.year, pickedDate.month,
                            pickedDate.day, pickedTime.hour, pickedTime.minute);
                      });
                    }
                  }
                },
              ),
              DropdownSearch<String>(
                items: _doctors,
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Select Surgeon',
                    hintText: 'Search and select a surgeon',
                  ),
                ),
                popupProps: PopupProps.menu(
                  showSearchBox: true,
                ),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedDoctor = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter surgeon name';
                  }
                  return null;
                },
                selectedItem: _selectedDoctor,
                filterFn: (item, filter) {
                  if (filter == null || filter.isEmpty) {
                    return true;
                  }
                  return item.toLowerCase().contains(filter.toLowerCase()) ||
                      item
                          .split(' ')
                          .first
                          .toLowerCase()
                          .contains(filter.toLowerCase()) ||
                      item
                          .split(' ')
                          .last
                          .toLowerCase()
                          .contains(filter.toLowerCase());
                },
              ),
              DropdownSearch<String>.multiSelection(
                  items: _nurses,
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      labelText: 'Select Nurse',
                      hintText: 'Search and select a nurse',
                    ),
                  ),
                  popupProps: PopupPropsMultiSelection.menu(
                    showSearchBox: true,
                  ),
                  onChanged: (List<String> selected) {
                    setState(() {
                      _selectedNurses = selected;
                    });
                  },
                  selectedItems: _selectedNurses,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter nurse names';
                    }
                    return null;
                  },
                  //selectedItem: _selectedNurse,
                  filterFn: (item, filter) {
                    if (filter == null || filter.isEmpty) {
                      return true;
                    }
                    return item.toLowerCase().contains(filter.toLowerCase()) ||
                        item
                            .split(' ')
                            .first
                            .toLowerCase()
                            .contains(filter.toLowerCase()) ||
                        item
                            .split(' ')
                            .last
                            .toLowerCase()
                            .contains(filter.toLowerCase());
                  }),
              DropdownSearch<String>.multiSelection(
                items:
                    _technologists, // Use the same nurse list for technologists
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Select Technologists',
                    hintText: 'Search and select technologists',
                  ),
                ),
                popupProps: PopupPropsMultiSelection.menu(
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter technologist names';
                  }
                  return null;
                },
                filterFn: (item, filter) {
                  if (filter == null || filter.isEmpty) {
                    return true;
                  }
                  return item.toLowerCase().contains(filter.toLowerCase()) ||
                      item
                          .split(' ')
                          .first
                          .toLowerCase()
                          .contains(filter.toLowerCase()) ||
                      item
                          .split(' ')
                          .last
                          .toLowerCase()
                          .contains(filter.toLowerCase());
                },
              ),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: InputDecoration(labelText: 'Status'),
                items: ['Scheduled', 'In Progress', 'Completed', 'Canceled']
                    .map((status) => DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        ))
                    .toList(),
                onChanged: (String? value) {
                  setState(() {
                    _status = value!;
                  });
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Notes'),
                onSaved: (value) {
                  _notes = value;
                },
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter notes';
                  }
                  return null;
                },
              ),

              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer, // Button background color
                ),
                child: const Text(
                  'Add Surgery',
                  style: TextStyle(
                    color: Colors.black, // Set the text color to black
                  ),
                ),
              ),

              //New TextFormField for notes
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
            backgroundColor: Color.fromARGB(218, 1, 196, 164),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'View Surgery Schedule',
            backgroundColor: Color.fromARGB(218, 1, 196, 164),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medication),
            label: 'Add New Surgery',
            backgroundColor: Color.fromARGB(218, 1, 196, 164),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
            backgroundColor: Color.fromARGB(218, 1, 196, 164),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts),
            label: 'Doctor List',
            backgroundColor: Color.fromARGB(218, 1, 196, 164),
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }
}

//notes (doctor, nurse)

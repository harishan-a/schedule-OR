import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
  String? _selectedNurse;
  String? _notes;

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
  var _technologists = [];
  var _status = 'Scheduled';

  List<String> _doctors = [];
  List<String> _nurses = [];

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
    _fetchNurses();
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

  Future<void> _submitForm() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) return;

    _formKey.currentState!.save();

    try {
      // Save to Firestore
      await FirebaseFirestore.instance.collection('surgeries').add({
        'surgeryType': _surgeryType,
        'room': _room,
        'startTime': Timestamp.fromDate(_startTime),
        'endTime': Timestamp.fromDate(_endTime),
        'surgeon': _selectedDoctor,
        'nurses': _nurses,
        'technologists': _technologists,
        'status': _status,
        'notes': _notes,
      });

      Navigator.of(context).pop(); // Go back after adding surgery
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
                  );
                  if (pickedDate != null) {
                    var pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_startTime),
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
                  );
                  if (pickedDate != null) {
                    var pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_endTime),
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
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Select Surgeon'),
                value: _selectedDoctor,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedDoctor = newValue;
                  });
                },
                items: _doctors.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Container(
                      // Add a fixed height for the dropdown items
                      height: 50,
                      child: SingleChildScrollView(
                        child: Text(value),
                      ),
                    ),
                  );
                }).toList(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter surgeon name';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                decoration:
                    InputDecoration(labelText: 'Nurses (comma-separated)'),
                value: _selectedNurse,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedNurse = newValue;
                  });
                },
                items: _nurses.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Container(
                      // Add a fixed height for the dropdown items
                      height: 50,
                      child: SingleChildScrollView(
                        child: Text(value),
                      ),
                    ),
                  );
                }).toList(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter nurse names';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: InputDecoration(
                    labelText: 'Technologists (comma-separated)'),
                onSaved: (value) {
                  _technologists =
                      value!.split(',').map((e) => e.trim()).toList();
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter technologist names';
                  }
                  return null;
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
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                ),
                child: const Text('Add Surgery'),
              ),
              //New TextFormField for notes
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
              )
            ],
          ),
        ),
      ),
    );
  }
}

//notes (doctor, nurse)
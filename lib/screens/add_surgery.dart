import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AddSurgeryScreen extends StatefulWidget {
  @override
  _AddSurgeryScreenState createState() => _AddSurgeryScreenState();
}

class _AddSurgeryScreenState extends State<AddSurgeryScreen> {
  final _formKey = GlobalKey<FormState>();
  var _surgeryType = '';
  var _room = '';
  var _startTime = DateTime.now();
  var _endTime = DateTime.now().add(Duration(hours: 1));
  var _surgeon = '';
  var _nurses = [];
  var _technologists = [];
  var _status = 'Scheduled';

  Future<void> _submitForm() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) return;

    _formKey.currentState!.save();

    // Save to Firestore
    await FirebaseFirestore.instance.collection('surgeries').add({
      'surgeryType': _surgeryType,
      'room': _room,
      'startTime': Timestamp.fromDate(_startTime),
      'endTime': Timestamp.fromDate(_endTime),
      'surgeon': _surgeon,
      'nurses': _nurses,
      'technologists': _technologists,
      'status': _status,
    });

    Navigator.of(context).pop(); // Go back after adding surgery
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
              TextFormField(
                decoration: InputDecoration(labelText: 'Surgery Type'),
                onSaved: (value) {
                  _surgeryType = value!;
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the surgery type';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Room'),
                onSaved: (value) {
                  _room = value!;
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the room';
                  }
                  return null;
                },
              ),
              ListTile(
                title: Text('Start Time'),
                subtitle: Text(DateFormat('MMM dd, yyyy - hh:mm a').format(_startTime)),
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
                        _startTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
                      });
                    }
                  }
                },
              ),
              ListTile(
                title: Text('End Time'),
                subtitle: Text(DateFormat('MMM dd, yyyy - hh:mm a').format(_endTime)),
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
                        _endTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
                      });
                    }
                  }
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Surgeon'),
                onSaved: (value) {
                  _surgeon = value!;
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter surgeon name';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Nurses (comma-separated)'),
                onSaved: (value) {
                  _nurses = value!.split(',').map((e) => e.trim()).toList();
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter nurse names';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Technologists (comma-separated)'),
                onSaved: (value) {
                  _technologists = value!.split(',').map((e) => e.trim()).toList();
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
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: const Text('Add Surgery'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

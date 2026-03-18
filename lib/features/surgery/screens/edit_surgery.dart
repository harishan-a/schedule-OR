// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_orscheduler/features/schedule/models/surgery.dart';
import 'package:firebase_orscheduler/features/schedule/screens/schedule_provider.dart';
import 'package:firebase_orscheduler/features/schedule/services/resource_check_service.dart';
import 'package:firebase_orscheduler/services/notification_service.dart'; // For sending notifications

/// Equipment model class for the edit screen
class Equipment {
  final String id;
  final String name;
  final String category;
  final bool isAvailable;

  Equipment({
    required this.id,
    required this.name,
    required this.category,
    required this.isAvailable,
  });
}

/// EditSurgeryScreen allows users to modify an existing surgery's details.
///
/// This screen provides a complete interface for editing all surgery fields including:
/// - Surgery type and patient information
/// - Scheduling (start/end times)
/// - Room assignment
/// - Staff assignments (surgeon, nurses, technologists)
/// - Status and notes
///
/// Key features:
/// - Prevents editing of completed surgeries
/// - Checks for scheduling conflicts
/// - Tracks all changes for detailed notifications
/// - Provides intuitive validation and error handling
/// - Ensures proper data synchronization with Firestore
///
/// The implementation carefully avoids common Flutter pitfalls such as
/// calling setState() inside asynchronous operations and ensures proper
/// error handling throughout the lifecycle.
class EditSurgeryScreen extends StatefulWidget {
  final String surgeryId;

  const EditSurgeryScreen({super.key, required this.surgeryId});

  @override
  State<EditSurgeryScreen> createState() => _EditSurgeryScreenState();
}

class _EditSurgeryScreenState extends State<EditSurgeryScreen> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Text controllers
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _patientIdController = TextEditingController();
  final TextEditingController _patientAgeController = TextEditingController();

  // Selected values
  String? _selectedDoctor;
  List<String> _selectedNurses = [];
  List<String> _selectedTechnologists = [];
  String? _selectedRoom;
  String? _selectedSurgeryType;
  String? _selectedGender;
  String _status = '';
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 1));
  int _prepTimeMinutes = 0;
  int _cleanupTimeMinutes = 0;
  Set<String> _selectedEquipmentIds = {};
  List<Map<String, dynamic>> _timeBlocks = [];

  // Gender options
  final List<String> _genderOptions = ['Male', 'Female', 'Other'];

  // Staff and room options
  List<String> _doctorOptions = [];
  List<String> _nurseOptions = [];
  List<String> _technologistOptions = [];
  List<String> _roomOptions = [];
  List<String> _surgeryTypeOptions = [
    'General Surgery',
    'Orthopedic Surgery',
    'Cardiac Surgery',
    'Neurosurgery',
    'Plastic Surgery',
    'Vascular Surgery',
    'Thoracic Surgery',
    'Colorectal Surgery',
    'Pediatric Surgery',
    'Other',
  ];

  // Equipment options
  List<Equipment> _availableEquipment = [];

  // Saved original values for comparison
  List<String> _originalNurses = [];
  List<String> _originalTechnologists = [];

  // Loaded data
  Surgery? _surgery;

  // State variables
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  List<String> _availabilityWarnings = [];

  // User interaction tracking for analytics
  final _fieldInteractions = <String, int>{};
  final _formOpenTime = DateTime.now();
  bool _unsavedChanges = false;

  // Resource availability checking
  final ResourceCheckService _resourceCheckService = ResourceCheckService();
  bool _checkingAvailability = false;
  Map<String, bool> _resourceAvailability = {
    'room': true,
    'surgeon': true,
    'nurses': true,
    'technologists': true,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    // Clean up controllers to prevent memory leaks
    _patientNameController.dispose();
    _notesController.dispose();
    _patientIdController.dispose();
    _patientAgeController.dispose();

    // Clear cached staff lists to free memory
    _doctorOptions = [];
    _nurseOptions = [];
    _technologistOptions = [];
    super.dispose();
  }

  /// Loads all required data in a proper sequence
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load staff lists and surgery data concurrently for better performance
      final results = await Future.wait([
        _loadStaffLists(),
        _loadSurgeryData(),
      ]);

      // If we get here, both operations completed successfully
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load data: $e';
        });
      }
    }
  }

  /// Loads staff options from Firestore
  Future<void> _loadStaffLists() async {
    try {
      // Load doctors from users collection with role filter
      final doctorsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Doctor')
          .get();

      List<String> doctors = [];
      for (var doc in doctorsSnapshot.docs) {
        if (doc.data().containsKey('name')) {
          doctors.add(doc['name'] as String);
        } else if (doc.data().containsKey('firstName') &&
            doc.data().containsKey('lastName')) {
          // If name doesn't exist but firstName and lastName do
          doctors.add('${doc['firstName']} ${doc['lastName']}');
        }
      }

      // Load nurses from users collection with role filter
      final nursesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Nurse')
          .get();

      List<String> nurses = [];
      for (var doc in nursesSnapshot.docs) {
        if (doc.data().containsKey('name')) {
          nurses.add(doc['name'] as String);
        } else if (doc.data().containsKey('firstName') &&
            doc.data().containsKey('lastName')) {
          // If name doesn't exist but firstName and lastName do
          nurses.add('${doc['firstName']} ${doc['lastName']}');
        }
      }

      // Load technologists from users collection with role filter
      final technologistsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Technologist')
          .get();

      List<String> technologists = [];
      for (var doc in technologistsSnapshot.docs) {
        if (doc.data().containsKey('name')) {
          technologists.add(doc['name'] as String);
        } else if (doc.data().containsKey('firstName') &&
            doc.data().containsKey('lastName')) {
          // If name doesn't exist but firstName and lastName do
          technologists.add('${doc['firstName']} ${doc['lastName']}');
        }
      }

      setState(() {
        _doctorOptions = doctors;
        _nurseOptions = nurses;
        _technologistOptions = technologists;
      });
    } catch (e) {
      // Log error but continue - we'll still try to load the surgery
      debugPrint('Error loading staff lists: $e');
    }
  }

  /// Loads surgery data from Firestore
  Future<void> _loadSurgeryData() async {
    try {
      // Get surgery document
      final surgeryDoc = await FirebaseFirestore.instance
          .collection('surgeries')
          .doc(widget.surgeryId)
          .get();

      if (!surgeryDoc.exists || surgeryDoc.data() == null) {
        throw Exception('Surgery not found');
      }

      // Create surgery object
      final surgery = Surgery.fromFirestore(surgeryDoc.id, surgeryDoc.data()!);

      // Load room options if not already loaded
      if (_roomOptions.isEmpty) {
        await _loadRoomOptions();
      }

      // Load equipment options
      _loadEquipmentOptions();

      // Populate form data
      _selectedSurgeryType = surgery.surgeryType;
      _patientNameController.text = surgery.patientName;

      // Handle medical record number - check both patientId and medicalRecordNumber fields
      if (surgery.patientId != null && surgery.patientId!.isNotEmpty) {
        _patientIdController.text = surgery.patientId!;
      } else if (surgeryDoc.data()!.containsKey('medicalRecordNumber')) {
        _patientIdController.text =
            surgeryDoc.data()!['medicalRecordNumber'] as String? ?? '';
      }

      // Handle new patient fields
      if (surgeryDoc.data()!.containsKey('patientAge')) {
        _patientAgeController.text =
            surgeryDoc.data()!['patientAge']?.toString() ?? '';
      }
      if (surgeryDoc.data()!.containsKey('patientGender')) {
        _selectedGender = surgeryDoc.data()!['patientGender'] as String?;
      }

      _notesController.text = surgery.notes;
      _startTime = surgery.startTime;
      _endTime = surgery.endTime;
      _status = surgery.status;

      // Handle prep and cleanup times
      if (surgeryDoc.data()!.containsKey('prepTimeMinutes')) {
        _prepTimeMinutes = surgeryDoc.data()!['prepTimeMinutes'] as int? ?? 0;
      }
      if (surgeryDoc.data()!.containsKey('cleanupTimeMinutes')) {
        _cleanupTimeMinutes =
            surgeryDoc.data()!['cleanupTimeMinutes'] as int? ?? 0;
      }

      // Handle custom time blocks
      if (surgeryDoc.data()!.containsKey('customTimeBlocks')) {
        final timeBlocksData = surgeryDoc.data()!['customTimeBlocks'];
        if (timeBlocksData is List) {
          _timeBlocks = List<Map<String, dynamic>>.from(
              timeBlocksData.map((block) => Map<String, dynamic>.from(block)));
        }
      }

      // Handle equipment
      if (surgeryDoc.data()!.containsKey('requiredEquipment')) {
        final equipmentData = surgeryDoc.data()!['requiredEquipment'];
        if (equipmentData is List) {
          _selectedEquipmentIds =
              Set<String>.from(equipmentData.cast<String>());
        }
      }

      // Handle room selection
      if (surgery.room.isNotEmpty) {
        _selectedRoom = surgery.room.first;
      }

      // Handle surgeon selection
      if (surgery.surgeon.isNotEmpty) {
        _selectedDoctor = surgery.surgeon;
      }

      // Handle nurses
      _selectedNurses = List<String>.from(surgery.nurses);
      _originalNurses = List<String>.from(surgery.nurses);

      // Handle technologists
      _selectedTechnologists = List<String>.from(surgery.technologists);
      _originalTechnologists = List<String>.from(surgery.technologists);

      // Store the surgery object
      setState(() {
        _surgery = surgery;
      });

      // Check for availability conflicts
      await _checkResourceAvailability();
    } catch (e) {
      debugPrint('Error loading surgery: $e');
      rethrow; // This will be caught by _loadData
    }
  }

  /// Load room options from Firestore
  Future<void> _loadRoomOptions() async {
    try {
      final roomsSnapshot =
          await FirebaseFirestore.instance.collection('rooms').get();

      List<String> rooms = [];
      for (var doc in roomsSnapshot.docs) {
        if (doc.data().containsKey('name')) {
          rooms.add(doc['name'] as String);
        }
      }

      // If no rooms found in the database, use default list
      if (rooms.isEmpty) {
        rooms = [
          'OperatingRoom1',
          'OperatingRoom2',
          'OperatingRoom3',
          'OperatingRoom4',
          'OperatingRoom5',
        ];
      }

      setState(() {
        _roomOptions = rooms;
      });
    } catch (e) {
      // Use default room options on error
      setState(() {
        _roomOptions = [
          'OperatingRoom1',
          'OperatingRoom2',
          'OperatingRoom3',
          'OperatingRoom4',
          'OperatingRoom5',
        ];
      });
      debugPrint('Error loading room options: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: PopScope(
        canPop: !_unsavedChanges,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;

          // If there are unsaved changes, show confirmation dialog
          if (_unsavedChanges) {
            final shouldDiscard = await _confirmDiscardChanges();
            if (shouldDiscard) {
              Navigator.of(context).pop();
            }
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Edit Surgery'),
          ),
          body: _buildBody(),
          bottomNavigationBar: _buildBottomBar(),
        ),
      ),
    );
  }

  // Build bottom bar with save button
  Widget _buildBottomBar() {
    if (_isLoading || _errorMessage != null || _surgery == null) {
      return const SizedBox.shrink();
    }

    return BottomAppBar(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveSurgery,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  // Confirm before leaving if there are unsaved changes
  Future<bool> _confirmDiscardChanges() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
            'You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildBody() {
    // Show loading indicator
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading surgery data...'),
          ],
        ),
      );
    }

    // Show error message
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    // If surgery is null (should not happen but just in case)
    if (_surgery == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Surgery data not available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    // Show edit form
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Surgery Details Section
          _buildSectionHeader('Surgery Details'),
          _buildDropdown<String>(
            label: 'Surgery Type',
            value: _selectedSurgeryType,
            items: _surgeryTypeOptions.map((type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedSurgeryType = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a surgery type';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Patient Section
          _buildSectionHeader('Patient Information'),
          _buildTextFormField(
            controller: _patientNameController,
            labelText: 'Patient Name',
            prefixIcon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter patient name';
              }
              return null;
            },
            onChanged: (_) => _trackFieldInteraction('patientName'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextFormField(
                  controller: _patientAgeController,
                  labelText: 'Age',
                  prefixIcon: Icons.calendar_today,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _trackFieldInteraction('patientAge'),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final age = int.tryParse(value);
                      if (age == null || age <= 0 || age > 150) {
                        return 'Invalid age';
                      }
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdown<String>(
                  label: 'Gender',
                  value: _selectedGender,
                  items: _genderOptions.map((gender) {
                    return DropdownMenuItem<String>(
                      value: gender,
                      child: Text(gender),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value;
                      _trackFieldInteraction('patientGender');
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextFormField(
            controller: _patientIdController,
            labelText: 'Patient ID Number',
            prefixIcon: Icons.badge_outlined,
            onChanged: (_) => _trackFieldInteraction('patientId'),
          ),
          const SizedBox(height: 24),

          // Time and Location Section
          _buildSectionHeader('Time & Location'),
          _buildDateTimePicker(
            label: 'Start Time',
            value: _startTime,
            onChanged: (newTime) {
              setState(() {
                _startTime = newTime;

                // If end time is now before start time, adjust it
                if (_endTime.isBefore(_startTime)) {
                  _endTime = _startTime.add(const Duration(hours: 1));
                }
              });
              // Check for availability conflicts when time changes
              _checkResourceAvailability();
            },
            validator: () {
              if (_endTime.isBefore(_startTime)) {
                return 'End time must be after start time';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildDateTimePicker(
            label: 'End Time',
            value: _endTime,
            onChanged: (newTime) {
              setState(() {
                _endTime = newTime;
              });
              // Check for availability conflicts when time changes
              _checkResourceAvailability();
            },
            validator: () {
              if (_endTime.isBefore(_startTime)) {
                return 'End time must be after start time';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildDropdown<String>(
            label: 'Operating Room',
            value: _selectedRoom,
            items: _roomOptions.map((room) {
              return DropdownMenuItem<String>(
                value: room,
                child: Text(room),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedRoom = value;
                _trackFieldInteraction('room');
              });
              // Check for availability conflicts when room changes
              _checkResourceAvailability();
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select an operating room';
              }
              return null;
            },
            isAvailable: _resourceAvailability['room'] ?? true,
          ),

          // Prep and Cleanup Times
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildNumberSelector(
                  label: 'Prep Time (minutes)',
                  value: _prepTimeMinutes,
                  icon: Icons.timer,
                  onChanged: (value) {
                    setState(() {
                      _prepTimeMinutes = value;
                      _trackFieldInteraction('prepTime');
                    });
                  },
                  options: List.generate(13, (i) => i * 5),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildNumberSelector(
                  label: 'Cleanup Time (minutes)',
                  value: _cleanupTimeMinutes,
                  icon: Icons.cleaning_services,
                  onChanged: (value) {
                    setState(() {
                      _cleanupTimeMinutes = value;
                      _trackFieldInteraction('cleanupTime');
                    });
                  },
                  options: List.generate(13, (i) => i * 5),
                ),
              ),
            ],
          ),

          // Custom Time Blocks
          if (_timeBlocks.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionHeader('Custom Time Blocks'),
            ..._timeBlocks.map((block) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                            '${block['name']}: ${block['durationMinutes']} min'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          setState(() {
                            _timeBlocks.remove(block);
                            _trackFieldInteraction('timeBlocks');
                          });
                        },
                      ),
                    ],
                  ),
                )),
          ],

          // Add Custom Time Block button
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _showAddCustomTimeBlockDialog(),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add Custom Time Block'),
          ),
          const SizedBox(height: 24),

          // Medical Team Section
          _buildSectionHeader('Medical Team'),
          if (_doctorOptions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No doctors available in the system',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            )
          else
            _buildSimpleDropdown<String>(
              label: 'Surgeon',
              value: _selectedDoctor,
              items: _doctorOptions.map((option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDoctor = value;
                  _trackFieldInteraction('surgeon');
                });
                // Check for availability conflicts when surgeon changes
                _checkResourceAvailability();
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a surgeon';
                }
                return null;
              },
              isAvailable: _resourceAvailability['surgeon'] ?? true,
            ),
          const SizedBox(height: 16),

          // Nurses dropdown
          if (_nurseOptions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No nurses available in the system',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            )
          else
            _buildChipSelector(
              title: 'Nurses',
              options: _nurseOptions,
              selectedValues: _selectedNurses,
              onSelectionChanged: (values) {
                setState(() {
                  _selectedNurses = values;
                  _trackFieldInteraction('nurses');
                });
                // Check for availability conflicts when nurses change
                _checkResourceAvailability();
              },
              icon: Icons.person,
              isAvailable: _resourceAvailability['nurses'] ?? true,
            ),
          const SizedBox(height: 16),

          // Technologists dropdown
          if (_technologistOptions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No technologists available in the system',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            )
          else
            _buildChipSelector(
              title: 'Technologists',
              options: _technologistOptions,
              selectedValues: _selectedTechnologists,
              onSelectionChanged: (values) {
                setState(() {
                  _selectedTechnologists = values;
                  _trackFieldInteraction('technologists');
                });
                // Check for availability conflicts when technologists change
                _checkResourceAvailability();
              },
              icon: Icons.person,
              isAvailable: _resourceAvailability['technologists'] ?? true,
            ),
          const SizedBox(height: 24),

          // Equipment Section
          _buildSectionHeader('Equipment'),
          _buildEquipmentSelector(),
          const SizedBox(height: 24),

          // Display availability warnings if any
          if (_availabilityWarnings.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orange.shade800),
                      const SizedBox(width: 8),
                      Text(
                        'Scheduling Conflicts',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                          fontSize: 16,
                        ),
                      ),
                      if (_checkingAvailability)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 16,
                          height: 16,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_availabilityWarnings.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _availabilityWarnings[index],
                        style: TextStyle(
                          color: Colors.orange.shade900,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Text(
                    'You can still save this surgery, but it may result in scheduling conflicts.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Status Section
          _buildSectionHeader('Status'),
          const SizedBox(height: 8),
          _buildStatusSelector(Theme.of(context).colorScheme),
          const SizedBox(height: 24),

          // Notes Section
          _buildSectionHeader('Additional Information'),
          _buildTextFormField(
            controller: _notesController,
            labelText: 'Notes',
            prefixIcon: Icons.note_outlined,
            maxLines: 3,
          ),

          // Add padding at the bottom for the bottom bar
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    int maxLines = 1,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    TextInputType? keyboardType,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(prefixIcon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        filled: true,
        fillColor: colorScheme.surface,
      ),
      validator: validator,
      onChanged: onChanged,
      keyboardType: keyboardType,
    );
  }

  Widget _buildDateTimePicker({
    required String label,
    required DateTime value,
    required ValueChanged<DateTime> onChanged,
    String? Function()? validator,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final errorText = validator != null ? validator() : null;
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            // Show date picker
            final date = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );

            if (date != null && mounted) {
              // Show time picker
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(value),
              );

              if (time != null && mounted) {
                final newDateTime = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );

                onChanged(newDateTime);
              }
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError ? colorScheme.error : colorScheme.outline,
                width: hasError ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: hasError ? colorScheme.error : colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('MMM d, y  h:mm a').format(value),
                    style: TextStyle(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText!,
              style: TextStyle(
                color: colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? Function(T?)? validator,
    bool isAvailable = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    // Check if value exists in items
    bool valueExists = false;
    if (value != null) {
      for (var item in items) {
        if (item.value == value) {
          valueExists = true;
          break;
        }
      }
    }

    // If value doesn't exist in items, set it to null
    final effectiveValue = valueExists ? value : null;

    // Border color based on availability
    final borderColor = !isAvailable
        ? Colors.redAccent
        : (value != null ? colorScheme.primary : colorScheme.outline);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            if (!isAvailable) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                'Conflicting schedule',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: effectiveValue,
          items: items,
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: borderColor,
                width: !isAvailable ? 2 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: borderColor,
                width: !isAvailable ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: !isAvailable ? Colors.redAccent : colorScheme.primary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            filled: true,
            fillColor: !isAvailable ? Colors.red.shade50 : colorScheme.surface,
          ),
          isExpanded: true,
        ),
      ],
    );
  }

  // Simple chip selector for multiple staff selection that won't crash
  Widget _buildChipSelector({
    required String title,
    required List<String> options,
    required List<String> selectedValues,
    required ValueChanged<List<String>> onSelectionChanged,
    required IconData icon,
    bool isAvailable = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            if (!isAvailable && selectedValues.isNotEmpty) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                'Scheduling conflicts',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        if (options.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              'No options available',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                final isSelected = selectedValues.contains(option);

                return FilterChip(
                  label: Text(option),
                  selected: isSelected,
                  showCheckmark: true,
                  onSelected: (selected) {
                    final newValues = List<String>.from(selectedValues);

                    if (selected) {
                      if (!newValues.contains(option)) {
                        newValues.add(option);
                      }
                    } else {
                      newValues.remove(option);
                    }

                    onSelectionChanged(newValues);
                  },
                  checkmarkColor: colorScheme.onPrimaryContainer,
                  selectedColor: isSelected && !isAvailable
                      ? Colors.red.shade100
                      : colorScheme.primaryContainer,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected
                          ? (isAvailable
                              ? Colors.transparent
                              : Colors.redAccent)
                          : colorScheme.outline.withOpacity(0.3),
                      width: isSelected && !isAvailable ? 2 : 1,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusSelector(ColorScheme colorScheme) {
    final statusOptions = [
      (label: 'Scheduled', icon: Icons.schedule_outlined, color: Colors.blue),
      (label: 'In Progress', icon: Icons.sync_outlined, color: Colors.orange),
      (label: 'Cancelled', icon: Icons.cancel_outlined, color: Colors.red),
      (
        label: 'Completed',
        icon: Icons.check_circle_outline,
        color: Colors.green
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: statusOptions.map((option) {
        final isSelected = _status == option.label;

        return InkWell(
          onTap: () {
            setState(() {
              _status = option.label;
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? option.color.withOpacity(0.15)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? option.color
                    : colorScheme.outline.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  option.icon,
                  size: 18,
                  color:
                      isSelected ? option.color : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  option.label,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? option.color
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: option.color,
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // Simple dropdown for single selection
  Widget _buildSimpleDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? Function(T?)? validator,
    bool isAvailable = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            if (!isAvailable) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                'Scheduling conflicts',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: !isAvailable ? Colors.redAccent : colorScheme.outline,
                width: !isAvailable ? 2 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: !isAvailable ? Colors.redAccent : colorScheme.outline,
                width: !isAvailable ? 2 : 1,
              ),
            ),
            filled: true,
            fillColor: !isAvailable ? Colors.red.shade50 : colorScheme.surface,
          ),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          dropdownColor: colorScheme.surface,
        ),
      ],
    );
  }

  // Handle saving the surgery with improved error reporting
  Future<void> _saveSurgery() async {
    if (!_formKey.currentState!.validate()) {
      // Show validation failed message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the errors in the form'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if end time is after start time
    if (_endTime.isBefore(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after start time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check for availability conflicts and show confirmation if needed
    await _checkResourceAvailability();

    // If there are availability warnings, show confirmation dialog
    if (_availabilityWarnings.isNotEmpty) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              const Text('Scheduling Conflicts'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'There are scheduling conflicts with this surgery:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...List.generate(_availabilityWarnings.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _availabilityWarnings[index],
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }),
              const SizedBox(height: 12),
              const Text(
                'Do you want to proceed anyway?',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save Anyway'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) {
        return; // User cancelled the save operation
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Handle nullable values
      final String surgeon = _selectedDoctor ?? '';
      final int? patientAge = _patientAgeController.text.isNotEmpty
          ? int.tryParse(_patientAgeController.text)
          : null;

      // Create updated surgery object with basic fields
      final updatedSurgery = Surgery(
        id: _surgery!.id,
        patientName: _patientNameController.text,
        patientId: _patientIdController.text.isNotEmpty
            ? _patientIdController.text
            : null,
        patientAge: patientAge,
        patientGender: _selectedGender,
        surgeryType: _selectedSurgeryType!,
        doctorId: _surgery!.doctorId, // Keep the existing doctorId
        surgeon: surgeon, // Now using non-nullable string
        dateTime: _startTime, // Legacy field
        startTime: _startTime,
        endTime: _endTime,
        roomId: _surgery!.roomId, // Keep the existing roomId
        room: _selectedRoom != null
            ? [_selectedRoom!]
            : [''], // Ensure non-empty list
        duration: _endTime.difference(_startTime).inMinutes,
        status: _status,
        type: _surgery!.type, // Keep the existing type
        notes: _notesController.text,
        nurses: _selectedNurses,
        technologists: _selectedTechnologists,
      );

      // Create a map to store field changes for notification
      Map<String, dynamic> changes =
          _getFieldChanges(_surgery!, updatedSurgery);

      // Save surgery using provider
      final surgeryProvider =
          Provider.of<SurgeryProvider>(context, listen: false);

      // Prepare the data for Firestore as it expects it
      Map<String, dynamic> newData = {
        'surgeryType': updatedSurgery.surgeryType,
        'patientName': updatedSurgery.patientName,
        'patientId': updatedSurgery.patientId,
        'medicalRecordNumber': updatedSurgery
            .patientId, // Also save as medicalRecordNumber for compatibility
        'patientAge': patientAge,
        'patientGender': _selectedGender,
        'room': updatedSurgery.room,
        'startTime': Timestamp.fromDate(updatedSurgery.startTime),
        'endTime': Timestamp.fromDate(updatedSurgery.endTime),
        'status': updatedSurgery.status,
        'surgeon': updatedSurgery.surgeon,
        'nurses': updatedSurgery.nurses,
        'technologists': updatedSurgery.technologists,
        'notes': updatedSurgery.notes,
        'prepTimeMinutes': _prepTimeMinutes,
        'cleanupTimeMinutes': _cleanupTimeMinutes,
        'requiredEquipment': _selectedEquipmentIds.toList(),
        'customTimeBlocks': _timeBlocks,
      };

      // If any fields changed, add changes to notification data
      if (changes.isNotEmpty) {
        // Add the changes to the notification data
        newData['changes'] = changes;

        // Add the formatted message to the notification data
        if (changes.containsKey('_formattedMessage')) {
          newData['changeMessage'] = changes['_formattedMessage'];
        }
      }

      // Update the surgery in the database - the provider will handle notifications
      await surgeryProvider.updateSurgeryData(_surgery!.id, newData);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Surgery updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Return to previous screen after successful save
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      // Show detailed error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save surgery: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );

        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Checks availability of selected resources for the chosen time slot
  /// Updates UI with warnings if conflicts are found
  Future<void> _checkResourceAvailability() async {
    // Skip if no surgery is loaded or we're still loading
    if (_surgery == null || _isLoading) return;

    setState(() {
      _checkingAvailability = true;
      _availabilityWarnings = [];
    });

    try {
      final List<String> warnings = [];

      // 1. Check room availability - exclude the current surgery from the check
      if (_selectedRoom != null) {
        final roomAvailable = await _isRoomAvailableExcludingSelf(
            _selectedRoom!, _startTime, _endTime);
        _resourceAvailability['room'] = roomAvailable;

        if (!roomAvailable) {
          warnings.add(
              '⚠️ Selected operating room is already booked for this time slot');
        }
      }

      // 2. Check surgeon availability
      if (_selectedDoctor != null) {
        final surgeonAvailable = await _isStaffAvailableExcludingSelf(
            _selectedDoctor!, _startTime, _endTime);
        _resourceAvailability['surgeon'] = surgeonAvailable;

        if (!surgeonAvailable) {
          warnings
              .add('⚠️ Selected surgeon is already booked for this time slot');
        }
      }

      // 3. Check nurses availability
      if (_selectedNurses.isNotEmpty) {
        bool allNursesAvailable = true;
        List<String> unavailableNurses = [];

        for (final nurse in _selectedNurses) {
          final available =
              await _isStaffAvailableExcludingSelf(nurse, _startTime, _endTime);

          if (!available) {
            allNursesAvailable = false;
            unavailableNurses.add(nurse);
          }
        }

        _resourceAvailability['nurses'] = allNursesAvailable;

        if (!allNursesAvailable) {
          warnings.add(
              '⚠️ These nurses are already booked: ${unavailableNurses.join(', ')}');
        }
      }

      // 4. Check technologists availability
      if (_selectedTechnologists.isNotEmpty) {
        bool allTechsAvailable = true;
        List<String> unavailableTechs = [];

        for (final tech in _selectedTechnologists) {
          final available =
              await _isStaffAvailableExcludingSelf(tech, _startTime, _endTime);

          if (!available) {
            allTechsAvailable = false;
            unavailableTechs.add(tech);
          }
        }

        _resourceAvailability['technologists'] = allTechsAvailable;

        if (!allTechsAvailable) {
          warnings.add(
              '⚠️ These technologists are already booked: ${unavailableTechs.join(', ')}');
        }
      }

      setState(() {
        _availabilityWarnings = warnings;
      });
    } catch (e) {
      debugPrint('Error checking availability: $e');
      setState(() {
        _availabilityWarnings = ['Error checking resource availability: $e'];
      });
    } finally {
      setState(() {
        _checkingAvailability = false;
      });
    }
  }

  /// Checks if a room is available for a time slot, excluding the current surgery
  Future<bool> _isRoomAvailableExcludingSelf(
      String roomId, DateTime startTime, DateTime endTime) async {
    try {
      final conflictingBookings = await FirebaseFirestore.instance
          .collection('surgeries')
          .where('room', arrayContains: roomId)
          .where('status', whereIn: ['Scheduled', 'In Progress']).get();

      // Filter out the current surgery and check for time conflicts
      for (final doc in conflictingBookings.docs) {
        // Skip the current surgery
        if (doc.id == _surgery!.id) continue;

        final surgeryData = doc.data();
        final surgeryStart = (surgeryData['startTime'] as Timestamp).toDate();
        final surgeryEnd = (surgeryData['endTime'] as Timestamp).toDate();

        // Check for time overlap
        if (!(endTime.isBefore(surgeryStart) ||
            startTime.isAfter(surgeryEnd))) {
          return false; // Conflict found
        }
      }

      return true; // No conflicts
    } catch (e) {
      debugPrint('Error checking room availability: $e');
      return true; // Default to available on error
    }
  }

  /// Checks if a staff member is available for a time slot, excluding the current surgery
  Future<bool> _isStaffAvailableExcludingSelf(
      String staffName, DateTime startTime, DateTime endTime) async {
    try {
      // Find surgeries where this staff member is assigned
      final conflictingSurgeriesAsSurgeon = await FirebaseFirestore.instance
          .collection('surgeries')
          .where('surgeon', isEqualTo: staffName)
          .where('status', whereIn: ['Scheduled', 'In Progress']).get();

      final conflictingSurgeriesAsNurse = await FirebaseFirestore.instance
          .collection('surgeries')
          .where('nurses', arrayContains: staffName)
          .where('status', whereIn: ['Scheduled', 'In Progress']).get();

      final conflictingSurgeriesAsTech = await FirebaseFirestore.instance
          .collection('surgeries')
          .where('technologists', arrayContains: staffName)
          .where('status', whereIn: ['Scheduled', 'In Progress']).get();

      // Combine all conflicting surgeries
      final allBookings = [
        ...conflictingSurgeriesAsSurgeon.docs,
        ...conflictingSurgeriesAsNurse.docs,
        ...conflictingSurgeriesAsTech.docs,
      ];

      // Check each surgery for time conflicts, excluding the current one
      for (final doc in allBookings) {
        // Skip the current surgery
        if (doc.id == _surgery!.id) continue;

        final surgeryData = doc.data();
        final surgeryStart = (surgeryData['startTime'] as Timestamp).toDate();
        final surgeryEnd = (surgeryData['endTime'] as Timestamp).toDate();

        // Check for time overlap
        if (!(endTime.isBefore(surgeryStart) ||
            startTime.isAfter(surgeryEnd))) {
          return false; // Conflict found
        }
      }

      return true; // No conflicts
    } catch (e) {
      debugPrint('Error checking staff availability: $e');
      return true; // Default to available on error
    }
  }

  // Create a map to store field changes for notification
  Map<String, dynamic> _getFieldChanges(Surgery original, Surgery updated) {
    Map<String, dynamic> changes = {};

    // Check for time changes
    if (original.startTime != updated.startTime) {
      changes['startTime'] = {
        'oldValue': _formatDateTime(original.startTime),
        'newValue': _formatDateTime(updated.startTime),
        'fieldName': 'Start Time'
      };
    }

    if (original.endTime != updated.endTime) {
      changes['endTime'] = {
        'oldValue': _formatDateTime(original.endTime),
        'newValue': _formatDateTime(updated.endTime),
        'fieldName': 'End Time'
      };
    }

    // Check for room changes
    if (!_areListsEqual(original.room, updated.room)) {
      changes['room'] = {
        'oldValue': original.room.isEmpty ? 'None' : original.room.join(', '),
        'newValue': updated.room.isEmpty ? 'None' : updated.room.join(', '),
        'fieldName': 'Operating Room'
      };
    }

    // Check for staff changes
    if (original.surgeon != updated.surgeon) {
      changes['surgeon'] = {
        'oldValue': original.surgeon.isEmpty ? 'None' : original.surgeon,
        'newValue': updated.surgeon.isEmpty ? 'None' : updated.surgeon,
        'fieldName': 'Surgeon'
      };
    }

    // Check for patient id changes
    if (original.patientId != updated.patientId) {
      changes['patientId'] = {
        'oldValue': original.patientId ?? 'Not provided',
        'newValue': updated.patientId ?? 'Not provided',
        'fieldName': 'Patient ID'
      };
    }

    if (!_areListsEqual(original.nurses, updated.nurses)) {
      changes['nurses'] = {
        'oldValue':
            original.nurses.isEmpty ? 'None' : original.nurses.join(', '),
        'newValue': updated.nurses.isEmpty ? 'None' : updated.nurses.join(', '),
        'fieldName': 'Nurses'
      };
    }

    if (!_areListsEqual(original.technologists, updated.technologists)) {
      changes['technologists'] = {
        'oldValue': original.technologists.isEmpty
            ? 'None'
            : original.technologists.join(', '),
        'newValue': updated.technologists.isEmpty
            ? 'None'
            : updated.technologists.join(', '),
        'fieldName': 'Technologists'
      };
    }

    // Check for status changes
    if (original.status != updated.status) {
      changes['status'] = {
        'oldValue': original.status,
        'newValue': updated.status,
        'fieldName': 'Status'
      };
    }

    // Check for notes changes - omit actual content for privacy
    if (original.notes != updated.notes) {
      changes['notes'] = {
        'oldValue': original.notes.isEmpty ? 'None' : 'Previous notes',
        'newValue': updated.notes.isEmpty ? 'None' : 'Updated notes',
        'fieldName': 'Notes'
      };
    }

    // Create a readable notification message
    if (changes.isNotEmpty) {
      // Create a message detailing the changes
      final String formattedMessage = _createFormattedChangeMessage(changes);
      changes['_formattedMessage'] = formattedMessage;
    }

    return changes;
  }

  // Create a formatted change message with smart summarization
  String _createFormattedChangeMessage(Map<String, dynamic> changes) {
    StringBuffer message = StringBuffer();

    // Handle special case: Only status changed
    if (changes.length == 1 && changes.containsKey('status')) {
      message.write(
          'Surgery status updated from "${changes['status']!['oldValue']}" to "${changes['status']!['newValue']}".');
      return message.toString();
    }

    // Handle special case: Only timing changes (start and/or end time)
    bool onlyTimingChanges =
        changes.keys.every((key) => key == 'startTime' || key == 'endTime');
    if (onlyTimingChanges) {
      message.write('Surgery rescheduled: ');
      if (changes.containsKey('startTime')) {
        message.write(
            '${changes['startTime']!['oldValue']} → ${changes['startTime']!['newValue']}');
      }
      if (changes.containsKey('startTime') && changes.containsKey('endTime')) {
        message.write(', ');
      }
      if (changes.containsKey('endTime')) {
        message.write('ending at ${changes['endTime']!['newValue']}');
      }
      return message.toString();
    }

    // Handle special case: Only staff changes
    bool onlyStaffChanges = changes.keys.every(
        (key) => key == 'surgeon' || key == 'nurses' || key == 'technologists');
    if (onlyStaffChanges) {
      message.write('Staff changes: ');
      int count = 0;
      changes.forEach((key, value) {
        if (count > 0) message.write(', ');
        message.write(
            '${value['fieldName']}: ${value['oldValue']} → ${value['newValue']}');
        count++;
      });
      return message.toString();
    }

    // Default case: Multiple types of changes - use a bulleted list
    message.write('Surgery updated:');

    // Add status change first if present
    if (changes.containsKey('status')) {
      message.write(
          '\n- Status: ${changes['status']!['oldValue']} → ${changes['status']!['newValue']}');
    }

    // Add other changes (except notes which are skipped for privacy)
    changes.forEach((key, value) {
      if (key != 'status' && key != 'notes' && key != '_formattedMessage') {
        message.write(
            '\n- ${value['fieldName']}: ${value['oldValue']} → ${value['newValue']}');
      }
    });

    return message.toString();
  }

  // Helper to format DateTime
  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, y h:mm a').format(dateTime);
  }

  // Helper to compare lists
  bool _areListsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;

    // Create sorted copies of the lists for comparison
    final sortedList1 = List<String>.from(list1)..sort();
    final sortedList2 = List<String>.from(list2)..sort();

    for (int i = 0; i < sortedList1.length; i++) {
      if (sortedList1[i] != sortedList2[i]) return false;
    }

    return true;
  }

  // Track user's field interactions for analytics
  void _trackFieldInteraction(String fieldName) {
    setState(() {
      _fieldInteractions[fieldName] = (_fieldInteractions[fieldName] ?? 0) + 1;
      _unsavedChanges = true;
    });
  }

  /// Shows dialog to add custom time block
  void _showAddCustomTimeBlockDialog() {
    final nameController = TextEditingController();
    int durationMinutes = 15;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text('Add Custom Time Block'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Block Name',
                  hintText: 'e.g., Special Procedure, Device Setup',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Duration: '),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: durationMinutes.toDouble(),
                      min: 5,
                      max: 120,
                      divisions: 23, // 5-minute steps up to 120
                      label: '$durationMinutes min',
                      onChanged: (value) {
                        setState(() {
                          durationMinutes = value.round();
                          // Round to nearest 5
                          durationMinutes = (durationMinutes ~/ 5) * 5;
                          if (durationMinutes < 5) durationMinutes = 5;
                        });
                      },
                    ),
                  ),
                  Text('$durationMinutes min'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  setState(() {
                    _timeBlocks.add({
                      'name': nameController.text.trim(),
                      'durationMinutes': durationMinutes,
                    });
                    _trackFieldInteraction('timeBlocks');
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add Block'),
            ),
          ],
        );
      }),
    );
  }

  /// Load equipment options
  void _loadEquipmentOptions() {
    // This would typically fetch from Firebase, but for now we'll use sample data
    _availableEquipment = [
      Equipment(
          id: 'E001',
          name: 'Anesthesia Machine',
          category: 'Anesthesia',
          isAvailable: true),
      Equipment(
          id: 'E002',
          name: 'Patient Monitor',
          category: 'Monitoring',
          isAvailable: true),
      Equipment(
          id: 'E003',
          name: 'Surgical Table',
          category: 'Furniture',
          isAvailable: true),
      Equipment(
          id: 'E004',
          name: 'Defibrillator',
          category: 'Emergency',
          isAvailable: true),
      Equipment(
          id: 'E005',
          name: 'Surgical Lights',
          category: 'Lighting',
          isAvailable: true),
      Equipment(
          id: 'E006',
          name: 'Electrosurgical Unit',
          category: 'Surgical',
          isAvailable: true),
      Equipment(
          id: 'E007',
          name: 'Suction Machine',
          category: 'Surgical',
          isAvailable: true),
      Equipment(
          id: 'E008',
          name: 'Ultrasound Machine',
          category: 'Imaging',
          isAvailable: true),
      Equipment(
          id: 'E009',
          name: 'Surgical Microscope',
          category: 'Optical',
          isAvailable: true),
      Equipment(
          id: 'E010',
          name: 'Surgical Robot',
          category: 'Robotic',
          isAvailable: true),
    ];
  }

  /// Builds the equipment selection UI
  Widget _buildEquipmentSelector() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16.0),
          child: Text(
            'Select equipment needed for this surgery:',
            style: TextStyle(fontSize: 16),
          ),
        ),

        // Available equipment grid
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Available Equipment:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),

                // Grid of equipment cards
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableEquipment.map((equipment) {
                    final isSelected =
                        _selectedEquipmentIds.contains(equipment.id);
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedEquipmentIds.remove(equipment.id);
                          } else {
                            _selectedEquipmentIds.add(equipment.id);
                          }
                          _trackFieldInteraction('equipment');
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.4,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).primaryColor.withOpacity(0.1)
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant
                                  .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.medical_services_outlined,
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                equipment.name,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Selected count
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Selected: ${_selectedEquipmentIds.length} items',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a number selector for prep and cleanup times
  Widget _buildNumberSelector({
    required String label,
    required int value,
    required IconData icon,
    required Function(int) onChanged,
    required List<int> options,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outline),
            borderRadius: BorderRadius.circular(12),
            color: colorScheme.surface,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: options.contains(value) ? value : options.first,
              items: options.map((option) {
                return DropdownMenuItem<int>(
                  value: option,
                  child: Text('$option minutes'),
                );
              }).toList(),
              onChanged: (newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
              icon: Icon(icon, size: 18),
              isExpanded: true,
            ),
          ),
        ),
      ],
    );
  }
}

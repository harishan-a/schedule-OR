// =============================================================================
// Add Surgery Screen
// =============================================================================
// A comprehensive form screen for scheduling new surgeries with features:
// - Patient information entry
// - Surgery details selection
// - Medical team assignment
// - Resource conflict checking
// - Auto-save functionality
//
// Form Sections:
// 1. Patient Details (name, age, gender, medical record)
// 2. Surgery Information (type, room, date/time)
// 3. Staff Assignment (surgeon, nurses, technologist)
// 4. Additional Notes
//
// State Management:
// - Form auto-saves every 30 seconds
// - Unsaved changes detection
// - Form state persistence across sessions
//
// Validation:
// - Required field checking
// - Time slot validation
// - Resource conflict detection
// - Staff availability verification
//
// Note: This screen implements a multi-step form with preview functionality
// and comprehensive validation before submission to Firestore.
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

import '../../../features/doctor/screens/doctor_page.dart';
import '../../../features/profile/screens/profile.dart';
import '../../../features/schedule/screens/resource_check.dart';
import '../../../features/schedule/screens/schedule.dart';
import 'package:firebase_orscheduler/shared/widgets/custom_navigation_bar.dart';

/// Screen for adding new surgeries with auto-save and validation
class AddSurgeryScreen extends StatefulWidget {
  final bool isTestMode;
  const AddSurgeryScreen({super.key, this.isTestMode = false});

  @override
  AddSurgeryScreenState createState() => AddSurgeryScreenState();
}

class AddSurgeryScreenState extends State<AddSurgeryScreen>
    with SingleTickerProviderStateMixin {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Loading and submission states
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _showPreview = false;
  bool _hasUnsavedChanges = false;

  // Surgery details
  String? _surgeryType;
  String? _operatingRoom;
  String? _selectedDoctor;
  List<String> _selectedNurses = [];
  String? _notes;
  String? _selectedTechnologist;
  String _status = 'Scheduled'; // Default status for new surgeries

  // Navigation state
  int _selectedIndex = 2; // Index for Add Surgery tab

  // Patient information controllers
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _patientAgeController = TextEditingController();
  final TextEditingController _medicalRecordController =
      TextEditingController();
  String? _patientGender;

  // Available options for dropdowns
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

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];

  // Time selection
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 1));

  // Staff lists populated from Firestore
  List<String> _technologists = [];
  List<String> _doctors = [];
  List<String> _nurses = [];

  // Animation controller for transitions
  late AnimationController _animationController;

  // Auto-save timer
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    if (widget.isTestMode) {
      _doctors = ['Dr. Test'];
      _nurses = ['Nurse Test'];
      _technologists = ['Tech Test'];
    } else {
      _loadData();  // Actual Firestore calls to fetch data.
    }
    //_loadData(); // Load staff lists
    _loadSavedForm(); // Restore saved form state
    _setupAutoSave(); // Start auto-save timer
  }

  /// Initializes auto-save functionality
  void _setupAutoSave() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_hasUnsavedChanges) {
        _saveFormState();
      }
    });
  }

  /// Loads saved form state from SharedPreferences
  Future<void> _loadSavedForm() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedForm = prefs.getString('surgery_form');
      if (savedForm != null) {
        final formData = json.decode(savedForm);
        setState(() {
          // Restore all form fields
          _patientNameController.text = formData['patientName'] ?? '';
          _patientAgeController.text = formData['patientAge'] ?? '';
          _patientGender = formData['patientGender'];
          _medicalRecordController.text = formData['medicalRecord'] ?? '';
          _surgeryType = formData['surgeryType'];
          _operatingRoom = formData['operatingRoom'];
          _selectedDoctor = formData['selectedDoctor'];
          _selectedNurses = List<String>.from(formData['selectedNurses'] ?? []);
          _selectedTechnologist = formData['selectedTechnologist'];
          _notes = formData['notes'];

          // Parse dates with null safety
          if (formData['startTime'] != null) {
            _startTime = DateTime.parse(formData['startTime']);
          }
          if (formData['endTime'] != null) {
            _endTime = DateTime.parse(formData['endTime']);
          }
        });

        // Show restoration notification
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Restored previous form data'),
              action: SnackBarAction(
                label: 'Clear',
                onPressed: _clearSavedForm,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading saved form: $e');
    }
  }

  /// Saves current form state to SharedPreferences
  Future<void> _saveFormState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final formData = {
        'patientName': _patientNameController.text,
        'patientAge': _patientAgeController.text,
        'patientGender': _patientGender,
        'medicalRecord': _medicalRecordController.text,
        'surgeryType': _surgeryType,
        'operatingRoom': _operatingRoom,
        'selectedDoctor': _selectedDoctor,
        'selectedNurses': _selectedNurses,
        'selectedTechnologist': _selectedTechnologist,
        'notes': _notes,
        'startTime': _startTime.toIso8601String(),
        'endTime': _endTime.toIso8601String(),
      };
      await prefs.setString('surgery_form', json.encode(formData));
      _hasUnsavedChanges = false;
    } catch (e) {
      debugPrint('Error saving form state: $e');
    }
  }

  /// Clears saved form data and resets all fields
  Future<void> _clearSavedForm() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('surgery_form');
      setState(() {
        // Reset all form fields to defaults
        _patientNameController.clear();
        _patientAgeController.clear();
        _patientGender = null;
        _medicalRecordController.clear();
        _surgeryType = null;
        _operatingRoom = null;
        _selectedDoctor = null;
        _selectedNurses = [];
        _selectedTechnologist = null;
        _notes = null;
        _startTime = DateTime.now();
        _endTime = DateTime.now().add(const Duration(hours: 1));
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Form data cleared')),
        );
      }
    } catch (e) {
      debugPrint('Error clearing form: $e');
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _animationController.dispose();
    _patientNameController.dispose();
    _patientAgeController.dispose();
    _medicalRecordController.dispose();
    super.dispose();
  }

  /// Handles navigation between main app screens
  ///
  /// Index mapping:
  /// - 0: Schedule screen
  /// - 1: Schedule screen (alternate view)
  /// - 2: Add surgery screen (current)
  /// - 3: Profile screen
  /// - 4: Doctor page
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (ctx) => const ScheduleScreen()));
        break;
      case 1:
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (ctx) => ScheduleScreen()));
        break;
      case 2:
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (ctx) => AddSurgeryScreen()));
        break;
      case 3:
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (ctx) => const ProfileScreen()));
        break;
      case 4:
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (ctx) => const DoctorPage()));
        break;
    }
  }

  /// Fetches list of technologists from Firestore
  ///
  /// Queries users collection for technologist role
  /// Returns sorted list of full names
  Future<void> _fetchTechnologists() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Technologist')
          .get();

      if (!mounted) return;

      setState(() {
        _technologists = snapshot.docs
            .map((doc) => '${doc['firstName']} ${doc['lastName']}')
            .toList()
          ..sort();
      });
    } catch (error) {
      debugPrint("Error fetching technologists: $error");
      rethrow;
    }
  }

  /// Fetches list of doctors from Firestore
  ///
  /// Queries users collection for doctor role
  /// Returns sorted list of full names
  Future<void> _fetchDoctors() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Doctor')
          .get();

      if (!mounted) return;

      setState(() {
        _doctors = snapshot.docs
            .map((doc) => '${doc['firstName']} ${doc['lastName']}')
            .toList()
          ..sort();
      });
    } catch (error) {
      debugPrint("Error fetching doctors: $error");
      rethrow;
    }
  }

  /// Fetches list of nurses from Firestore
  ///
  /// Queries users collection for nurse role
  /// Returns sorted list of full names
  Future<void> _fetchNurses() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Nurse')
          .get();

      if (!mounted) return;

      setState(() {
        _nurses = snapshot.docs
            .map((doc) => '${doc['firstName']} ${doc['lastName']}')
            .toList()
          ..sort();
      });
    } catch (error) {
      debugPrint("Error fetching nurses: $error");
      rethrow;
    }
  }

  /// Checks for scheduling conflicts with existing surgeries
  ///
  /// Verifies availability for:
  /// - Selected surgeon
  /// - Selected nurses
  /// - Selected technologist
  /// - Selected operating room
  ///
  /// Returns true if conflicts found, false otherwise
  Future<bool> _checkConflicts() async {
    try {
      // Show loading indicator
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checking for scheduling conflicts...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Check surgeon conflicts
      var surgeonConflicts = await FirebaseFirestore.instance
          .collection('surgeries')
          .where('surgeon', isEqualTo: _selectedDoctor)
          .where('status', whereIn: ['Scheduled', 'In Progress']).get();

      for (var doc in surgeonConflicts.docs) {
        Timestamp surgeryStart = doc.data()['startTime'];
        Timestamp surgeryEnd = doc.data()['endTime'];

        if (_startTime.isBefore(surgeryEnd.toDate()) &&
            _endTime.isAfter(surgeryStart.toDate())) {
          if (!mounted) return true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Conflict: Dr. $_selectedDoctor has another surgery scheduled at this time.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
          return true;
        }
      }

      // Check nurse conflicts
      for (var nurse in _selectedNurses) {
        var nurseConflicts = await FirebaseFirestore.instance
            .collection('surgeries')
            .where('nurses', arrayContains: nurse)
            .where('status', whereIn: ['Scheduled', 'In Progress']).get();

        for (var doc in nurseConflicts.docs) {
          Timestamp surgeryStart = doc.data()['startTime'];
          Timestamp surgeryEnd = doc.data()['endTime'];

          if (_startTime.isBefore(surgeryEnd.toDate()) &&
              _endTime.isAfter(surgeryStart.toDate())) {
            if (!mounted) return true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Conflict: Nurse $nurse has another surgery scheduled at this time.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
            return true;
          }
        }
      }

      // Check technologist conflicts
      if (_selectedTechnologist != null) {
        var techConflicts = await FirebaseFirestore.instance
            .collection('surgeries')
            .where('technologists', arrayContains: _selectedTechnologist)
            .where('status', whereIn: ['Scheduled', 'In Progress']).get();

        for (var doc in techConflicts.docs) {
          Timestamp surgeryStart = doc.data()['startTime'];
          Timestamp surgeryEnd = doc.data()['endTime'];

          if (_startTime.isBefore(surgeryEnd.toDate()) &&
              _endTime.isAfter(surgeryStart.toDate())) {
            if (!mounted) return true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Conflict: Technologist $_selectedTechnologist has another surgery scheduled at this time.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
            return true;
          }
        }
      }

      // Check room conflicts
      if (_operatingRoom != null) {
        var roomConflicts = await FirebaseFirestore.instance
            .collection('surgeries')
            .where('room', isEqualTo: _operatingRoom)
            .where('status', whereIn: ['Scheduled', 'In Progress']).get();

        for (var doc in roomConflicts.docs) {
          Timestamp surgeryStart = doc.data()['startTime'];
          Timestamp surgeryEnd = doc.data()['endTime'];

          if (_startTime.isBefore(surgeryEnd.toDate()) &&
              _endTime.isAfter(surgeryStart.toDate())) {
            if (!mounted) return true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Conflict: $_operatingRoom is already booked for this time slot.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
            return true;
          }
        }
      }

      return false;
    } catch (error) {
      debugPrint("Error checking conflicts: $error");
      if (!mounted) return true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('Error checking for conflicts. Please try again.'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () async {
              final hasConflicts = await _checkConflicts();
              if (!hasConflicts && mounted) {
                _confirmAndSubmit();
              }
            },
            textColor: Colors.white,
          ),
        ),
      );
      return true;
    }
  }

  /// Validates form data and shows preview if valid
  ///
  /// Checks:
  /// - Required fields
  /// - Time slot validity
  /// - Staff selections
  Future<void> _submitForm() async {
    if (!_validateForm()) return;

    _formKey.currentState!.save();
    await _saveFormState(); // Save form state before preview

    setState(() {
      _showPreview = true;
    });
  }

  /// Validates form data and submits to Firestore
  ///
  /// Process:
  /// 1. Check for conflicts
  /// 2. Show loading indicator
  /// 3. Save to Firestore
  /// 4. Show success dialog
  Future<void> _confirmAndSubmit() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Check for conflicts before adding
      bool hasConflicts = await _checkConflicts();
      if (hasConflicts) {
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      // Show loading indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scheduling surgery...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Save to Firestore
      await FirebaseFirestore.instance.collection('surgeries').add({
        'surgeryType': _surgeryType,
        'room': _operatingRoom,
        'startTime': Timestamp.fromDate(_startTime),
        'endTime': Timestamp.fromDate(_endTime),
        'surgeon': _selectedDoctor,
        'nurses': _selectedNurses,
        'technologists':
            _selectedTechnologist != null ? [_selectedTechnologist] : [],
        'status': _status,
        'notes': _notes,
        'patientName': _patientNameController.text,
        'patientAge': int.tryParse(_patientAgeController.text),
        'patientGender': _patientGender,
        'medicalRecordNumber': _medicalRecordController.text,
        'createdAt': Timestamp.now(),
        'lastUpdated': Timestamp.now(),
      });

      if (!mounted) return;

      // Show success animation
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Surgery Scheduled!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Surgery for ${_patientNameController.text} has been successfully scheduled.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('MMM dd, yyyy  hh:mm a').format(_startTime),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (context) => const AddSurgeryScreen()),
                          (Route<dynamic> route) => false,
                        );
                      },
                      child: const Text('Schedule Another'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (context) => const ScheduleScreen()),
                          (Route<dynamic> route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                      ),
                      child: const Text('View Schedule'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      debugPrint("Error adding surgery: $error");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to schedule surgery. Please try again.'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _confirmAndSubmit,
            textColor: Colors.white,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _showPreview = false;
        });
      }
    }
  }

  /// Builds the main UI with theme-aware styling
  ///
  /// Features:
  /// - Dark mode support
  /// - Responsive layout
  /// - Form sections
  /// - Preview mode
  @override
  Widget build(BuildContext context) {
    // Theme-aware colors
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final cardColor = isDarkMode ? Colors.grey[850]! : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final hintColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final fillColor = isDarkMode ? Colors.grey[800]! : Colors.grey[50]!;
    final borderColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;

    return WillPopScope(
      onWillPop: () async {
        // Check for unsaved changes before popping
        if (_hasUnsavedChanges) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Unsaved Changes'),
              content: const Text(
                  'You have unsaved changes. Do you want to discard them?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _showPreview ? 'Preview Surgery Details' : 'Schedule New Surgery',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          actions: [
            if (!_showPreview)
              IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: () => _showHelpDialog(context),
              ),
          ],
          leading: _showPreview
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _showPreview = false),
                )
              : null,
        ),
        body: _isLoading
            ? _buildLoadingIndicator(textColor)
            : _showPreview
                ? _buildPreview(context, cardColor, textColor, borderColor)
                : _buildForm(context, backgroundColor, cardColor, textColor,
                    fillColor, borderColor, hintColor),
        bottomNavigationBar: CustomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  /// Builds centered loading indicator with text
  Widget _buildLoadingIndicator(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading...',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the quick actions card for common operations
  ///
  /// Features:
  /// - Resource check button
  /// - View schedule button
  /// - Theme-aware styling
  Widget _buildQuickActionsCard(
      BuildContext context, Color cardColor, Color textColor) {
    return Card(
      elevation: 2,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickActionButton(
                    context,
                    'Check Resources',
                    Icons.analytics,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ResourceCheck()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildQuickActionButton(
                    context,
                    'View Schedule',
                    Icons.calendar_today,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ScheduleScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a quick action button with icon and label
  Widget _buildQuickActionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds section titles with consistent styling
  Widget _buildSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  /// Creates consistent input decoration for form fields
  ///
  /// Parameters:
  /// - label: Field label text
  /// - icon: Leading icon
  /// - fillColor: Background color
  /// - borderColor: Border color
  InputDecoration _getInputDecoration(
    String label,
    IconData icon,
    Color fillColor,
    Color borderColor,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      filled: true,
      fillColor: fillColor,
    );
  }

  /// Builds an enhanced date/time picker with formatting
  Widget _buildEnhancedDateTimePicker(
    BuildContext context,
    String label,
    DateTime initialDate,
    IconData icon,
    Function(DateTime?) onDateTimeChanged,
    Color fillColor,
    Color borderColor,
    Color textColor,
    bool isDarkMode,
  ) {
    return InkWell(
      onTap: () async {
        final DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (BuildContext context, Widget? child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                      surface: isDarkMode ? Colors.grey[850] : Colors.white,
                    ),
              ),
              child: child ?? const SizedBox(),
            );
          },
        );
        if (pickedDate != null) {
          final TimeOfDay? pickedTime = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(initialDate),
            builder: (BuildContext context, Widget? child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  timePickerTheme: TimePickerThemeData(
                    backgroundColor:
                        isDarkMode ? Colors.grey[850] : Colors.white,
                    hourMinuteShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                child: child ?? const SizedBox(),
              );
            },
            initialEntryMode: TimePickerEntryMode.input,
          );
          if (pickedTime != null) {
            // Round minutes to nearest 5
            final int roundedMinute = ((pickedTime.minute + 2) ~/ 5) * 5;
            final DateTime combinedDateTime = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              roundedMinute,
            );
            onDateTimeChanged(combinedDateTime);
          }
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borderColor),
          ),
          filled: true,
          fillColor: fillColor,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                DateFormat('MMM dd, yyyy  hh:mm a').format(initialDate),
                style: TextStyle(fontSize: 16, color: textColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.calendar_today, color: textColor.withOpacity(0.7)),
          ],
        ),
      ),
    );
  }

  /// Builds the form with theme-aware styling
  Widget _buildForm(
    BuildContext context,
    Color backgroundColor,
    Color cardColor,
    Color textColor,
    Color fillColor,
    Color borderColor,
    Color hintColor,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).primaryColor.withOpacity(isDarkMode ? 0.2 : 0.05),
            backgroundColor,
          ],
        ),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Actions Section
              _buildQuickActionsCard(context, cardColor, textColor),
              const SizedBox(height: 24),

              // Patient Information Section
              _buildSectionTitle('Patient Information', textColor),
              Card(
                elevation: 2,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _patientNameController,
                        style: TextStyle(color: textColor),
                        decoration: _getInputDecoration(
                          'Patient Name',
                          Icons.person,
                          fillColor,
                          borderColor,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter patient name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _patientAgeController,
                              style: TextStyle(color: textColor),
                              decoration: _getInputDecoration(
                                'Age',
                                Icons.calendar_today,
                                fillColor,
                                borderColor,
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                final age = int.tryParse(value);
                                if (age == null || age <= 0 || age > 150) {
                                  return 'Invalid age';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: _getInputDecoration(
                                'Gender',
                                Icons.people,
                                fillColor,
                                borderColor,
                              ),
                              value: _patientGender,
                              items: _genderOptions.map((String gender) {
                                return DropdownMenuItem(
                                  value: gender,
                                  child: Text(gender,
                                      style: TextStyle(color: textColor)),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _patientGender = newValue;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                              dropdownColor: cardColor,
                              style: TextStyle(color: textColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _medicalRecordController,
                        style: TextStyle(color: textColor),
                        decoration: _getInputDecoration(
                          'Medical Record Number',
                          Icons.folder,
                          fillColor,
                          borderColor,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter medical record number';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Surgery Type Section
              _buildSectionTitle('Surgery Details', textColor),
              Card(
                elevation: 2,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: _getInputDecoration(
                          'Surgery Type',
                          Icons.medical_services,
                          fillColor,
                          borderColor,
                        ),
                        value: _surgeryType,
                        items: _surgeryTypes.map((String type) {
                          return DropdownMenuItem(
                            value: type,
                            child:
                                Text(type, style: TextStyle(color: textColor)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _surgeryType = newValue;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a surgery type';
                          }
                          return null;
                        },
                        dropdownColor: cardColor,
                        style: TextStyle(color: textColor),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: _getInputDecoration(
                          'Operating Room',
                          Icons.room,
                          fillColor,
                          borderColor,
                        ),
                        value: _operatingRoom,
                        items: _room.map((String room) {
                          return DropdownMenuItem(
                            value: room,
                            child:
                                Text(room, style: TextStyle(color: textColor)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _operatingRoom = newValue;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select an operating room';
                          }
                          return null;
                        },
                        dropdownColor: cardColor,
                        style: TextStyle(color: textColor),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Time Selection Section
              _buildSectionTitle('Schedule', textColor),
              Card(
                elevation: 2,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEnhancedDateTimePicker(
                        context,
                        'Start Time',
                        _startTime,
                        Icons.access_time,
                        (DateTime? newDateTime) {
                          if (newDateTime != null) {
                            setState(() {
                              _startTime = newDateTime;
                              // Automatically set end time to 1 hour after start time
                              _endTime =
                                  newDateTime.add(const Duration(hours: 1));
                            });
                          }
                        },
                        fillColor,
                        borderColor,
                        textColor,
                        isDarkMode,
                      ),
                      const SizedBox(height: 16),
                      _buildEnhancedDateTimePicker(
                        context,
                        'End Time',
                        _endTime,
                        Icons.access_time,
                        (DateTime? newDateTime) {
                          if (newDateTime != null) {
                            setState(() {
                              _endTime = newDateTime;
                            });
                          }
                        },
                        fillColor,
                        borderColor,
                        textColor,
                        isDarkMode,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Duration: ${_formatDuration(_startTime, _endTime)}',
                        style: TextStyle(
                          color: hintColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Staff Selection Section
              _buildSectionTitle('Medical Team', textColor),
              Card(
                elevation: 2,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownSearch<String>(
                        items: _doctors,
                        dropdownDecoratorProps: DropDownDecoratorProps(
                          dropdownSearchDecoration: _getInputDecoration(
                            'Select Surgeon',
                            Icons.person,
                            fillColor,
                            borderColor,
                          ),
                        ),
                        popupProps: PopupProps.menu(
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(
                            decoration: InputDecoration(
                              hintText: 'Search surgeon...',
                              hintStyle: TextStyle(color: hintColor),
                              prefixIcon: Icon(Icons.search, color: hintColor),
                              filled: true,
                              fillColor: fillColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: borderColor),
                              ),
                            ),
                          ),
                          menuProps: MenuProps(
                            backgroundColor: cardColor,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _selectedDoctor = value;
                          });
                        },
                        selectedItem: _selectedDoctor,
                      ),
                      const SizedBox(height: 16),
                      MultiSelectDialogField<String>(
                        items: _nurses
                            .map((nurse) =>
                                MultiSelectItem<String>(nurse, nurse))
                            .toList(),
                        title: Text("Select Nurses",
                            style: TextStyle(color: textColor)),
                        selectedColor: Theme.of(context).primaryColor,
                        decoration: BoxDecoration(
                          color: fillColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        buttonIcon:
                            Icon(Icons.arrow_drop_down, color: textColor),
                        buttonText: Text(
                          "Select Nurses",
                          style: TextStyle(fontSize: 16, color: textColor),
                        ),
                        onConfirm: (values) {
                          setState(() {
                            _selectedNurses = values;
                          });
                        },
                        chipDisplay: MultiSelectChipDisplay(
                          onTap: (value) {
                            setState(() {
                              _selectedNurses.remove(value);
                            });
                          },
                          chipColor:
                              Theme.of(context).primaryColor.withOpacity(0.1),
                          textStyle: TextStyle(color: textColor),
                        ),
                        backgroundColor: cardColor,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: _getInputDecoration(
                          'Select Technologist',
                          Icons.engineering,
                          fillColor,
                          borderColor,
                        ),
                        value: _selectedTechnologist,
                        items: _technologists.map((String tech) {
                          return DropdownMenuItem(
                            value: tech,
                            child:
                                Text(tech, style: TextStyle(color: textColor)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedTechnologist = newValue;
                          });
                        },
                        dropdownColor: cardColor,
                        style: TextStyle(color: textColor),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Notes Section
              _buildSectionTitle('Additional Notes', textColor),
              Card(
                elevation: 2,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextFormField(
                    maxLines: 3,
                    style: TextStyle(color: textColor),
                    decoration: _getInputDecoration(
                      'Enter any additional notes or requirements...',
                      Icons.note,
                      fillColor,
                      borderColor,
                    ),
                    onSaved: (value) {
                      _notes = value;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Preview Surgery Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the preview screen for surgery details
  ///
  /// Features:
  /// - Organized sections
  /// - Theme-aware styling
  /// - Edit and confirm buttons
  Widget _buildPreview(BuildContext context, Color cardColor, Color textColor,
      Color borderColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPreviewSection(
            'Patient Information',
            [
              _buildPreviewItem('Name', _patientNameController.text),
              _buildPreviewItem('Age', _patientAgeController.text),
              _buildPreviewItem('Gender', _patientGender ?? ''),
              _buildPreviewItem(
                  'Medical Record', _medicalRecordController.text),
            ],
            cardColor,
            textColor,
            borderColor,
          ),
          const SizedBox(height: 16),
          _buildPreviewSection(
            'Surgery Details',
            [
              _buildPreviewItem('Type', _surgeryType ?? ''),
              _buildPreviewItem('Room', _operatingRoom ?? ''),
              _buildPreviewItem(
                  'Date', DateFormat('MMM dd, yyyy').format(_startTime)),
              _buildPreviewItem('Time',
                  '${DateFormat('hh:mm a').format(_startTime)} - ${DateFormat('hh:mm a').format(_endTime)}'),
              _buildPreviewItem(
                  'Duration', _formatDuration(_startTime, _endTime)),
            ],
            cardColor,
            textColor,
            borderColor,
          ),
          const SizedBox(height: 16),
          _buildPreviewSection(
            'Medical Team',
            [
              _buildPreviewItem('Surgeon', _selectedDoctor ?? ''),
              _buildPreviewItem('Nurses', _selectedNurses.join(', ')),
              if (_selectedTechnologist != null)
                _buildPreviewItem('Technologist', _selectedTechnologist!),
            ],
            cardColor,
            textColor,
            borderColor,
          ),
          const SizedBox(height: 16),
          if (_notes?.isNotEmpty ?? false)
            _buildPreviewSection(
              'Additional Notes',
              [_buildPreviewItem('Notes', _notes!)],
              cardColor,
              textColor,
              borderColor,
            ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _showPreview = false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _confirmAndSubmit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Confirm & Schedule'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a section in the preview screen
  ///
  /// Parameters:
  /// - title: Section header text
  /// - children: List of preview items
  /// - cardColor: Background color
  /// - textColor: Text color
  /// - borderColor: Border color
  Widget _buildPreviewSection(
    String title,
    List<Widget> children,
    Color cardColor,
    Color textColor,
    Color borderColor,
  ) {
    return Card(
      elevation: 2,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Builds a preview item with label and value
  ///
  /// Parameters:
  /// - label: Item label
  /// - value: Item value
  Widget _buildPreviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
              ),
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  /// Formats duration between two dates
  ///
  /// Returns formatted string like "2 hr 30 min"
  String _formatDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '$hours hr ${minutes.toString().padLeft(2, '0')} min';
  }

  /// Shows help dialog with tips and instructions
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Tips'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('• Surgery type and operating room are required fields'),
              SizedBox(height: 8),
              Text('• Time slots are available in 5-minute intervals'),
              SizedBox(height: 8),
              Text(
                  '• End time is automatically set to 1 hour after start time'),
              SizedBox(height: 8),
              Text('• You can search for staff members using the search box'),
              SizedBox(height: 8),
              Text('• Multiple nurses can be selected for the surgery'),
              SizedBox(height: 8),
              Text('• Use the quick actions to check resource availability'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  // Update the form fields to mark unsaved changes
  void _markUnsavedChanges() {
    setState(() {
      _hasUnsavedChanges = true;
    });
  }

  // Enhanced validation for the form
  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields correctly'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (_selectedNurses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one nurse'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (_endTime.isBefore(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after start time'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    // Check if surgery duration is within reasonable limits (e.g., 30 min to 12 hours)
    final duration = _endTime.difference(_startTime);
    if (duration.inMinutes < 30 || duration.inHours > 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Surgery duration must be between 30 minutes and 12 hours'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

  // Add tooltips to form fields
  Widget _buildTooltip(Widget child, String message) {
    return Tooltip(
      message: message,
      preferBelow: false,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white),
      child: child,
    );
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _fetchDoctors(),
        _fetchNurses(),
        _fetchTechnologists(),
      ]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to load data. Please try again.'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _loadData,
            textColor: Colors.white,
          ),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }
}

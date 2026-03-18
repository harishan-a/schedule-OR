// =============================================================================
// Add Surgery Screen
// =============================================================================
// A comprehensive form screen for scheduling new surgeries with features:
// - Patient information entry
// - Surgery details selection
// - Medical team assignment
// - Resource conflict checking
// - Equipment selection interface
// - Time conflict visualization
//
// Form Sections:
// 1. Patient Details (name, age, gender, medical record)
// 2. Surgery Information (type, room, date/time, prep/cleanup times)
// 3. Staff Assignment (surgeon, nurses, technologist)
// 4. Equipment Selection
// 5. Conflict Check
//
// Validation:
// - Required field checking
// - Time slot validation
// - Resource conflict detection
// - Staff availability verification
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:provider/provider.dart';

import '../../../features/doctor/screens/doctor_page.dart';
import '../../../features/profile/screens/profile.dart';
import '../../../features/schedule/screens/schedule.dart';
import '../../../features/schedule/screens/schedule_provider.dart';
import '../../../services/notification_service.dart';
import '../../../services/notification_manager.dart';
import '../../../shared/widgets/custom_navigation_bar.dart';
import '../providers/surgery_form_provider.dart';

/// Screen for adding new surgeries with multi-step form
class AddSurgeryScreen extends StatefulWidget {
  final bool isTestMode;
  const AddSurgeryScreen({super.key, this.isTestMode = false});

  @override
  AddSurgeryScreenState createState() => AddSurgeryScreenState();
}

// Equipment model class
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

class AddSurgeryScreenState extends State<AddSurgeryScreen>
    with SingleTickerProviderStateMixin {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Loading and submission states
  bool _isSubmitting = false;

  // Surgery types and operating rooms
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

  // Staff lists populated from Firestore
  List<String> _technologists = [];
  List<String> _doctors = [];
  List<String> _nurses = [];

  // Navigation state
  int _selectedIndex = 2; // Index for Add Surgery tab

  // Form provider
  late SurgeryFormProvider _formProvider;

  @override
  void initState() {
    super.initState();

    // Initialize form provider
    _formProvider = Provider.of<SurgeryFormProvider>(context, listen: false);

    // Force reset the form on initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _formProvider.resetForm();
    });

    if (widget.isTestMode) {
      _loadTestData();
    } else {
      _loadData(); // Actual Firestore calls to fetch data
    }
  }

  /// Loads test data for testing mode
  void _loadTestData() {
    _doctors = ['Dr. Test A', 'Dr. Test B'];
    _nurses = ['Nurse Test A', 'Nurse Test B', 'Nurse Test C'];
    _technologists = ['Tech Test A', 'Tech Test B'];
  }

  /// Handles navigation between main app screens
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
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (ctx) => const ProfileScreen(fromMoreScreen: false)));
        break;
      case 4:
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (ctx) => const DoctorPage()));
        break;
    }
  }

  /// Fetches list of technologists from Firestore
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

  /// Submits the surgery scheduling form
  Future<void> _submitForm() async {
    // Get form provider
    final formProvider =
        Provider.of<SurgeryFormProvider>(context, listen: false);

    // First, validate all required fields
    bool isValid = true;

    // Check patient information
    if (formProvider.patientName.isEmpty ||
        formProvider.patientAge.isEmpty ||
        formProvider.patientGender == null ||
        formProvider.medicalRecordNumber.isEmpty) {
      isValid = false;
      formProvider.goToStep(0); // Go to patient info step
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete the patient information'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check surgery details
    if (formProvider.surgeryType == null ||
        formProvider.operatingRoom == null) {
      isValid = false;
      formProvider.goToStep(1); // Go to surgery details step
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete the surgery details'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check time selection
    if (!formProvider.startTime.isBefore(formProvider.endTime) ||
        formProvider.endTime.difference(formProvider.startTime).inMinutes <
            30) {
      isValid = false;
      formProvider.goToStep(2); // Go to time selection step
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please select a valid time range (at least 30 minutes)'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check staff selection
    if (formProvider.selectedDoctor == null ||
        formProvider.selectedNurses.isEmpty) {
      isValid = false;
      formProvider.goToStep(3); // Go to staff selection step
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a surgeon and at least one nurse'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // If validation fails, don't proceed
    if (!isValid) return;

    // Set submitting state
    setState(() {
      _isSubmitting = true;
    });

    // Check for conflicts before confirming
    bool hasConflicts = await formProvider.checkConflicts();

    // If there are conflicts, go to the conflicts step instead of showing an error
    if (hasConflicts) {
      setState(() {
        _isSubmitting = false;
      });

      if (!mounted) return;

      // Navigate to the conflicts step
      formProvider.goToStep(5);

      // Show a guidance message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Conflicts detected. Please review and adjust your selections.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    // Show confirmation dialog (only if no conflicts)
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.calendar_today,
                    color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text('Confirm Scheduling'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Are you sure you want to schedule this surgery?'),
                const SizedBox(height: 12),
                Text(
                  'Surgery: ${formProvider.surgeryType ?? ""}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Patient: ${formProvider.patientName}'),
                Text(
                    'Date: ${DateFormat('MMM dd, yyyy').format(formProvider.startTime)}'),
                Text(
                    'Time: ${DateFormat('hh:mm a').format(formProvider.startTime)} - ${DateFormat('hh:mm a').format(formProvider.endTime)}'),
                Text('Room: ${formProvider.operatingRoom ?? ""}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Schedule'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    try {
      // Use the existing SurgeryProvider to add the surgery
      final surgeryProvider =
          Provider.of<SurgeryProvider>(context, listen: false);

      // Calculate duration in minutes
      final duration =
          formProvider.endTime.difference(formProvider.startTime).inMinutes;

      // Create equipment requirements
      final equipmentRequirements = formProvider.createEquipmentRequirements();

      // Prepare surgery data
      final surgeryData = {
        'surgeryType': formProvider.surgeryType,
        'room': formProvider.operatingRoom,
        'startTime': Timestamp.fromDate(formProvider.startTime),
        'endTime': Timestamp.fromDate(formProvider.endTime),
        'surgeon': formProvider.selectedDoctor,
        'nurses': formProvider.selectedNurses,
        'technologists': formProvider.selectedTechnologist != null
            ? [formProvider.selectedTechnologist]
            : [],
        'status': 'Scheduled',
        'notes': formProvider.notes,
        'patientName': formProvider.patientName,
        'patientAge': int.tryParse(formProvider.patientAge),
        'patientGender': formProvider.patientGender,
        'medicalRecordNumber': formProvider.medicalRecordNumber,
        'duration': formProvider.totalDuration,
        'prepTimeMinutes': formProvider.prepTimeMinutes,
        'cleanupTimeMinutes': formProvider.cleanupTimeMinutes,
        'requiredEquipment': formProvider.selectedEquipmentIds,
        'equipmentRequirements':
            equipmentRequirements.map((req) => req.toFirestore()).toList(),
        'customTimeBlocks': formProvider.timeBlocks,
      };

      // Add surgery to Firestore
      final surgeryId = await surgeryProvider.addSurgery(surgeryData);

      // Send notifications to assigned staff
      try {
        // Initialize notification services
        final notificationService = NotificationService();
        final notificationManager = NotificationManager();

        // Send scheduled notification via NotificationService
        await notificationService.sendScheduledNotification(surgeryId);

        // Send notification via NotificationManager to all assigned staff
        await notificationManager.sendScheduledNotificationById(surgeryId);

        debugPrint(
            "Notifications sent for newly scheduled surgery: $surgeryId");
      } catch (notificationError) {
        // Log error but don't prevent the surgery from being scheduled
        debugPrint("Error sending notifications: $notificationError");
      }

      // Clear the form
      formProvider.clearSavedForm();

      // Force a complete form reset
      formProvider.resetForm();

      if (!mounted) return;

      // Show success dialog
      await _showSuccessDialog(surgeryData);
    } catch (error) {
      debugPrint("Error adding surgery: $error");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to schedule surgery. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// Shows success dialog after scheduling a surgery
  Future<void> _showSuccessDialog(Map<String, dynamic> surgeryData) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                'Surgery for ${surgeryData['patientName']} has been successfully scheduled.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('MMM dd, yyyy  hh:mm a')
                    .format((surgeryData['startTime'] as Timestamp).toDate()),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Flexible(
                    child: TextButton(
                      onPressed: () {
                        // First reset the form
                        if (_formKey.currentState != null) {
                          _formKey.currentState!.reset();
                        }

                        // Then navigate to fresh screen
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (context) => const AddSurgeryScreen()),
                          (Route<dynamic> route) => false,
                        );
                      },
                      child: const Text('Schedule Another'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: ElevatedButton(
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
                            horizontal: 16, vertical: 12),
                      ),
                      child: const Text('View Schedule'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Creates consistent input decoration for form fields
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

  /// Loads staff and other data
  Future<void> _loadData() async {
    if (!mounted) return;

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
    }
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
              Text(
                  '• Use the multi-step form to easily navigate through sections'),
              SizedBox(height: 8),
              Text('• Required fields are marked with an asterisk (*)'),
              SizedBox(height: 8),
              Text(
                  '• Set preparation and cleanup times for more accurate scheduling'),
              SizedBox(height: 8),
              Text(
                  '• Equipment selection allows you to mark items as required or optional'),
              SizedBox(height: 8),
              Text('• Conflicts are automatically detected and visualized'),
              SizedBox(height: 8),
              Text('• Your form progress is saved every 30 seconds'),
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

  @override
  Widget build(BuildContext context) {
    final formProvider = Provider.of<SurgeryFormProvider>(context);
    _formKey.currentState?.validate();

    // Show loading indicator when form is submitting
    if (formProvider.isSubmitting) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Scheduling surgery...'),
            ],
          ),
        ),
      );
    }

    // Regular stepper form
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Surgery'),
        centerTitle: true,
        elevation: 0,
        actions: [
          // Reset form button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Form',
            onPressed: () => _showResetConfirmationDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: _buildStepper(context, formProvider),
      ),
      bottomNavigationBar: CustomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index != _selectedIndex) {
            setState(() {
              _selectedIndex = index;
            });
            _onItemTapped(index);
          }
        },
      ),
    );
  }

  /// Shows a confirmation dialog before resetting the form
  Future<void> _showResetConfirmationDialog() async {
    final bool shouldReset = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reset Form?'),
            content: const Text(
                'This will clear all entered data. Are you sure you want to reset the form?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Reset'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldReset) {
      final formProvider =
          Provider.of<SurgeryFormProvider>(context, listen: false);
      formProvider.resetForm();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Form has been reset'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  /// Builds and formats time info row for time summary
  Widget _buildTimeInfoRow(String label, String value, Color textColor,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Formats duration between start and end time
  String _formatDuration(DateTime start, DateTime end) {
    final diff = end.difference(start);
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);

    if (hours > 0) {
      return '$hours hr ${minutes > 0 ? '$minutes min' : ''}';
    } else {
      return '$minutes min';
    }
  }

  /// Builds the stepper form and handles step navigation
  Widget _buildStepper(BuildContext context, SurgeryFormProvider formProvider) {
    // Theme-aware colors
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final cardColor = isDarkMode ? Colors.grey[850]! : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final fillColor = isDarkMode ? Colors.grey[800]! : Colors.grey[50]!;
    final borderColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).primaryColor,
              background: backgroundColor,
              surface: cardColor,
            ),
      ),
      child: Stepper(
        type: StepperType.vertical,
        physics: const ClampingScrollPhysics(),
        currentStep: formProvider.currentStep,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Row(
              children: [
                if (details.currentStep > 0)
                  OutlinedButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: details.currentStep < 5
                      ? details.onStepContinue
                      : _submitForm,
                  child: Text(
                    details.currentStep == 5 ? 'Schedule Surgery' : 'Continue',
                  ),
                ),
              ],
            ),
          );
        },
        onStepContinue: () {
          // Check if form is valid before proceeding
          if (formProvider.validateCurrentStep()) {
            formProvider.nextStep();
          } else {
            // Show appropriate error message based on current step
            String errorMessage = 'Please complete all required fields';
            switch (formProvider.currentStep) {
              case 0:
                errorMessage = 'Please complete all patient information fields';
                break;
              case 1:
                errorMessage =
                    'Please select both a surgery type and operating room';
                break;
              case 2:
                errorMessage =
                    'Please select a valid time range (at least 30 minutes)';
                break;
              case 3:
                errorMessage = 'Please select a surgeon and at least one nurse';
                break;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        onStepCancel: () {
          formProvider.previousStep();
        },
        onStepTapped: (step) {
          formProvider.goToStep(step);
        },
        steps: [
          // Step 1: Patient Information
          Step(
            title: const Text('Patient Information'),
            isActive: formProvider.currentStep >= 0,
            content: _buildPatientInfoStep(
                formProvider, fillColor, borderColor, textColor),
          ),

          // Step 2: Surgery Details
          Step(
            title: const Text('Surgery Details'),
            isActive: formProvider.currentStep >= 1,
            content: _buildSurgeryDetailsStep(
                formProvider, fillColor, borderColor, textColor),
          ),

          // Step 3: Time Selection
          Step(
            title: const Text('Time Selection'),
            isActive: formProvider.currentStep >= 2,
            content: _buildTimeSelectionStep(
                formProvider, fillColor, borderColor, textColor),
          ),

          // Step 4: Staff Selection
          Step(
            title: const Text('Medical Staff'),
            isActive: formProvider.currentStep >= 3,
            content: _buildStaffSelectionStep(
                formProvider, fillColor, borderColor, textColor),
          ),

          // Step 5: Equipment
          Step(
            title: const Text('Equipment & Notes'),
            isActive: formProvider.currentStep >= 4,
            content: _buildEquipmentStep(
                formProvider, fillColor, borderColor, textColor),
          ),

          // Step 6: Conflict Check
          Step(
            title: const Text('Conflict Check'),
            isActive: formProvider.currentStep >= 5,
            content: _buildConflictCheckStep(
                formProvider, fillColor, borderColor, textColor),
          ),
        ],
      ),
    );
  }

  /// Builds the Patient Information step
  Widget _buildPatientInfoStep(
    SurgeryFormProvider formProvider,
    Color fillColor,
    Color borderColor,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: formProvider.patientName,
          style: TextStyle(color: textColor),
          decoration: _getInputDecoration(
            'Patient Name *',
            Icons.person,
            fillColor,
            borderColor,
          ),
          onChanged: (value) =>
              formProvider.updatePatientInfo(patientName: value),
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
                initialValue: formProvider.patientAge,
                style: TextStyle(color: textColor),
                decoration: _getInputDecoration(
                  'Age *',
                  Icons.calendar_today,
                  fillColor,
                  borderColor,
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) =>
                    formProvider.updatePatientInfo(patientAge: value),
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
                  'Gender *',
                  Icons.people,
                  fillColor,
                  borderColor,
                ),
                value: formProvider.patientGender,
                items: _genderOptions.map((String gender) {
                  return DropdownMenuItem(
                    value: gender,
                    child: Text(gender, style: TextStyle(color: textColor)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  formProvider.updatePatientInfo(patientGender: newValue);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
                dropdownColor: fillColor,
                style: TextStyle(color: textColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: formProvider.medicalRecordNumber,
          style: TextStyle(color: textColor),
          decoration: _getInputDecoration(
            'Medical Record Number *',
            Icons.folder,
            fillColor,
            borderColor,
          ),
          onChanged: (value) =>
              formProvider.updatePatientInfo(medicalRecordNumber: value),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter medical record number';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// Builds the Surgery Details step
  Widget _buildSurgeryDetailsStep(
    SurgeryFormProvider formProvider,
    Color fillColor,
    Color borderColor,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          decoration: _getInputDecoration(
            'Surgery Type *',
            Icons.medical_services,
            fillColor,
            borderColor,
          ),
          value: formProvider.surgeryType,
          items: _surgeryTypes.map((String type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type, style: TextStyle(color: textColor)),
            );
          }).toList(),
          onChanged: (String? newValue) {
            formProvider.updateSurgeryDetails(surgeryType: newValue);
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a surgery type';
            }
            return null;
          },
          dropdownColor: fillColor,
          style: TextStyle(color: textColor),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: _getInputDecoration(
            'Operating Room *',
            Icons.room,
            fillColor,
            borderColor,
          ),
          value: formProvider.operatingRoom,
          items: _room.map((String room) {
            return DropdownMenuItem(
              value: room,
              child: Text(room, style: TextStyle(color: textColor)),
            );
          }).toList(),
          onChanged: (String? newValue) {
            formProvider.updateSurgeryDetails(operatingRoom: newValue);
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select an operating room';
            }
            return null;
          },
          dropdownColor: fillColor,
          style: TextStyle(color: textColor),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: formProvider.notes,
          maxLines: 3,
          style: TextStyle(color: textColor),
          decoration: _getInputDecoration(
            'Notes (Optional)',
            Icons.note,
            fillColor,
            borderColor,
          ),
          onChanged: (value) => formProvider.updateSurgeryDetails(notes: value),
        ),
      ],
    );
  }

  /// Builds the Time Selection step
  Widget _buildTimeSelectionStep(
    SurgeryFormProvider formProvider,
    Color fillColor,
    Color borderColor,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Selection - Calendar style
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Surgery Date',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: formProvider.startTime,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  helpText: 'SELECT SURGERY DATE',
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                              primary: Theme.of(context).primaryColor,
                            ),
                      ),
                      child: child!,
                    );
                  },
                );

                if (pickedDate != null) {
                  // Keep the time the same, just update the date
                  final newDateTime = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    formProvider.startTime.hour,
                    formProvider.startTime.minute,
                  );

                  // Calculate the new end time preserving duration
                  final duration =
                      formProvider.endTime.difference(formProvider.startTime);
                  final newEndTime = newDateTime.add(duration);

                  formProvider.updateTimeInfo(
                    startTime: newDateTime,
                    endTime: newEndTime,
                  );
                }
              },
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: Theme.of(context).primaryColor),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy')
                          .format(formProvider.startTime),
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_drop_down, color: textColor),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Start Time Selection with 5-min increments
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Start Time',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                // Get current hour and minute
                final currentHour = formProvider.startTime.hour;
                final currentMinute = formProvider.startTime.minute;

                // Round minutes to nearest 5
                final roundedMinute = (currentMinute ~/ 5) * 5;

                final initialTime = TimeOfDay(
                  hour: currentHour,
                  minute: roundedMinute,
                );

                final pickedTime = await showCustomTimePicker(
                  context: context,
                  initialTime: initialTime,
                );

                if (pickedTime != null) {
                  // Create new DateTime with selected time
                  final newDateTime = DateTime(
                    formProvider.startTime.year,
                    formProvider.startTime.month,
                    formProvider.startTime.day,
                    pickedTime.hour,
                    pickedTime.minute,
                  );

                  // Keep duration consistent
                  final duration =
                      formProvider.endTime.difference(formProvider.startTime);
                  final newEndTime = newDateTime.add(duration);

                  formProvider.updateTimeInfo(
                    startTime: newDateTime,
                    endTime: newEndTime,
                  );
                }
              },
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        color: Theme.of(context).primaryColor),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('h:mm a').format(formProvider.startTime),
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_drop_down, color: textColor),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Duration selector (keeping the existing one with minor UI improvements)
        Row(
          children: [
            Expanded(
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Duration',
                  prefixIcon: const Icon(Icons.hourglass_bottom),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  filled: true,
                  fillColor: fillColor,
                ),
                child: Row(
                  children: [
                    // Hours selector
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: formProvider.durationHours,
                          isDense: true,
                          items: List.generate(9, (i) => i).map((hours) {
                            return DropdownMenuItem(
                              value: hours,
                              child: Text(
                                '$hours hr',
                                style: TextStyle(color: textColor),
                              ),
                            );
                          }).toList(),
                          onChanged: (hours) {
                            if (hours != null) {
                              // Calculate new end time based on hours and keep minutes
                              final minutes = formProvider.durationMinutes;
                              final newEndTime = formProvider.startTime.add(
                                  Duration(hours: hours, minutes: minutes));
                              formProvider.updateTimeInfo(
                                endTime: newEndTime,
                              );
                            }
                          },
                          dropdownColor: fillColor,
                        ),
                      ),
                    ),

                    // Minutes selector
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: formProvider.durationMinutes,
                          isDense: true,
                          items: List.generate(12, (i) => i * 5).map((minutes) {
                            return DropdownMenuItem(
                              value: minutes,
                              child: Text(
                                '$minutes min',
                                style: TextStyle(color: textColor),
                              ),
                            );
                          }).toList(),
                          onChanged: (minutes) {
                            if (minutes != null) {
                              // Calculate new end time based on minutes and keep hours
                              final hours = formProvider.durationHours;
                              final newEndTime = formProvider.startTime.add(
                                  Duration(hours: hours, minutes: minutes));
                              formProvider.updateTimeInfo(
                                endTime: newEndTime,
                              );
                            }
                          },
                          dropdownColor: fillColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Prep and Cleanup Times with improved UI
        Row(
          children: [
            // Prep time selector
            Expanded(
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Prep Time',
                  prefixIcon: const Icon(Icons.timer),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  filled: true,
                  fillColor: fillColor,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: formProvider.prepTimeMinutes,
                    isDense: true,
                    isExpanded: true,
                    items: List.generate(13, (i) => i * 5).map((minutes) {
                      return DropdownMenuItem(
                        value: minutes,
                        child: Text(
                          '$minutes min',
                          style: TextStyle(color: textColor),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        formProvider.updateTimeInfo(prepTimeMinutes: value);
                      }
                    },
                    dropdownColor: fillColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Cleanup time selector
            Expanded(
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Cleanup Time',
                  prefixIcon: const Icon(Icons.cleaning_services),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  filled: true,
                  fillColor: fillColor,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: formProvider.cleanupTimeMinutes,
                    isDense: true,
                    isExpanded: true,
                    items: List.generate(13, (i) => i * 5).map((minutes) {
                      return DropdownMenuItem(
                        value: minutes,
                        child: Text(
                          '$minutes min',
                          style: TextStyle(color: textColor),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        formProvider.updateTimeInfo(cleanupTimeMinutes: value);
                      }
                    },
                    dropdownColor: fillColor,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Custom time block button
        OutlinedButton.icon(
          onPressed: () => _showAddCustomTimeBlockDialog(context, formProvider),
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Add Custom Time Block'),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Theme.of(context).primaryColor),
            foregroundColor: Theme.of(context).primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),

        const SizedBox(height: 16),

        // Time Summary Card
        Card(
          elevation: 0,
          color:
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Time Summary',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Start time info
                _buildTimeInfoRow(
                    'Start Time:',
                    DateFormat('MMM dd, yyyy  hh:mm a')
                        .format(formProvider.startTime),
                    textColor),

                // End time info (calculated)
                _buildTimeInfoRow(
                    'End Time:',
                    DateFormat('MMM dd, yyyy  hh:mm a')
                        .format(formProvider.endTime),
                    textColor),

                // Surgery time info
                _buildTimeInfoRow(
                    'Surgery Duration:',
                    _formatDuration(
                        formProvider.startTime, formProvider.endTime),
                    textColor),

                // Prep and cleanup times
                if (formProvider.prepTimeMinutes > 0)
                  _buildTimeInfoRow('Prep Time:',
                      '${formProvider.prepTimeMinutes} min', textColor),

                if (formProvider.cleanupTimeMinutes > 0)
                  _buildTimeInfoRow('Cleanup Time:',
                      '${formProvider.cleanupTimeMinutes} min', textColor),

                // Display custom time blocks if any
                if (formProvider.timeBlocks.isNotEmpty) ...[
                  const Divider(height: 16),
                  ...formProvider.timeBlocks.map((block) => _buildTimeInfoRow(
                      '${block['name']}:',
                      '${block['durationMinutes']} min',
                      textColor)),
                ],

                // Total time including prep/cleanup
                const Divider(height: 24),

                _buildTimeInfoRow('Total Block Time:',
                    '${formProvider.grandTotalDuration} min', textColor,
                    isBold: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the Staff Selection step
  Widget _buildStaffSelectionStep(
    SurgeryFormProvider formProvider,
    Color fillColor,
    Color borderColor,
    Color textColor,
  ) {
    final hintColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[400]!
        : Colors.grey[600]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Surgeon Selection
        DropdownSearch<String>(
          items: _doctors,
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: _getInputDecoration(
              'Select Surgeon *',
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
              backgroundColor: fillColor,
            ),
          ),
          onChanged: (value) {
            if (value != null) {
              formProvider.updateStaffAssignments(selectedDoctor: value);
            }
          },
          selectedItem: formProvider.selectedDoctor,
        ),

        const SizedBox(height: 16),

        // Nurses Selection
        MultiSelectDialogField<String>(
          items: _nurses
              .map((nurse) => MultiSelectItem<String>(nurse, nurse))
              .toList(),
          title: Text("Select Nurses *", style: TextStyle(color: textColor)),
          selectedColor: Theme.of(context).primaryColor,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          buttonIcon: Icon(Icons.arrow_drop_down, color: textColor),
          buttonText: Text(
            "Select Nurses",
            style: TextStyle(fontSize: 16, color: textColor),
          ),
          onConfirm: (values) {
            formProvider.updateStaffAssignments(selectedNurses: values);
          },
          initialValue: formProvider.selectedNurses,
          chipDisplay: MultiSelectChipDisplay(
            onTap: (value) {
              final updatedNurses = [...formProvider.selectedNurses];
              updatedNurses.remove(value);
              formProvider.updateStaffAssignments(
                  selectedNurses: updatedNurses);
            },
            chipColor: Theme.of(context).primaryColor.withOpacity(0.1),
            textStyle: TextStyle(color: textColor),
          ),
          backgroundColor: fillColor,
        ),

        const SizedBox(height: 16),

        // Technologist Selection
        DropdownButtonFormField<String>(
          decoration: _getInputDecoration(
            'Select Technologist (Optional)',
            Icons.engineering,
            fillColor,
            borderColor,
          ),
          value: formProvider.selectedTechnologist,
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('None'),
            ),
            ..._technologists.map((String tech) {
              return DropdownMenuItem(
                value: tech,
                child: Text(tech, style: TextStyle(color: textColor)),
              );
            }).toList(),
          ],
          onChanged: (String? newValue) {
            formProvider.updateStaffAssignments(selectedTechnologist: newValue);
          },
          dropdownColor: fillColor,
          style: TextStyle(color: textColor),
        ),

        const SizedBox(height: 20),

        // Staff Availability Card
        Card(
          elevation: 0,
          color:
              Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Staff Availability',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'The system will check for scheduling conflicts before confirming the surgery.',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Staff members will be automatically notified when surgery is scheduled.',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the Equipment step
  Widget _buildEquipmentStep(
    SurgeryFormProvider formProvider,
    Color fillColor,
    Color borderColor,
    Color textColor,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Simple header text
        const Padding(
          padding: EdgeInsets.only(bottom: 16.0),
          child: Text(
            'Select equipment needed for this surgery:',
            style: TextStyle(fontSize: 16),
          ),
        ),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _getAvailableEquipment().map((equipment) {
            final isSelected =
                formProvider.selectedEquipmentIds.contains(equipment.id);
            return FilterChip(
              label: Text(equipment.name),
              selected: isSelected,
              onSelected: (selected) {
                final updatedEquipment =
                    Set<String>.from(formProvider.selectedEquipmentIds);
                if (selected) {
                  updatedEquipment.add(equipment.id);
                } else {
                  updatedEquipment.remove(equipment.id);
                }
                formProvider.updateEquipmentSelections(updatedEquipment, {});
              },
              selectedColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.15),
              checkmarkColor: Theme.of(context).colorScheme.primary,
            );
          }).toList(),
        ),

        const SizedBox(height: 8),
        Text(
          'Selected: ${formProvider.selectedEquipmentIds.length} items',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      ],
    );
  }

  /// Builds the Conflict Check step that shows scheduling conflicts
  Widget _buildConflictCheckStep(
    SurgeryFormProvider formProvider,
    Color fillColor,
    Color borderColor,
    Color textColor,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header explaining this step
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              'Scheduling Conflicts Check',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),

          Text(
            'This step checks for scheduling conflicts with your current selections. If conflicts are found, you\'ll need to adjust your scheduling parameters before proceeding.',
            style: TextStyle(color: textColor),
          ),

          const SizedBox(height: 24),

          // Current selection summary card
          Card(
            elevation: 0,
            color:
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Currently Selected:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Room and Time
                  _buildSelectionInfoRow(
                    'Operating Room:',
                    formProvider.operatingRoom ?? 'Not Selected',
                    Icons.room,
                    textColor,
                    () =>
                        formProvider.goToStep(1), // Navigate to surgery details
                  ),

                  _buildSelectionInfoRow(
                    'Date & Time:',
                    '${DateFormat('MMM dd, yyyy').format(formProvider.startTime)} at ${DateFormat('h:mm a').format(formProvider.startTime)} - ${DateFormat('h:mm a').format(formProvider.endTime)}',
                    Icons.access_time,
                    textColor,
                    () =>
                        formProvider.goToStep(2), // Navigate to time selection
                  ),

                  // Staff
                  _buildSelectionInfoRow(
                    'Surgeon:',
                    formProvider.selectedDoctor ?? 'Not Selected',
                    Icons.person,
                    textColor,
                    () =>
                        formProvider.goToStep(3), // Navigate to staff selection
                  ),

                  _buildSelectionInfoRow(
                    'Nurses:',
                    formProvider.selectedNurses.isEmpty
                        ? 'None Selected'
                        : formProvider.selectedNurses.join(', '),
                    Icons.people,
                    textColor,
                    () =>
                        formProvider.goToStep(3), // Navigate to staff selection
                  ),

                  if (formProvider.selectedTechnologist != null)
                    _buildSelectionInfoRow(
                      'Technologist:',
                      formProvider.selectedTechnologist!,
                      Icons.engineering,
                      textColor,
                      () => formProvider
                          .goToStep(3), // Navigate to staff selection
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Conflicts visualization
          _buildConflictsVisualization(
            formProvider,
            fillColor,
            textColor,
            borderColor,
          ),
        ],
      ),
    );
  }

  /// Builds an information row for the current selection
  Widget _buildSelectionInfoRow(
    String label,
    String value,
    IconData icon,
    Color textColor,
    VoidCallback onEdit,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textColor.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: onEdit,
            tooltip: 'Edit',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }

  /// Shows dialog to add custom time block
  void _showAddCustomTimeBlockDialog(
      BuildContext context, SurgeryFormProvider formProvider) {
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
                // Add a new custom time block
                formProvider.addTimeBlock(
                  name: nameController.text.trim(),
                  durationMinutes: durationMinutes,
                );
                Navigator.pop(context);
              },
              child: const Text('Add Block'),
            ),
          ],
        );
      }),
    );
  }

  /// Gets a list of available equipment
  List<Equipment> _getAvailableEquipment() {
    // Hard-coded for this example
    return [
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

  /// Custom time picker that supports 5-minute increments
  Future<TimeOfDay?> showCustomTimePicker({
    required BuildContext context,
    required TimeOfDay initialTime,
  }) async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    // Store selected time
    TimeOfDay selectedTime = initialTime;

    // Ensure minutes are divisible by 5
    int minute = (initialTime.minute ~/ 5) * 5;
    selectedTime = TimeOfDay(hour: initialTime.hour, minute: minute);

    // Show dialog
    final TimeOfDay? result = await showDialog<TimeOfDay>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              backgroundColor: backgroundColor,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Select time',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Time selection controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Hour selection
                        _buildTimeSelector(
                          context: context,
                          value: selectedTime.hour,
                          onChanged: (int hour) {
                            setState(() {
                              selectedTime = TimeOfDay(
                                  hour: hour, minute: selectedTime.minute);
                            });
                          },
                          minValue: 0,
                          maxValue: 23,
                          format: (int value) {
                            String hour = value.toString().padLeft(2, '0');
                            return hour;
                          },
                          isSelected: true,
                        ),

                        // Colon separator
                        Text(
                          ':',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),

                        // Minute selection - in 5 minute increments
                        _buildTimeSelector(
                          context: context,
                          value: selectedTime.minute,
                          onChanged: (int minute) {
                            setState(() {
                              selectedTime = TimeOfDay(
                                  hour: selectedTime.hour, minute: minute);
                            });
                          },
                          minValue: 0,
                          maxValue: 55,
                          interval: 5,
                          format: (int value) {
                            String minute = value.toString().padLeft(2, '0');
                            return minute;
                          },
                          isSelected: true,
                        ),

                        // AM/PM selector
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Column(
                            children: [
                              _buildAmPmButton(
                                context: context,
                                label: 'AM',
                                isSelected: selectedTime.hour < 12,
                                onTap: () {
                                  setState(() {
                                    if (selectedTime.hour >= 12) {
                                      selectedTime = TimeOfDay(
                                        hour: selectedTime.hour - 12,
                                        minute: selectedTime.minute,
                                      );
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              _buildAmPmButton(
                                context: context,
                                label: 'PM',
                                isSelected: selectedTime.hour >= 12,
                                onTap: () {
                                  setState(() {
                                    if (selectedTime.hour < 12) {
                                      selectedTime = TimeOfDay(
                                        hour: selectedTime.hour + 12,
                                        minute: selectedTime.minute,
                                      );
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, selectedTime),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    return result;
  }

  /// Helper method to build time selectors for hour and minute
  Widget _buildTimeSelector({
    required BuildContext context,
    required int value,
    required Function(int) onChanged,
    required int minValue,
    required int maxValue,
    required String Function(int) format,
    int interval = 1,
    bool isSelected = false,
  }) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Increment button
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up),
          onPressed: () {
            int newValue = value + interval;
            // Handle wrapping
            if (newValue > maxValue) {
              newValue = minValue;
            }
            onChanged(newValue);
          },
        ),

        // Value display
        Container(
          width: 70,
          height: 60,
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryColor.withOpacity(0.1) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              format(value),
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: isSelected ? theme.primaryColor : null,
              ),
            ),
          ),
        ),

        // Decrement button
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () {
            int newValue = value - interval;
            // Handle wrapping
            if (newValue < minValue) {
              newValue = maxValue;
            }
            onChanged(newValue);
          },
        ),
      ],
    );
  }

  /// Helper method to build AM/PM button
  Widget _buildAmPmButton({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 48,
        height: 32,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor
              : theme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : theme.primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds conflicts visualization with the current time selection
  Widget _buildConflictsVisualization(
    SurgeryFormProvider formProvider,
    Color cardColor,
    Color textColor,
    Color borderColor,
  ) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchConflicts(formProvider),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            elevation: 0,
            color: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: borderColor.withOpacity(0.5)),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Checking for conflicts...'),
                  ],
                ),
              ),
            ),
          );
        }

        final List<Map<String, dynamic>> conflicts = snapshot.data ?? [];

        if (conflicts.isEmpty) {
          return Card(
            elevation: 0,
            color: Colors.green.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.green.withOpacity(0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No Conflicts Detected',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your selected time slot is available.',
                              style: TextStyle(
                                color: textColor.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        } else {
          return Card(
            elevation: 0,
            color: Colors.red.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.red.withOpacity(0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.red, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${conflicts.length} Conflicts Detected',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Please adjust your selections to resolve these conflicts:',
                              style: TextStyle(
                                color: textColor.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // List of conflicts
                  ...conflicts.map((conflict) {
                    IconData iconData;
                    Color iconColor;

                    // Determine icon based on conflict type
                    switch (conflict['type']) {
                      case 'room':
                        iconData = Icons.meeting_room;
                        iconColor = Colors.red;
                        break;
                      case 'surgeon':
                        iconData = Icons.medical_services;
                        iconColor = Colors.orange;
                        break;
                      case 'nurse':
                        iconData = Icons.healing;
                        iconColor = Colors.amber;
                        break;
                      case 'technologist':
                        iconData = Icons.engineering;
                        iconColor = Colors.amber.shade800;
                        break;
                      default:
                        iconData = Icons.error_outline;
                        iconColor = Colors.red;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(iconData, color: iconColor, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  conflict['message'],
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Conflicting Time: ${conflict['conflictingTime']}',
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.7),
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Patient: ${conflict['patientName']}',
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.7),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Edit button to quickly go to the relevant step
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () {
                              // Navigate to appropriate step
                              switch (conflict['type']) {
                                case 'room':
                                  formProvider.goToStep(1); // Surgery details
                                  break;
                                case 'surgeon':
                                case 'nurse':
                                case 'technologist':
                                  formProvider.goToStep(3); // Staff selection
                                  break;
                                default:
                                  formProvider.goToStep(2); // Time selection
                              }
                            },
                            tooltip: 'Edit',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  /// Fetch conflicts from Firebase
  Future<List<Map<String, dynamic>>> _fetchConflicts(
      SurgeryFormProvider formProvider) async {
    final List<Map<String, dynamic>> conflicts = [];

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      // Check for room conflicts
      if (formProvider.operatingRoom != null) {
        final roomConflicts = await firestore
            .collection('surgeries')
            .where('room', isEqualTo: formProvider.operatingRoom)
            .where('status', whereIn: ['Scheduled', 'In Progress']).get();

        for (var doc in roomConflicts.docs) {
          final data = doc.data();
          final Timestamp startTime = data['startTime'];
          final Timestamp endTime = data['endTime'];

          // Skip comparing with itself for editing
          if (formProvider.startTime.isBefore(endTime.toDate()) &&
              formProvider.endTime.isAfter(startTime.toDate())) {
            conflicts.add({
              'type': 'room',
              'resource': formProvider.operatingRoom,
              'conflictingTime':
                  '${DateFormat('MMM dd, h:mm a').format(startTime.toDate())} - ${DateFormat('h:mm a').format(endTime.toDate())}',
              'patientName': data['patientName'] ?? 'Unknown Patient',
              'message':
                  'Operating Room "${formProvider.operatingRoom}" is already booked during this time'
            });
          }
        }
      }

      // Check for surgeon conflicts
      if (formProvider.selectedDoctor != null) {
        final surgeonConflicts = await firestore
            .collection('surgeries')
            .where('surgeon', isEqualTo: formProvider.selectedDoctor)
            .where('status', whereIn: ['Scheduled', 'In Progress']).get();

        for (var doc in surgeonConflicts.docs) {
          final data = doc.data();
          final Timestamp startTime = data['startTime'];
          final Timestamp endTime = data['endTime'];

          // Skip comparing with itself for editing
          if (formProvider.startTime.isBefore(endTime.toDate()) &&
              formProvider.endTime.isAfter(startTime.toDate())) {
            conflicts.add({
              'type': 'surgeon',
              'resource': formProvider.selectedDoctor,
              'conflictingTime':
                  '${DateFormat('MMM dd, h:mm a').format(startTime.toDate())} - ${DateFormat('h:mm a').format(endTime.toDate())}',
              'patientName': data['patientName'] ?? 'Unknown Patient',
              'message':
                  'Surgeon "${formProvider.selectedDoctor}" is already assigned to another surgery at this time'
            });
          }
        }
      }

      // Check for nurse conflicts
      for (final nurse in formProvider.selectedNurses) {
        final nurseConflicts = await firestore
            .collection('surgeries')
            .where('nurses', arrayContains: nurse)
            .where('status', whereIn: ['Scheduled', 'In Progress']).get();

        for (var doc in nurseConflicts.docs) {
          final data = doc.data();
          final Timestamp startTime = data['startTime'];
          final Timestamp endTime = data['endTime'];

          // Skip comparing with itself for editing
          if (formProvider.startTime.isBefore(endTime.toDate()) &&
              formProvider.endTime.isAfter(startTime.toDate())) {
            conflicts.add({
              'type': 'nurse',
              'resource': nurse,
              'conflictingTime':
                  '${DateFormat('MMM dd, h:mm a').format(startTime.toDate())} - ${DateFormat('h:mm a').format(endTime.toDate())}',
              'patientName': data['patientName'] ?? 'Unknown Patient',
              'message':
                  'Nurse "$nurse" is already assigned to another surgery at this time'
            });
          }
        }
      }

      // Check for technologist conflicts
      if (formProvider.selectedTechnologist != null) {
        final techConflicts = await firestore
            .collection('surgeries')
            .where('technologists',
                arrayContains: formProvider.selectedTechnologist)
            .where('status', whereIn: ['Scheduled', 'In Progress']).get();

        for (var doc in techConflicts.docs) {
          final data = doc.data();
          final Timestamp startTime = data['startTime'];
          final Timestamp endTime = data['endTime'];

          // Skip comparing with itself for editing
          if (formProvider.startTime.isBefore(endTime.toDate()) &&
              formProvider.endTime.isAfter(startTime.toDate())) {
            conflicts.add({
              'type': 'technologist',
              'resource': formProvider.selectedTechnologist,
              'conflictingTime':
                  '${DateFormat('MMM dd, h:mm a').format(startTime.toDate())} - ${DateFormat('h:mm a').format(endTime.toDate())}',
              'patientName': data['patientName'] ?? 'Unknown Patient',
              'message':
                  'Technologist "${formProvider.selectedTechnologist}" is already assigned to another surgery at this time'
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching conflicts: $e');
      // If there's an error, add a generic conflict as a fallback
      conflicts.add({
        'type': 'error',
        'resource': 'Unknown',
        'conflictingTime': 'Unknown',
        'patientName': 'Error',
        'message': 'Error checking conflicts. Please try again.'
      });
    }

    return conflicts;
  }
}

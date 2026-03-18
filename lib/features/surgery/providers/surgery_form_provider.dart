// =============================================================================
// Surgery Form Provider
// =============================================================================
// A provider for managing surgery form state in the multi-step surgery form:
// - Form state persistence across steps
// - Form validation
// - Save/restore functionality
// - Equipment selection management
// - Time slot recommendation logic
//
// Provider Pattern Implementation:
// - Uses ChangeNotifier for state management
// - Manages form fields for all steps
// - Handles form loading and submission
// =============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';

import '../../equipment/models/equipment.dart';
import '../../equipment/repositories/equipment_repository.dart';
import '../../schedule/models/surgery.dart';
import 'package:firebase_orscheduler/features/surgery/models/surgery_equipment_requirement.dart';

/// Provider for managing the state of the multi-step surgery form
class SurgeryFormProvider with ChangeNotifier {
  // Current step in the multi-step form
  int _currentStep = 0;

  // Loading and submission states
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _showPreview = false;
  bool _hasUnsavedChanges = false;

  // Advanced mode toggle
  bool _advancedMode = false;

  // Patient information
  String _patientName = '';
  String _patientAge = '';
  String? _patientGender;
  String _medicalRecordNumber = '';

  // Surgery details
  String? _surgeryType;
  String? _operatingRoom;
  String _notes = '';
  String _status = 'Scheduled'; // Default status

  // Time information
  DateTime _startTime = DateTime.now()
      .add(const Duration(days: 1, hours: 9)); // Default to 9 AM tomorrow
  DateTime _endTime = DateTime.now()
      .add(const Duration(days: 1, hours: 11)); // Default 2-hour surgery
  int _prepTimeMinutes = 30;
  int _cleanupTimeMinutes = 30;

  // Duration management (for improved UI)
  int _durationHours = 2; // Default to 2 hours
  int _durationMinutes = 0; // Default to 0 minutes
  List<Map<String, dynamic>> _timeBlocks =
      []; // For complex surgeries with multiple blocks

  // Staff assignments
  String? _selectedDoctor;
  List<String> _selectedNurses = [];
  String? _selectedTechnologist;

  // Equipment selections
  Set<String> _selectedEquipmentIds = {};
  Map<String, bool> _requiredEquipment = {};

  // Time slot recommendations
  List<Map<String, dynamic>> _recommendedTimeSlots = [];
  int _selectedRecommendationIndex = -1;
  String _recommendationSortType = 'earliest'; // Default sort: earliest first

  // Auto-save timer
  Timer? _autoSaveTimer;

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Equipment repository for equipment data
  final EquipmentRepository _equipmentRepository = EquipmentRepository();

  /// Constructor
  SurgeryFormProvider() {
    _setupAutoSave();
  }

  /// Sets up the auto-save timer
  void _setupAutoSave() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_hasUnsavedChanges) {
        saveFormState();
      }
    });
  }

  /// Loads saved form data
  Future<void> loadSavedForm() async {
    try {
      _isLoading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final savedForm = prefs.getString('surgery_form');

      if (savedForm != null) {
        final formData = json.decode(savedForm);

        // Restore patient information
        _patientName = formData['patientName'] ?? '';
        _patientAge = formData['patientAge'] ?? '';
        _patientGender = formData['patientGender'];
        _medicalRecordNumber = formData['medicalRecordNumber'] ?? '';

        // Restore surgery details
        _surgeryType = formData['surgeryType'];
        _operatingRoom = formData['operatingRoom'];
        _notes = formData['notes'] ?? '';

        // Restore time information
        if (formData['startTime'] != null) {
          _startTime = DateTime.parse(formData['startTime']);
        }
        if (formData['endTime'] != null) {
          _endTime = DateTime.parse(formData['endTime']);
        }
        _prepTimeMinutes = formData['prepTimeMinutes'] ?? 30;
        _cleanupTimeMinutes = formData['cleanupTimeMinutes'] ?? 30;

        // Restore staff assignments
        _selectedDoctor = formData['selectedDoctor'];
        _selectedNurses = List<String>.from(formData['selectedNurses'] ?? []);
        _selectedTechnologist = formData['selectedTechnologist'];

        // Restore equipment selections
        _selectedEquipmentIds =
            Set<String>.from(formData['selectedEquipmentIds'] ?? []);
        if (formData['requiredEquipment'] != null) {
          _requiredEquipment = Map<String, bool>.from(
              (formData['requiredEquipment'] as Map).map(
                  (key, value) => MapEntry(key.toString(), value as bool)));
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading saved form: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Saves the current form state
  Future<void> saveFormState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final formData = {
        // Patient information
        'patientName': _patientName,
        'patientAge': _patientAge,
        'patientGender': _patientGender,
        'medicalRecordNumber': _medicalRecordNumber,

        // Surgery details
        'surgeryType': _surgeryType,
        'operatingRoom': _operatingRoom,
        'notes': _notes,

        // Time information
        'startTime': _startTime.toIso8601String(),
        'endTime': _endTime.toIso8601String(),
        'prepTimeMinutes': _prepTimeMinutes,
        'cleanupTimeMinutes': _cleanupTimeMinutes,

        // Staff assignments
        'selectedDoctor': _selectedDoctor,
        'selectedNurses': _selectedNurses,
        'selectedTechnologist': _selectedTechnologist,

        // Equipment selections
        'selectedEquipmentIds': List<String>.from(_selectedEquipmentIds),
        'requiredEquipment': _requiredEquipment,

        // Form state
        'currentStep': _currentStep,
      };

      await prefs.setString('surgery_form', json.encode(formData));
      _hasUnsavedChanges = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving form state: $e');
    }
  }

  /// Clears the saved form data
  Future<void> clearSavedForm() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('surgery_form');
      resetForm();
    } catch (e) {
      debugPrint('Error clearing form: $e');
    }
  }

  /// Reset the entire form to default values
  void resetForm() {
    _currentStep = 0;

    // Reset patient information
    _patientName = '';
    _patientAge = '';
    _patientGender = null;
    _medicalRecordNumber = '';

    // Reset surgery details
    _surgeryType = null;
    _operatingRoom = null;
    _notes = '';

    // Reset time information
    _startTime = DateTime.now().add(const Duration(days: 1, hours: 9));
    _endTime = DateTime.now().add(const Duration(days: 1, hours: 11));
    _prepTimeMinutes = 30;
    _cleanupTimeMinutes = 30;

    // Reset staff assignments
    _selectedDoctor = null;
    _selectedNurses = [];
    _selectedTechnologist = null;

    // Reset equipment selections
    _selectedEquipmentIds = {};
    _requiredEquipment = {};

    // Reset recommendations
    _recommendedTimeSlots = [];
    _selectedRecommendationIndex = -1;

    _hasUnsavedChanges = false;
    notifyListeners();
  }

  /// Updates patient information
  void updatePatientInfo({
    String? patientName,
    String? patientAge,
    String? patientGender,
    String? medicalRecordNumber,
  }) {
    if (patientName != null) _patientName = patientName;
    if (patientAge != null) _patientAge = patientAge;
    if (patientGender != null) _patientGender = patientGender;
    if (medicalRecordNumber != null) _medicalRecordNumber = medicalRecordNumber;

    _hasUnsavedChanges = true;
    notifyListeners();
  }

  /// Updates surgery details
  void updateSurgeryDetails({
    String? surgeryType,
    String? operatingRoom,
    String? notes,
  }) {
    if (surgeryType != null) _surgeryType = surgeryType;
    if (operatingRoom != null) _operatingRoom = operatingRoom;
    if (notes != null) _notes = notes;

    _hasUnsavedChanges = true;
    notifyListeners();
  }

  /// Updates time information
  void updateTimeInfo({
    DateTime? startTime,
    DateTime? endTime,
    int? prepTimeMinutes,
    int? cleanupTimeMinutes,
  }) {
    bool changed = false;

    if (startTime != null && startTime != _startTime) {
      _startTime = startTime;
      changed = true;
    }

    if (endTime != null && endTime != _endTime) {
      _endTime = endTime;
      changed = true;
    }

    if (prepTimeMinutes != null && prepTimeMinutes != _prepTimeMinutes) {
      _prepTimeMinutes = prepTimeMinutes;
      changed = true;
    }

    if (cleanupTimeMinutes != null &&
        cleanupTimeMinutes != _cleanupTimeMinutes) {
      _cleanupTimeMinutes = cleanupTimeMinutes;
      changed = true;
    }

    if (changed) {
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  /// Updates staff assignments
  void updateStaffAssignments({
    String? selectedDoctor,
    List<String>? selectedNurses,
    String? selectedTechnologist,
  }) {
    if (selectedDoctor != null) _selectedDoctor = selectedDoctor;
    if (selectedNurses != null) _selectedNurses = selectedNurses;
    if (selectedTechnologist != null)
      _selectedTechnologist = selectedTechnologist;

    _hasUnsavedChanges = true;
    notifyListeners();
  }

  /// Updates equipment selections
  void updateEquipmentSelections(
    Set<String> selectedIds,
    Map<String, bool> requiredMap,
  ) {
    _selectedEquipmentIds = selectedIds;
    _requiredEquipment = requiredMap;

    _hasUnsavedChanges = true;
    notifyListeners();
  }

  /// Moves to the next step in the form
  void nextStep() {
    _currentStep++;
    notifyListeners();
  }

  /// Moves to the previous step in the form
  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  /// Goes to a specific step in the form
  void goToStep(int step) {
    _currentStep = step;
    notifyListeners();
  }

  /// Toggles the preview mode
  void togglePreview() {
    _showPreview = !_showPreview;
    notifyListeners();
  }

  /// Generates recommended time slots based on current form data
  Future<void> generateRecommendations({bool forceGenerate = false}) async {
    if ((_isLoading && !forceGenerate) ||
        (_surgeryType == null && _operatingRoom == null)) {
      return;
    }

    try {
      _isLoading = true;
      _recommendedTimeSlots = [];
      notifyListeners();

      // In production, we'd use a combination of approaches:
      // 1. Check database for conflicts (room/staff availability)
      // 2. Apply scheduling algorithm with preference weights
      // 3. Return ranked options

      // For this demonstration, we'll generate simulated recommendations
      final duration = _endTime.difference(_startTime);

      if (forceGenerate) {
        // When force generating, use simulated varied scores
        final int numRecommendations =
            5 + (DateTime.now().millisecondsSinceEpoch % 5);
        final conflicts = [
          'Dr. Smith has another appointment',
          'Equipment maintenance scheduled'
        ];

        for (int i = 0; i < numRecommendations; i++) {
          // Distribute recommendations throughout the day and across multiple days
          final dayOffset = (i ~/ 2) + 1; // Every 2 slots, move to next day
          final hourOffset = 9 + (i % 4) * 2; // 9am, 11am, 1pm, 3pm

          final startDate = DateTime.now().add(Duration(days: dayOffset));
          final startTime = DateTime(
              startDate.year, startDate.month, startDate.day, hourOffset, 0);
          final endTime = startTime.add(duration);

          // Calculate a realistic compatibility score
          // In a real app, this would be based on staff availability,
          // equipment availability, room utilization, etc.
          double score =
              0.4 + (Random().nextDouble() * 0.6); // Between 40% and 100%

          // Add some simulated conflicts for demonstration
          List<String> slotConflicts = [];
          if (score < 0.7 && Random().nextBool()) {
            slotConflicts.add(conflicts[Random().nextInt(conflicts.length)]);
          }

          _recommendedTimeSlots.add({
            'startTime': startTime,
            'endTime': endTime,
            'compatibilityScore': score,
            'conflicts': slotConflicts,
          });
        }
      } else {
        // When not forcing, try to use real availability data from Firestore
        try {
          // Calculate duration in minutes
          final durationMinutes = duration.inMinutes;

          // Get existing surgeries for the selected day and next 7 days
          final startDate = DateTime.now();
          final endDate = startDate.add(const Duration(days: 7));

          final surgerySnap = await _firestore
              .collection('surgeries')
              .where('startTime',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
              .where('startTime', isLessThan: Timestamp.fromDate(endDate))
              .get();

          List<Map<String, dynamic>> surgeries = surgerySnap.docs
              .map((doc) => {...doc.data(), 'id': doc.id})
              .toList();

          // Generate possible time slots for the next 7 days
          List<Map<String, dynamic>> possibleSlots = [];

          for (int day = 0; day < 7; day++) {
            final slotDate = startDate.add(Duration(days: day));

            // Generate slots from 8 AM to 5 PM every 30 minutes
            DateTime slotTime =
                DateTime(slotDate.year, slotDate.month, slotDate.day, 8, 0);

            while (slotTime.hour < 17) {
              final slotEndTime =
                  slotTime.add(Duration(minutes: durationMinutes));

              // Calculate a compatibility score
              double compatibilityScore = 1.0;
              List<String> conflicts = [];

              // Check for room conflicts
              bool hasRoomConflict = false;
              for (var surgery in surgeries) {
                final surgeryStart =
                    (surgery['startTime'] as Timestamp).toDate();
                final surgeryEnd = (surgery['endTime'] as Timestamp).toDate();

                // Include prep and cleanup times in conflict detection
                final surgeryPrepTime = surgery['prepTimeMinutes'] ?? 0;
                final surgeryCleanupTime = surgery['cleanupTimeMinutes'] ?? 0;

                final actualStart =
                    surgeryStart.subtract(Duration(minutes: surgeryPrepTime));
                final actualEnd =
                    surgeryEnd.add(Duration(minutes: surgeryCleanupTime));

                final slotActualStart =
                    slotTime.subtract(Duration(minutes: _prepTimeMinutes));
                final slotActualEnd =
                    slotEndTime.add(Duration(minutes: _cleanupTimeMinutes));

                if (surgery['room'] == _operatingRoom &&
                    slotActualStart.isBefore(actualEnd) &&
                    slotActualEnd.isAfter(actualStart)) {
                  hasRoomConflict = true;
                  compatibilityScore = 0.0;
                  conflicts.add('Room is already booked');
                  break;
                }
              }

              // Only add non-conflicting slots
              if (!hasRoomConflict) {
                // Check for staff availability
                List<String> unavailableStaff = [];

                if (_selectedDoctor != null) {
                  bool doctorAvailable = true;
                  for (var surgery in surgeries) {
                    final surgeryStart =
                        (surgery['startTime'] as Timestamp).toDate();
                    final surgeryEnd =
                        (surgery['endTime'] as Timestamp).toDate();

                    if (surgery['surgeon'] == _selectedDoctor &&
                        slotTime.isBefore(surgeryEnd) &&
                        slotEndTime.isAfter(surgeryStart)) {
                      doctorAvailable = false;
                      unavailableStaff.add('Surgeon: $_selectedDoctor');
                      compatibilityScore -= 0.3;
                      conflicts.add('Surgeon is unavailable');
                      break;
                    }
                  }
                }

                // Add this time slot with its compatibility score
                if (compatibilityScore > 0) {
                  possibleSlots.add({
                    'startTime': slotTime,
                    'endTime': slotEndTime,
                    'compatibilityScore': compatibilityScore,
                    'conflicts': conflicts,
                  });
                }
              }

              // Move to next 30-minute slot
              slotTime = slotTime.add(const Duration(minutes: 30));
            }
          }

          // Sort by compatibility score (descending)
          possibleSlots.sort((a, b) => (b['compatibilityScore'] as double)
              .compareTo(a['compatibilityScore'] as double));

          // Take top slots
          _recommendedTimeSlots = possibleSlots.take(8).toList();
        } catch (e) {
          debugPrint(
              'Error querying surgeries: $e - falling back to simulated data');
          // If database query fails, fall back to simulated data
          await generateRecommendations(forceGenerate: true);
          return;
        }
      }

      // Sort by the current sort type
      if (_recommendedTimeSlots.isNotEmpty) {
        _recommendedTimeSlots = sortedRecommendations;
      }
    } catch (e) {
      debugPrint('Error generating recommendations: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Selects a recommended time slot
  void selectRecommendedTimeSlot(int index) {
    if (index >= 0 && index < _recommendedTimeSlots.length) {
      final slot = _recommendedTimeSlots[index];
      _startTime = slot['startTime'] as DateTime;
      _endTime = slot['endTime'] as DateTime;
      _selectedRecommendationIndex = index;

      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  /// Validates the form based on the current step
  bool validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Patient Information
        return _patientName.isNotEmpty &&
            _patientAge.isNotEmpty &&
            _patientGender != null &&
            _medicalRecordNumber.isNotEmpty;

      case 1: // Surgery Details
        return _surgeryType != null && _operatingRoom != null;

      case 2: // Time Selection
        return _startTime.isBefore(_endTime) &&
            _endTime.difference(_startTime).inMinutes >= 30;

      case 3: // Staff Selection
        return _selectedDoctor != null && _selectedNurses.isNotEmpty;

      case 4: // Equipment Selection
        return true; // Equipment is optional

      case 5: // Conflict Check
        return true; // This step is informational

      default:
        return true;
    }
  }

  /// Checks for scheduling conflicts
  Future<bool> checkConflicts() async {
    try {
      // Check surgeon conflicts
      if (_selectedDoctor != null) {
        var surgeonConflicts = await _firestore
            .collection('surgeries')
            .where('surgeon', isEqualTo: _selectedDoctor)
            .where('status', whereIn: ['Scheduled', 'In Progress']).get();

        for (var doc in surgeonConflicts.docs) {
          Timestamp surgeryStart = doc.data()['startTime'];
          Timestamp surgeryEnd = doc.data()['endTime'];

          if (_startTime.isBefore(surgeryEnd.toDate()) &&
              _endTime.isAfter(surgeryStart.toDate())) {
            return true; // Conflict found
          }
        }
      }

      // Check nurse conflicts
      for (var nurse in _selectedNurses) {
        var nurseConflicts = await _firestore
            .collection('surgeries')
            .where('nurses', arrayContains: nurse)
            .where('status', whereIn: ['Scheduled', 'In Progress']).get();

        for (var doc in nurseConflicts.docs) {
          Timestamp surgeryStart = doc.data()['startTime'];
          Timestamp surgeryEnd = doc.data()['endTime'];

          if (_startTime.isBefore(surgeryEnd.toDate()) &&
              _endTime.isAfter(surgeryStart.toDate())) {
            return true; // Conflict found
          }
        }
      }

      // Check technologist conflicts
      if (_selectedTechnologist != null) {
        var techConflicts = await _firestore
            .collection('surgeries')
            .where('technologists', arrayContains: _selectedTechnologist)
            .where('status', whereIn: ['Scheduled', 'In Progress']).get();

        for (var doc in techConflicts.docs) {
          Timestamp surgeryStart = doc.data()['startTime'];
          Timestamp surgeryEnd = doc.data()['endTime'];

          if (_startTime.isBefore(surgeryEnd.toDate()) &&
              _endTime.isAfter(surgeryStart.toDate())) {
            return true; // Conflict found
          }
        }
      }

      // Check room conflicts
      if (_operatingRoom != null) {
        var roomConflicts = await _firestore
            .collection('surgeries')
            .where('room', isEqualTo: _operatingRoom)
            .where('status', whereIn: ['Scheduled', 'In Progress']).get();

        for (var doc in roomConflicts.docs) {
          Timestamp surgeryStart = doc.data()['startTime'];
          Timestamp surgeryEnd = doc.data()['endTime'];

          if (_startTime.isBefore(surgeryEnd.toDate()) &&
              _endTime.isAfter(surgeryStart.toDate())) {
            return true; // Conflict found
          }
        }
      }

      return false; // No conflicts
    } catch (e) {
      debugPrint("Error checking conflicts: $e");
      return true; // Assume conflict on error
    }
  }

  /// Creates equipment requirements from selected equipment
  List<SurgeryEquipmentRequirement> createEquipmentRequirements() {
    List<SurgeryEquipmentRequirement> requirements = [];

    for (final equipmentId in _selectedEquipmentIds) {
      // Determine if this equipment is required or optional
      final isRequired = _requiredEquipment[equipmentId] ?? false;

      // Set up times - for now, we'll use the surgery times
      final setupStart =
          _startTime.subtract(Duration(minutes: _prepTimeMinutes));
      final requiredUntil =
          _endTime.add(Duration(minutes: _cleanupTimeMinutes));

      // Create the requirement object
      requirements.add(SurgeryEquipmentRequirement(
        equipmentId: equipmentId,
        equipmentName:
            'Equipment $equipmentId', // This would be fetched from the equipment repository in a real app
        isRequired: isRequired,
        setupStartTime: setupStart,
        requiredUntilTime: requiredUntil,
      ));
    }

    return requirements;
  }

  // Getters
  int get currentStep => _currentStep;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get showPreview => _showPreview;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  bool get advancedMode => _advancedMode;

  String get patientName => _patientName;
  String get patientAge => _patientAge;
  String? get patientGender => _patientGender;
  String get medicalRecordNumber => _medicalRecordNumber;

  String? get surgeryType => _surgeryType;
  String? get operatingRoom => _operatingRoom;
  String get notes => _notes;

  DateTime get startTime => _startTime;
  DateTime get endTime => _endTime;
  int get prepTimeMinutes => _prepTimeMinutes;
  int get cleanupTimeMinutes => _cleanupTimeMinutes;

  String? get selectedDoctor => _selectedDoctor;
  List<String> get selectedNurses => _selectedNurses;
  String? get selectedTechnologist => _selectedTechnologist;

  Set<String> get selectedEquipmentIds => _selectedEquipmentIds;
  Map<String, bool> get requiredEquipment => _requiredEquipment;

  List<Map<String, dynamic>> get recommendedTimeSlots => _recommendedTimeSlots;
  int get selectedRecommendationIndex => _selectedRecommendationIndex;
  String get recommendationSortType => _recommendationSortType;

  /// Gets the duration of the surgery in minutes
  int get surgeryDuration => _endTime.difference(_startTime).inMinutes;

  /// Gets the total duration including prep and cleanup time
  int get totalDuration =>
      _prepTimeMinutes +
      surgeryDuration +
      _cleanupTimeMinutes +
      customBlocksDuration;

  /// Gets formatted strings for the surgery times
  String get formattedStartTime =>
      DateFormat('MMM dd, yyyy  hh:mm a').format(_startTime);
  String get formattedEndTime =>
      DateFormat('MMM dd, yyyy  hh:mm a').format(_endTime);

  /// Gets the actual start time including prep time
  DateTime get actualStartTime =>
      _startTime.subtract(Duration(minutes: _prepTimeMinutes));

  /// Gets the actual end time including cleanup time
  DateTime get actualEndTime =>
      _endTime.add(Duration(minutes: _cleanupTimeMinutes));

  /// Gets the duration management values
  int get durationHours => _durationHours;
  int get durationMinutes => _durationMinutes;
  List<Map<String, dynamic>> get timeBlocks => _timeBlocks;

  /// Toggles the advanced mode
  void toggleAdvancedMode() {
    _advancedMode = !_advancedMode;
    notifyListeners();
  }

  /// Adds a new time block
  void addTimeBlock({String name = '', int durationMinutes = 30}) {
    // Add a custom named time block to the total block time
    _timeBlocks.add({
      'name': name.isEmpty ? 'Custom Block' : name,
      'durationMinutes': durationMinutes,
      'isCustom': true,
    });

    // Update the total block time
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  /// Removes a time block at the specified index
  void removeTimeBlock(int index) {
    if (index >= 0 && index < _timeBlocks.length) {
      _timeBlocks.removeAt(index);
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  /// Gets the total duration of all custom time blocks
  int get customBlocksDuration {
    int total = 0;
    for (final block in _timeBlocks) {
      if (block['isCustom'] == true) {
        total += block['durationMinutes'] as int;
      }
    }
    return total;
  }

  /// Gets the total block time including surgery, prep, cleanup, and custom blocks
  int get grandTotalDuration =>
      surgeryDuration +
      _prepTimeMinutes +
      _cleanupTimeMinutes +
      customBlocksDuration;

  /// Schedules a form save after a delay
  void _scheduleSave() {
    // Cancel any existing timer
    _autoSaveTimer?.cancel();

    // Schedule a new save in 2 seconds
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      saveFormState();
    });
  }

  /// Sorted recommendations based on current sort type
  List<Map<String, dynamic>> get sortedRecommendations {
    if (_recommendedTimeSlots.isEmpty) return [];

    final List<Map<String, dynamic>> sorted = List.from(_recommendedTimeSlots);

    switch (_recommendationSortType) {
      case 'earliest':
        sorted.sort((a, b) {
          final DateTime aTime = a['startTime'] as DateTime;
          final DateTime bTime = b['startTime'] as DateTime;
          return aTime.compareTo(bTime);
        });
        break;
      case 'compatibility':
        sorted.sort((a, b) {
          final double aScore = a['compatibilityScore'] as double;
          final double bScore = b['compatibilityScore'] as double;
          return bScore.compareTo(aScore); // Higher score first
        });
        break;
      case 'thisWeek':
        final now = DateTime.now();
        final endOfWeek = now.add(Duration(days: 7 - now.weekday));

        // First sort by score
        sorted.sort((a, b) {
          final double aScore = a['compatibilityScore'] as double;
          final double bScore = b['compatibilityScore'] as double;
          return bScore.compareTo(aScore);
        });

        // Then move this week's slots to the top
        sorted.sort((a, b) {
          final DateTime aTime = a['startTime'] as DateTime;
          final DateTime bTime = b['startTime'] as DateTime;
          final bool aIsThisWeek = aTime.isBefore(endOfWeek);
          final bool bIsThisWeek = bTime.isBefore(endOfWeek);

          if (aIsThisWeek && !bIsThisWeek) return -1;
          if (!aIsThisWeek && bIsThisWeek) return 1;
          return 0;
        });
        break;
    }

    return sorted;
  }

  /// Sets the sort type for recommendations
  void setSortType(String sortType) {
    if (_recommendationSortType != sortType) {
      _recommendationSortType = sortType;
      notifyListeners();
    }
  }

  /// Clears the selected recommendation
  void clearSelectedRecommendation() {
    if (_selectedRecommendationIndex >= 0) {
      _selectedRecommendationIndex = -1;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }
}

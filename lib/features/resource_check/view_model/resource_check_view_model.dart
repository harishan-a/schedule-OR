import 'package:flutter/material.dart';
import 'package:firebase_orscheduler/domain/scheduling/conflict_detector.dart';
import 'package:firebase_orscheduler/data/repositories/user_repository.dart';
import 'package:firebase_orscheduler/core/constants/surgery_constants.dart';
import 'package:logging/logging.dart';

/// ViewModel for the resource check feature.
/// Uses SurgeryConstants instead of hardcoded room lists.
class ResourceCheckViewModel extends ChangeNotifier {
  final ConflictDetector _conflictDetector;
  final UserRepository _userRepository;
  final _logger = Logger('ResourceCheckViewModel');

  // Selected resources
  String? selectedRoom;
  String? selectedDoctor;
  List<String> selectedNurses = [];
  String? selectedTechnologist;

  // Time range
  DateTime startTime = DateTime.now();
  DateTime endTime = DateTime.now().add(const Duration(hours: 1));

  // Results
  List<ConflictResult> conflicts = [];
  bool isLoading = false;
  String? error;

  // Staff lists
  List<String> doctors = [];
  List<String> nurses = [];
  List<String> technologists = [];

  /// Available rooms from constants (not hardcoded).
  List<String> get availableRooms => SurgeryConstants.operatingRooms;

  ResourceCheckViewModel({
    ConflictDetector? conflictDetector,
    UserRepository? userRepository,
  })  : _conflictDetector = conflictDetector ?? ConflictDetector(),
        _userRepository = userRepository ?? UserRepository() {
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    try {
      final results = await Future.wait([
        _userRepository.getDoctorNames(),
        _userRepository.getNurseNames(),
        _userRepository.getTechnologistNames(),
      ]);
      doctors = results[0];
      nurses = results[1];
      technologists = results[2];
      notifyListeners();
    } catch (e) {
      _logger.warning('Error loading staff: $e');
    }
  }

  /// Check for conflicts with current selections.
  Future<void> checkConflicts() async {
    isLoading = true;
    error = null;
    conflicts = [];
    notifyListeners();

    try {
      conflicts = await _conflictDetector.checkConflicts(
        roomId: selectedRoom ?? '',
        startTime: startTime,
        endTime: endTime,
        surgeonId: selectedDoctor ?? '',
        nurseIds: selectedNurses,
        technologistId: selectedTechnologist,
      );
      _logger.info('Found ${conflicts.length} conflicts');
    } catch (e) {
      error = 'Failed to check conflicts';
      _logger.warning('Error checking conflicts: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    selectedRoom = null;
    selectedDoctor = null;
    selectedNurses = [];
    selectedTechnologist = null;
    startTime = DateTime.now();
    endTime = DateTime.now().add(const Duration(hours: 1));
    conflicts = [];
    error = null;
    notifyListeners();
  }
}

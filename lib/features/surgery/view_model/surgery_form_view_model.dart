import 'package:flutter/material.dart';
import 'package:firebase_orscheduler/data/repositories/surgery_repository.dart';
import 'package:firebase_orscheduler/data/repositories/user_repository.dart';
import 'package:logging/logging.dart';

/// ViewModel for the surgery form screens (add/edit).
/// Wraps the existing SurgeryFormProvider and adds repository-based data access.
class SurgeryFormViewModel extends ChangeNotifier {
  final SurgeryRepository _surgeryRepository;
  final UserRepository _userRepository;
  final _logger = Logger('SurgeryFormViewModel');

  List<String> doctors = [];
  List<String> nurses = [];
  List<String> technologists = [];
  bool isLoadingStaff = true;
  String? error;

  SurgeryFormViewModel({
    SurgeryRepository? surgeryRepository,
    UserRepository? userRepository,
  })  : _surgeryRepository = surgeryRepository ?? SurgeryRepository(),
        _userRepository = userRepository ?? UserRepository() {
    loadStaffLists();
  }

  /// Load staff lists from repository instead of inline Firestore calls.
  Future<void> loadStaffLists() async {
    isLoadingStaff = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _userRepository.getDoctorNames(),
        _userRepository.getNurseNames(),
        _userRepository.getTechnologistNames(),
      ]);

      doctors = results[0]..sort();
      nurses = results[1]..sort();
      technologists = results[2]..sort();
    } catch (e) {
      _logger.warning('Error loading staff lists: $e');
      error = 'Failed to load staff lists';
    } finally {
      isLoadingStaff = false;
      notifyListeners();
    }
  }

  /// Submit the surgery form data to the repository.
  Future<String> submitSurgery(Map<String, dynamic> data) async {
    try {
      final id = await _surgeryRepository.addSurgery(data);
      _logger.info('Surgery submitted: $id');
      return id;
    } catch (e) {
      _logger.warning('Error submitting surgery: $e');
      rethrow;
    }
  }

  /// Update an existing surgery.
  Future<void> updateSurgery(
      String surgeryId, Map<String, dynamic> data) async {
    try {
      await _surgeryRepository.updateSurgery(surgeryId, data);
      _logger.info('Surgery updated: $surgeryId');
    } catch (e) {
      _logger.warning('Error updating surgery: $e');
      rethrow;
    }
  }
}

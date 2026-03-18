import 'package:flutter/material.dart';
import 'package:firebase_orscheduler/data/repositories/surgery_repository.dart';
import 'package:firebase_orscheduler/features/schedule/models/surgery.dart';
import 'package:logging/logging.dart';

/// ViewModel for the surgery details screen.
class SurgeryDetailsViewModel extends ChangeNotifier {
  final SurgeryRepository _surgeryRepository;
  final _logger = Logger('SurgeryDetailsViewModel');

  Surgery? _surgery;
  bool _isLoading = false;
  String? _error;

  SurgeryDetailsViewModel({SurgeryRepository? surgeryRepository})
      : _surgeryRepository = surgeryRepository ?? SurgeryRepository();

  Surgery? get surgery => _surgery;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Stream a surgery by ID for real-time updates.
  Stream<Surgery?> getSurgeryStream(String surgeryId) {
    return _surgeryRepository.getSurgeryStream(surgeryId);
  }

  /// Update surgery status.
  Future<void> updateStatus(String surgeryId, String newStatus) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _surgeryRepository.updateSurgeryStatus(surgeryId, newStatus);
      _logger.info('Status updated: $surgeryId -> $newStatus');
    } catch (e) {
      _error = 'Failed to update status: $e';
      _logger.warning(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a surgery.
  Future<bool> deleteSurgery(String surgeryId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _surgeryRepository.deleteSurgery(surgeryId);
      _logger.info('Surgery deleted: $surgeryId');
      return true;
    } catch (e) {
      _error = 'Failed to delete surgery: $e';
      _logger.warning(_error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

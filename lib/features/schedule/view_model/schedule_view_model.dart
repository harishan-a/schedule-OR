import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_orscheduler/features/schedule/models/surgery.dart';
import 'package:firebase_orscheduler/data/repositories/surgery_repository.dart';
import 'package:firebase_orscheduler/core/enums/schedule_view_type.dart';

/// ViewModel for the schedule feature.
/// Manages schedule state and delegates data access to SurgeryRepository.
class ScheduleViewModel extends ChangeNotifier {
  final SurgeryRepository _surgeryRepository;

  ScheduleViewType _currentView = ScheduleViewType.day;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _error;

  ScheduleViewModel({SurgeryRepository? surgeryRepository})
      : _surgeryRepository = surgeryRepository ?? SurgeryRepository();

  // Getters
  ScheduleViewType get currentView => _currentView;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Change the schedule view type.
  void setView(ScheduleViewType view) {
    _currentView = view;
    notifyListeners();
  }

  /// Change the selected date.
  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  /// Navigate to the next day/week/month based on current view.
  void navigateForward() {
    switch (_currentView) {
      case ScheduleViewType.day:
        _selectedDate = _selectedDate.add(const Duration(days: 1));
        break;
      case ScheduleViewType.week:
        _selectedDate = _selectedDate.add(const Duration(days: 7));
        break;
      case ScheduleViewType.month:
        _selectedDate =
            DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
        break;
      case ScheduleViewType.tv:
        _selectedDate = _selectedDate.add(const Duration(days: 1));
        break;
    }
    notifyListeners();
  }

  /// Navigate to the previous day/week/month based on current view.
  void navigateBackward() {
    switch (_currentView) {
      case ScheduleViewType.day:
        _selectedDate = _selectedDate.subtract(const Duration(days: 1));
        break;
      case ScheduleViewType.week:
        _selectedDate = _selectedDate.subtract(const Duration(days: 7));
        break;
      case ScheduleViewType.month:
        _selectedDate =
            DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
        break;
      case ScheduleViewType.tv:
        _selectedDate = _selectedDate.subtract(const Duration(days: 1));
        break;
    }
    notifyListeners();
  }

  /// Jump to today.
  void goToToday() {
    _selectedDate = DateTime.now();
    notifyListeners();
  }

  /// Stream all surgeries (delegates to repository).
  Stream<List<Surgery>> getSurgeriesStream() {
    return _surgeryRepository.getSurgeriesStream();
  }

  /// Stream surgeries for a date range.
  Stream<List<Surgery>> getSurgeriesByDateRange(DateTime start, DateTime end) {
    return _surgeryRepository.getSurgeriesByDateRange(start, end);
  }

  /// Stream all surgeries as raw QuerySnapshot (backward compat).
  Stream<QuerySnapshot> getSurgeriesQueryStream() {
    return _surgeryRepository.getSurgeriesQueryStream();
  }

  /// Update surgery status.
  Future<void> updateSurgeryStatus(String surgeryId, String newStatus) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _surgeryRepository.updateSurgeryStatus(surgeryId, newStatus);
    } catch (e) {
      _error = 'Error updating surgery status: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a surgery.
  Future<void> deleteSurgery(String surgeryId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _surgeryRepository.deleteSurgery(surgeryId);
    } catch (e) {
      _error = 'Error deleting surgery: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

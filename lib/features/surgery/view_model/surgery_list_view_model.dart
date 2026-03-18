import 'package:flutter/material.dart';
import 'package:firebase_orscheduler/data/repositories/surgery_repository.dart';
import 'package:firebase_orscheduler/features/schedule/models/surgery.dart';
import 'package:logging/logging.dart';

/// ViewModel for surgery list screens (filtered, log).
class SurgeryListViewModel extends ChangeNotifier {
  final SurgeryRepository _surgeryRepository;
  final _logger = Logger('SurgeryListViewModel');

  String? _statusFilter;
  String? _searchQuery;
  bool _isLoading = false;
  String? _error;

  SurgeryListViewModel({SurgeryRepository? surgeryRepository})
      : _surgeryRepository = surgeryRepository ?? SurgeryRepository();

  String? get statusFilter => _statusFilter;
  String? get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setStatusFilter(String? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setSearchQuery(String? query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Stream all surgeries with optional client-side filtering.
  Stream<List<Surgery>> getSurgeriesStream() {
    return _surgeryRepository.getSurgeriesStream().map((surgeries) {
      var filtered = surgeries;

      if (_statusFilter != null && _statusFilter!.isNotEmpty) {
        filtered = filtered.where((s) => s.status == _statusFilter).toList();
      }

      if (_searchQuery != null && _searchQuery!.isNotEmpty) {
        final query = _searchQuery!.toLowerCase();
        filtered = filtered
            .where((s) =>
                s.patientName.toLowerCase().contains(query) ||
                s.surgeryType.toLowerCase().contains(query) ||
                s.surgeon.toLowerCase().contains(query))
            .toList();
      }

      return filtered;
    });
  }

  /// Get user's surgeries stream.
  Stream<List<Surgery>> getUserSurgeriesStream() {
    return _surgeryRepository.getUserSurgeriesStream();
  }
}

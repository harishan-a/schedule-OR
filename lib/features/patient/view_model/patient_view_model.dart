import 'package:flutter/material.dart';
import 'package:firebase_orscheduler/data/repositories/surgery_repository.dart';
import 'package:firebase_orscheduler/features/schedule/models/surgery.dart';
import 'package:logging/logging.dart';

/// ViewModel for the patient lookup screen.
class PatientViewModel extends ChangeNotifier {
  final SurgeryRepository _surgeryRepository;
  final _logger = Logger('PatientViewModel');

  List<Surgery> _results = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _searchType = 'name'; // 'name' or 'id'

  PatientViewModel({SurgeryRepository? surgeryRepository})
      : _surgeryRepository = surgeryRepository ?? SurgeryRepository();

  List<Surgery> get results => _results;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get searchType => _searchType;

  void setSearchType(String type) {
    _searchType = type;
    notifyListeners();
  }

  /// Validate and search for patient records.
  Future<void> search(String query) async {
    _searchQuery = query.trim();

    // Proper input validation (Enhancement #6)
    if (_searchQuery.isEmpty) {
      _error = 'Please enter a search term';
      notifyListeners();
      return;
    }

    if (_searchType == 'name' && _searchQuery.length < 2) {
      _error = 'Please enter at least 2 characters for name search';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_searchType == 'id') {
        _results = await _surgeryRepository.searchByPatientId(_searchQuery);
      } else {
        _results = await _surgeryRepository.searchByPatientName(_searchQuery);
      }

      if (_results.isEmpty) {
        _error = 'No records found for "$_searchQuery"';
      }

      _logger.info(
          'Patient search: $_searchType="$_searchQuery" found ${_results.length} results');
    } catch (e) {
      _error = 'Search failed. Please try again.';
      _logger.warning('Patient search error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearResults() {
    _results = [];
    _error = null;
    _searchQuery = '';
    notifyListeners();
  }
}

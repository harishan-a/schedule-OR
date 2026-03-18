import 'package:flutter/material.dart';
import 'package:firebase_orscheduler/data/repositories/user_repository.dart';
import 'package:logging/logging.dart';

/// ViewModel for the staff directory screen.
/// Provides working search (replaces "Search coming soon!" snackbar).
class StaffViewModel extends ChangeNotifier {
  final UserRepository _userRepository;
  final _logger = Logger('StaffViewModel');

  List<Map<String, dynamic>> _allStaff = [];
  List<Map<String, dynamic>> _filteredStaff = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String? _roleFilter;
  String? _departmentFilter;

  StaffViewModel({UserRepository? userRepository})
      : _userRepository = userRepository ?? UserRepository() {
    loadStaff();
  }

  List<Map<String, dynamic>> get staff => _filteredStaff;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String? get roleFilter => _roleFilter;
  String? get departmentFilter => _departmentFilter;

  /// Load all staff from repository.
  Future<void> loadStaff() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allStaff = await _userRepository.getAllStaff();
      _applyFilters();
      _logger.info('Loaded ${_allStaff.length} staff members');
    } catch (e) {
      _error = 'Failed to load staff directory';
      _logger.warning('Error loading staff: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Stream all staff for real-time updates.
  Stream<List<Map<String, dynamic>>> getStaffStream() {
    return _userRepository.getAllStaffStream();
  }

  /// Search staff by name or role (Enhancement #1 - replaces "Search coming soon!").
  void search(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  /// Filter by role.
  void setRoleFilter(String? role) {
    _roleFilter = role;
    _applyFilters();
    notifyListeners();
  }

  /// Filter by department.
  void setDepartmentFilter(String? department) {
    _departmentFilter = department;
    _applyFilters();
    notifyListeners();
  }

  /// Clear all filters.
  void clearFilters() {
    _searchQuery = '';
    _roleFilter = null;
    _departmentFilter = null;
    _applyFilters();
    notifyListeners();
  }

  /// Apply all filters to the staff list.
  void _applyFilters() {
    _filteredStaff = _allStaff.where((staff) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final firstName = (staff['firstName'] as String? ?? '').toLowerCase();
        final lastName = (staff['lastName'] as String? ?? '').toLowerCase();
        final role = (staff['role'] as String? ?? '').toLowerCase();
        final department = (staff['department'] as String? ?? '').toLowerCase();

        if (!firstName.contains(query) &&
            !lastName.contains(query) &&
            !role.contains(query) &&
            !department.contains(query)) {
          return false;
        }
      }

      // Role filter
      if (_roleFilter != null && _roleFilter!.isNotEmpty) {
        if (staff['role'] != _roleFilter) return false;
      }

      // Department filter
      if (_departmentFilter != null && _departmentFilter!.isNotEmpty) {
        if (staff['department'] != _departmentFilter) return false;
      }

      return true;
    }).toList();
  }
}

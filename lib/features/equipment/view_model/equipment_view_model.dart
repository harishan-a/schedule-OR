import 'package:flutter/material.dart';
import 'package:firebase_orscheduler/features/equipment/repositories/equipment_repository.dart';
import 'package:firebase_orscheduler/features/equipment/models/equipment.dart';
import 'package:logging/logging.dart';

/// ViewModel for the equipment catalog screen.
class EquipmentViewModel extends ChangeNotifier {
  final EquipmentRepository _equipmentRepository;
  final _logger = Logger('EquipmentViewModel');

  List<Equipment> _equipment = [];
  List<Equipment> _filteredEquipment = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String? _categoryFilter;
  bool? _availabilityFilter;

  EquipmentViewModel({EquipmentRepository? equipmentRepository})
      : _equipmentRepository = equipmentRepository ?? EquipmentRepository() {
    loadEquipment();
  }

  List<Equipment> get equipment => _filteredEquipment;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String? get categoryFilter => _categoryFilter;
  bool? get availabilityFilter => _availabilityFilter;

  /// Load all equipment.
  Future<void> loadEquipment() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _equipment = await _equipmentRepository.getAllEquipment();
      _applyFilters();
      _logger.info('Loaded ${_equipment.length} equipment items');
    } catch (e) {
      _error = 'Failed to load equipment';
      _logger.warning('Error loading equipment: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Stream equipment for real-time updates.
  Stream<List<Equipment>> getEquipmentStream() {
    return _equipmentRepository.getAllEquipmentStream();
  }

  void search(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void setCategoryFilter(String? category) {
    _categoryFilter = category;
    _applyFilters();
    notifyListeners();
  }

  void setAvailabilityFilter(bool? available) {
    _availabilityFilter = available;
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _categoryFilter = null;
    _availabilityFilter = null;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    _filteredEquipment = _equipment.where((item) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!item.name.toLowerCase().contains(query) &&
            !item.category.toLowerCase().contains(query)) {
          return false;
        }
      }

      if (_categoryFilter != null && _categoryFilter!.isNotEmpty) {
        if (item.category != _categoryFilter) return false;
      }

      if (_availabilityFilter != null) {
        if (item.isAvailable != _availabilityFilter) return false;
      }

      return true;
    }).toList();
  }

  /// Update equipment availability.
  Future<void> updateAvailability(String id, bool available) async {
    try {
      await _equipmentRepository.updateEquipmentAvailability(id, available);
      await loadEquipment(); // Refresh
    } catch (e) {
      _logger.warning('Error updating equipment availability: $e');
    }
  }
}

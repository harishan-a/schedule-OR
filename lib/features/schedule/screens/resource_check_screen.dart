// =============================================================================
// Resource Check Screen
// =============================================================================
// A screen that provides real-time resource availability checking:
// - Operating Rooms
// - Medical Staff (Doctors, Nurses, Technologists)
// - Time Slots
//
// Features:
// - Date and time selection
// - Resource filtering
// - Real-time availability updates
// - Search functionality
//
// Resource Service Integration:
// - Firestore queries for availability
// - Staff list population
// - Conflict detection
//
// Note: This screen uses a service layer for resource checks to separate
// business logic from UI concerns. All Firestore operations are delegated
// to ResourceCheckService.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/resource_check_service.dart';

/// Screen for checking resource availability with filtering options
class ResourceCheckScreen extends StatefulWidget {
  /// Initial date for availability check
  final DateTime? initialDate;
  
  /// Initial time for availability check
  final TimeOfDay? initialTime;
  
  /// Whether screen is standalone or embedded
  final bool isStandalone;

  const ResourceCheckScreen({
    super.key,
    this.initialDate,
    this.initialTime,
    this.isStandalone = true,
  });

  @override
  State<ResourceCheckScreen> createState() => _ResourceCheckScreenState();
}

class _ResourceCheckScreenState extends State<ResourceCheckScreen> {
  // Service for resource availability checks
  final ResourceCheckService _resourceService = ResourceCheckService();

  // Selected date and time
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  
  // Resource filtering
  String _selectedResourceType = 'Rooms';
  String _searchQuery = '';
  
  // UI state
  bool _isLoading = false;
  List<DocumentSnapshot> _availableResources = [];

  // Resource type options
  final List<String> _resourceTypes = ['Rooms', 'Doctors', 'Nurses', 'Technologists'];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize with provided date/time if available
    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    }
    if (widget.initialTime != null) {
      _selectedTime = widget.initialTime!;
    }
    _loadAvailability();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Loads available resources for selected time slot
  /// 
  /// Process:
  /// 1. Set loading state
  /// 2. Calculate time range
  /// 3. Query appropriate resource type
  /// 4. Handle errors
  /// 5. Update UI
  Future<void> _loadAvailability() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Calculate time range for availability check
      final startTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      final endTime = startTime.add(const Duration(hours: 2));

      // Query appropriate resource type
      switch (_selectedResourceType) {
        case 'Rooms':
          _availableResources = await _resourceService.getAvailableRooms(startTime, endTime);
          break;
        case 'Doctors':
          _availableResources = await _resourceService.getAvailableStaff(startTime, endTime, 'Doctor');
          break;
        case 'Nurses':
          _availableResources = await _resourceService.getAvailableStaff(startTime, endTime, 'Nurse');
          break;
        case 'Technologists':
          _availableResources = await _resourceService.getAvailableStaff(startTime, endTime, 'Technologist');
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading availability: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resource Check'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAvailability,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildResourceList(),
          ),
        ],
      ),
    );
  }

  /// Builds the filter section with:
  /// - Date/time selection
  /// - Search bar
  /// - Resource type filters
  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date and time selection row
          Row(
            children: [
              Expanded(
                child: _buildDatePicker(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTimePicker(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search resources...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
          const SizedBox(height: 16),
          // Resource type filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _resourceTypes.map((type) {
                final isSelected = _selectedResourceType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedResourceType = type;
                      });
                      _loadAvailability();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the date picker with formatted display
  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null && mounted) {
          setState(() {
            _selectedDate = date;
          });
          _loadAvailability();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('MMM dd, yyyy').format(_selectedDate),
              style: const TextStyle(fontSize: 16),
            ),
            const Icon(Icons.calendar_today),
          ],
        ),
      ),
    );
  }

  /// Builds the time picker with formatted display
  Widget _buildTimePicker() {
    return InkWell(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: _selectedTime,
        );
        if (time != null && mounted) {
          setState(() {
            _selectedTime = time;
          });
          _loadAvailability();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedTime.format(context),
              style: const TextStyle(fontSize: 16),
            ),
            const Icon(Icons.access_time),
          ],
        ),
      ),
    );
  }

  /// Builds the list of available resources
  /// 
  /// Features:
  /// - Search filtering
  /// - Empty state handling
  /// - Resource cards with details
  Widget _buildResourceList() {
    // Filter resources based on search query
    final filteredResources = _availableResources.where((resource) {
      final data = resource.data() as Map<String, dynamic>;
      final name = data['name']?.toString().toLowerCase() ?? '';
      final description = data['description']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery) || description.contains(_searchQuery);
    }).toList();

    // Show empty state if no resources found
    if (filteredResources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEmptyStateIcon(),
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No available ${_selectedResourceType.toLowerCase()}',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Try selecting a different time or date',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    // Build resource list
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredResources.length,
      itemBuilder: (context, index) {
        final resource = filteredResources[index];
        final data = resource.data() as Map<String, dynamic>;
        return _buildResourceCard(resource.id, data);
      },
    );
  }

  /// Builds a card for displaying resource details
  Widget _buildResourceCard(String resourceId, Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Icon(
            _getResourceIcon(),
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          data['name'] ?? 'Unknown',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['description'] != null)
              Text(data['description']),
            if (data['specialization'] != null)
              Text('Specialization: ${data['specialization']}'),
          ],
        ),
        trailing: widget.isStandalone
            ? const Icon(Icons.check_circle, color: Colors.green)
            : IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  Navigator.pop(context, {
                    'id': resourceId,
                    'data': data,
                  });
                },
              ),
      ),
    );
  }

  /// Returns appropriate icon for current resource type
  IconData _getResourceIcon() {
    switch (_selectedResourceType) {
      case 'Rooms':
        return Icons.meeting_room;
      case 'Doctors':
        return Icons.medical_services;
      case 'Nurses':
        return Icons.local_hospital;
      case 'Technologists':
        return Icons.engineering;
      default:
        return Icons.category;
    }
  }

  /// Returns appropriate empty state icon for current resource type
  IconData _getEmptyStateIcon() {
    switch (_selectedResourceType) {
      case 'Rooms':
        return Icons.meeting_room_outlined;
      case 'Doctors':
        return Icons.medical_services_outlined;
      case 'Nurses':
        return Icons.local_hospital_outlined;
      case 'Technologists':
        return Icons.engineering_outlined;
      default:
        return Icons.search_off_outlined;
    }
  }
}

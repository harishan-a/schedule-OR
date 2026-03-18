// =============================================================================
// Resource Check Screen
// =============================================================================
// A screen that provides real-time resource availability checking:
// - Operating Rooms
// - Medical Staff (Doctors, Nurses, Technologists)
// - Equipment
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
import 'package:firebase_orscheduler/features/equipment/repositories/equipment_repository.dart';
import 'package:firebase_orscheduler/features/equipment/models/equipment.dart';

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

class _ResourceCheckScreenState extends State<ResourceCheckScreen>
    with SingleTickerProviderStateMixin {
  // Services for resource availability checks
  final ResourceCheckService _resourceService = ResourceCheckService();
  final EquipmentRepository _equipmentRepository = EquipmentRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Selected date and time
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  // Resource filtering
  String _selectedResourceType = 'Rooms';
  String _searchQuery = '';

  // UI state
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  List<DocumentSnapshot> _availableResources = [];
  List<DocumentSnapshot> _unavailableResources = [];
  List<Equipment> _availableEquipment = [];
  List<Equipment> _unavailableEquipment = [];

  // Resource type options
  final List<String> _resourceTypes = [
    'Rooms',
    'Doctors',
    'Nurses',
    'Technologists',
    'Equipment'
  ];
  final TextEditingController _searchController = TextEditingController();

  // Calculated time range for availability checks
  late DateTime _startTime;
  late DateTime _endTime;

  // Tab controller for available/unavailable tabs
  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    // Initialize with provided date/time if available
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedTime = widget.initialTime ?? TimeOfDay.now();

    _updateTimeRange();
    _tabController = TabController(length: 2, vsync: this);

    // Load data after a short delay to allow UI to build first
    Future.microtask(() => _loadData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Updates the time range based on selected date and time
  void _updateTimeRange() {
    _startTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    _endTime = _startTime.add(const Duration(hours: 2));
  }

  /// Load all necessary data at once
  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      _updateTimeRange();
      await _loadAllData();
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error loading resources: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading resources: $e')),
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

  /// Load all data for the selected resource type
  Future<void> _loadAllData() async {
    switch (_selectedResourceType) {
      case 'Equipment':
        await _loadEquipmentData();
        break;
      case 'Rooms':
        await _loadRoomData();
        break;
      case 'Doctors':
      case 'Nurses':
      case 'Technologists':
        await _loadStaffData(_selectedResourceType);
        break;
    }
  }

  /// Load equipment data
  Future<void> _loadEquipmentData() async {
    try {
      // Get all equipment (available and unavailable)
      final allEquipment = await _equipmentRepository.getAllEquipment();

      // Check which equipment is available during the timeframe
      final availableDuringTimeframe = await _equipmentRepository
          .getAvailableEquipmentDuringTimeframe(_startTime, _endTime);

      // Extract IDs of available equipment for lookup
      final availableIds = availableDuringTimeframe.map((e) => e.id).toSet();

      // Sort equipment into available and unavailable lists
      if (mounted) {
        setState(() {
          _availableEquipment =
              allEquipment.where((e) => availableIds.contains(e.id)).toList();
          _unavailableEquipment =
              allEquipment.where((e) => !availableIds.contains(e.id)).toList();

          // Clear other resource lists to save memory
          _availableResources = [];
          _unavailableResources = [];
        });
      }
    } catch (e) {
      throw Exception('Failed to load equipment data: $e');
    }
  }

  /// Load room data
  Future<void> _loadRoomData() async {
    try {
      // Get all rooms
      final allRooms = await _firestore.collection('rooms').get();

      // Get available rooms during timeframe
      final availableRooms =
          await _resourceService.getAvailableRooms(_startTime, _endTime);

      // Extract IDs of available rooms for lookup
      final availableIds = availableRooms.map((doc) => doc.id).toSet();

      // Sort rooms into available and unavailable lists
      if (mounted) {
        setState(() {
          _availableResources = availableRooms;
          _unavailableResources = allRooms.docs
              .where((doc) => !availableIds.contains(doc.id))
              .toList();

          // Clear equipment lists to save memory
          _availableEquipment = [];
          _unavailableEquipment = [];
        });
      }
    } catch (e) {
      throw Exception('Failed to load room data: $e');
    }
  }

  /// Load staff data (doctors, nurses, technologists)
  Future<void> _loadStaffData(String role) async {
    try {
      // Convert role string to actual DB role name
      String dbRole = role;
      if (role == 'Doctors') dbRole = 'Doctor';
      if (role == 'Nurses') dbRole = 'Nurse';
      if (role == 'Technologists') dbRole = 'Technologist';

      // Get all staff of this role
      final allStaff = await _firestore
          .collection('users')
          .where('role', isEqualTo: dbRole)
          .get();

      // Get available staff during timeframe
      final availableStaff = await _resourceService.getAvailableStaff(
          _startTime, _endTime, dbRole);

      // Extract IDs of available staff for lookup
      final availableIds = availableStaff.map((doc) => doc.id).toSet();

      // Sort staff into available and unavailable lists
      if (mounted) {
        setState(() {
          _availableResources = availableStaff;
          _unavailableResources = allStaff.docs
              .where((doc) => !availableIds.contains(doc.id))
              .toList();

          // Clear equipment lists to save memory
          _availableEquipment = [];
          _unavailableEquipment = [];
        });
      }
    } catch (e) {
      throw Exception('Failed to load $role data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resource Check'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Available'),
            Tab(text: 'Unavailable'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildDateTimeSection(theme),
          _buildResourceTypeChips(theme),
          _buildSearchBar(theme),
          Expanded(
            child: _hasError
                ? _buildErrorState(theme)
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          // Available resources tab
                          _buildResourceList(true),
                          // Unavailable resources tab
                          _buildResourceList(false),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  /// Builds date and time selection section
  Widget _buildDateTimeSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Date & Time',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDatePicker(theme),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTimePicker(theme),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds resource type filter chips
  Widget _buildResourceTypeChips(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resource Type',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _resourceTypes.length,
              itemBuilder: (context, index) {
                final type = _resourceTypes[index];
                final isSelected = _selectedResourceType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (_isLoading)
                        return; // Prevent selection during loading

                      setState(() {
                        _selectedResourceType = type;
                      });
                      _loadData();
                    },
                    showCheckmark: false,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: theme.colorScheme.surface,
                    selectedColor: theme.colorScheme.primary,
                    side: BorderSide(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Builds search bar
  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search ${_selectedResourceType.toLowerCase()}...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.colorScheme.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.colorScheme.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
      ),
    );
  }

  /// Builds the date picker with formatted display
  Widget _buildDatePicker(ThemeData theme) {
    return InkWell(
      onTap: () async {
        if (_isLoading) return; // Prevent selection during loading

        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now().subtract(
              const Duration(days: 30)), // Allow checking past dates too
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null && mounted) {
          setState(() {
            _selectedDate = date;
          });
          _loadData();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('MMM dd, yyyy').format(_selectedDate),
              style: theme.textTheme.bodyLarge,
            ),
            Icon(Icons.calendar_today, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  /// Builds the time picker with formatted display
  Widget _buildTimePicker(ThemeData theme) {
    return InkWell(
      onTap: () async {
        if (_isLoading) return; // Prevent selection during loading

        final time = await showTimePicker(
          context: context,
          initialTime: _selectedTime,
          builder: (context, child) {
            return Theme(
              data: theme.copyWith(
                timePickerTheme: theme.timePickerTheme.copyWith(
                  dayPeriodBorderSide:
                      const BorderSide(color: Colors.transparent),
                ),
              ),
              child: child!,
            );
          },
        );
        if (time != null && mounted) {
          setState(() {
            _selectedTime = time;
          });
          _loadData();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedTime.format(context),
              style: theme.textTheme.bodyLarge,
            ),
            Icon(Icons.access_time, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  /// Builds the error state widget
  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: theme.colorScheme.error.withOpacity(0.8),
            ),
            const SizedBox(height: 24),
            Text(
              'Error Loading Resources',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage.isNotEmpty
                  ? _errorMessage
                  : 'An unexpected error occurred. Please try again.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the resource list (available or unavailable)
  Widget _buildResourceList(bool showAvailable) {
    if (_selectedResourceType == 'Equipment') {
      return _buildEquipmentList(showAvailable);
    } else {
      return _buildOtherResourcesList(showAvailable);
    }
  }

  /// Builds the equipment list (available or unavailable)
  Widget _buildEquipmentList(bool showAvailable) {
    final equipmentList =
        showAvailable ? _availableEquipment : _unavailableEquipment;

    // Filter equipment based on search query
    final filteredEquipment = equipmentList.where((equipment) {
      return equipment.name.toLowerCase().contains(_searchQuery);
    }).toList();

    // Show empty state if no equipment found
    if (filteredEquipment.isEmpty) {
      return _buildEmptyState(showAvailable);
    }

    // Build equipment list
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredEquipment.length,
      itemBuilder: (context, index) {
        final equipment = filteredEquipment[index];
        return _buildEquipmentCard(equipment, showAvailable);
      },
    );
  }

  /// Builds a card for displaying equipment
  Widget _buildEquipmentCard(Equipment equipment, bool isAvailable) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isAvailable
              ? Colors.green.withOpacity(0.5)
              : Colors.red.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: isAvailable
              ? Colors.green.withOpacity(0.2)
              : Colors.red.withOpacity(0.2),
          child: Icon(
            Icons.medical_services,
            color: isAvailable ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          equipment.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Category: ${equipment.category}',
          style: theme.textTheme.bodyMedium,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isAvailable ? Colors.green.shade100 : Colors.red.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            isAvailable ? 'Available' : 'Unavailable',
            style: TextStyle(
              color: isAvailable ? Colors.green.shade800 : Colors.red.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the other resources list (rooms, doctors, etc.)
  Widget _buildOtherResourcesList(bool showAvailable) {
    final resourcesList =
        showAvailable ? _availableResources : _unavailableResources;

    // Filter resources based on search query
    final filteredResources = resourcesList.where((resource) {
      final data = resource.data() as Map<String, dynamic>?;
      if (data == null) return false;

      final name = data['name']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery);
    }).toList();

    // Show empty state if no resources found
    if (filteredResources.isEmpty) {
      return _buildEmptyState(showAvailable);
    }

    // Build resource list
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredResources.length,
      itemBuilder: (context, index) {
        final resource = filteredResources[index];
        final data = resource.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();

        return _buildResourceCard(resource.id, data, showAvailable);
      },
    );
  }

  /// Builds a card for displaying resource details
  Widget _buildResourceCard(
      String resourceId, Map<String, dynamic> data, bool isAvailable) {
    final theme = Theme.of(context);
    final name = data['name'] ?? 'Unknown';

    // Get subtitle text based on resource type
    String subtitleText = '';
    if (_selectedResourceType == 'Rooms') {
      subtitleText = data['type'] ?? 'Operating Room';
    } else if (_selectedResourceType == 'Doctors') {
      subtitleText = data['specialization'] ?? 'Medical Doctor';
    } else if (_selectedResourceType == 'Nurses') {
      subtitleText = data['department'] ?? 'Surgery Department';
    } else if (_selectedResourceType == 'Technologists') {
      subtitleText = data['specialty'] ?? 'Medical Technologist';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isAvailable
              ? Colors.green.withOpacity(0.5)
              : Colors.red.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: isAvailable
              ? Colors.green.withOpacity(0.2)
              : Colors.red.withOpacity(0.2),
          child: Icon(
            _getResourceIcon(),
            color: isAvailable ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitleText,
          style: theme.textTheme.bodyMedium,
        ),
        trailing: widget.isStandalone
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      isAvailable ? Colors.green.shade100 : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  isAvailable ? 'Available' : 'Unavailable',
                  style: TextStyle(
                    color: isAvailable
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: theme.colorScheme.primary,
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

  /// Builds the empty state widget
  Widget _buildEmptyState(bool isAvailable) {
    final theme = Theme.of(context);
    final statusText = isAvailable ? 'available' : 'unavailable';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEmptyStateIcon(),
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'No $statusText ${_selectedResourceType.toLowerCase()}',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              isAvailable
                  ? 'Try selecting a different time or date to find available ${_selectedResourceType.toLowerCase()}'
                  : 'All ${_selectedResourceType.toLowerCase()} are available at the selected time',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Your search for "$_searchQuery" may be filtering out results',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
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
      case 'Equipment':
        return Icons.medical_services;
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
      case 'Equipment':
        return Icons.medical_services_outlined;
      default:
        return Icons.search_off_outlined;
    }
  }
}

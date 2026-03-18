// =============================================================================
// Equipment Selection Widget
// =============================================================================
// A reusable widget for selecting medical equipment with search and filtering.
// Features:
// - Searchable equipment list
// - Category-based filtering
// - Availability indicators
// - Visual distinction between selected/unselected items
// - "Required" vs "Optional" equipment tagging
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_orscheduler/features/equipment/models/equipment.dart';
import 'package:firebase_orscheduler/features/equipment/repositories/equipment_repository.dart';

/// A widget that allows selection of equipment items with search and filtering
class EquipmentSelection extends StatefulWidget {
  /// Set of initially selected equipment IDs
  final Set<String> selectedEquipmentIds;

  /// Callback when equipment selection changes
  final Function(Set<String>, Map<String, bool>) onSelectionChanged;

  /// Map of equipment IDs to their required status (true = required, false = optional)
  final Map<String, bool> requiredEquipment;

  /// Optional filter to only show equipment from specific categories
  final List<String>? categoryFilter;

  /// Whether to show the availability filter
  final bool showAvailabilityFilter;

  /// Constructor for the equipment selection widget
  const EquipmentSelection({
    super.key,
    required this.selectedEquipmentIds,
    required this.requiredEquipment,
    required this.onSelectionChanged,
    this.categoryFilter,
    this.showAvailabilityFilter = false,
  });

  @override
  State<EquipmentSelection> createState() => _EquipmentSelectionState();
}

class _EquipmentSelectionState extends State<EquipmentSelection>
    with SingleTickerProviderStateMixin {
  // Repository for fetching equipment data
  final _equipmentRepository = EquipmentRepository();

  // List of all equipment
  List<Equipment> _allEquipment = [];

  // Filtered list of equipment based on search and filters
  List<Equipment> _filteredEquipment = [];

  // Set of currently selected equipment IDs
  late Set<String> _selectedIds;

  // Map of equipment IDs to their required status
  late Map<String, bool> _requiredEquipment;

  // Search controller
  final TextEditingController _searchController = TextEditingController();

  // Currently selected category filter
  String? _selectedCategory;

  // Availability filter value
  bool? _availabilityFilter;

  // Animation controller for selection state changes
  late AnimationController _animationController;

  // Categories derived from all equipment
  List<String> _categories = [];

  // Loading states
  bool _isLoading = true;
  bool _isFiltering = false;

  // Debounce timer for search
  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Initialize selection state
    _selectedIds = Set<String>.from(widget.selectedEquipmentIds);
    _requiredEquipment = Map<String, bool>.from(widget.requiredEquipment);

    // Load equipment data
    _loadEquipment();

    // Set up debounced search listener
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Debounce search text changes
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _filterEquipment();
    });
  }

  /// Load equipment from repository
  Future<void> _loadEquipment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final equipment = await _equipmentRepository.getAllEquipment();

      if (!mounted) return;

      setState(() {
        _allEquipment = equipment;
        _extractCategories();
        _filterEquipment(setLoading: false);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load equipment: $e')),
      );
    }
  }

  /// Refresh equipment data
  Future<void> _refreshEquipment() async {
    // Clear the cache to force a refresh from the database
    _equipmentRepository.clearCache();
    return _loadEquipment();
  }

  /// Extract unique categories from equipment data
  void _extractCategories() {
    final categorySet = <String>{};
    for (final equipment in _allEquipment) {
      categorySet.add(equipment.category);
    }
    _categories = categorySet.toList()..sort();
  }

  /// Filter equipment based on search text, category and availability
  void _filterEquipment({bool setLoading = true}) {
    final searchText = _searchController.text.toLowerCase();

    if (setLoading) {
      setState(() {
        _isFiltering = true;
      });
    }

    // Use a microtask to allow the UI to update with the loading state
    // before performing the potentially expensive filtering operation
    Future.microtask(() {
      final filteredList = _allEquipment.where((equipment) {
        // Apply search filter
        final matchesSearch = searchText.isEmpty ||
            equipment.name.toLowerCase().contains(searchText);

        // Apply category filter
        final matchesCategory = _selectedCategory == null ||
            equipment.category == _selectedCategory;

        // Apply availability filter if enabled
        final matchesAvailability = _availabilityFilter == null ||
            equipment.isAvailable == _availabilityFilter;

        // Apply widget's category filter if provided
        final matchesWidgetCategoryFilter = widget.categoryFilter == null ||
            widget.categoryFilter!.contains(equipment.category);

        return matchesSearch &&
            matchesCategory &&
            matchesAvailability &&
            matchesWidgetCategoryFilter;
      }).toList();

      // Sort by name
      filteredList.sort((a, b) => a.name.compareTo(b.name));

      if (mounted) {
        setState(() {
          _filteredEquipment = filteredList;
          _isFiltering = false;
        });
      }
    });
  }

  /// Toggle selection of an equipment item
  void _toggleSelection(String equipmentId) {
    setState(() {
      if (_selectedIds.contains(equipmentId)) {
        _selectedIds.remove(equipmentId);
        _requiredEquipment.remove(equipmentId);
      } else {
        _selectedIds.add(equipmentId);
        // Default to optional when newly selected
        _requiredEquipment[equipmentId] = false;
      }

      // Notify parent of selection change
      widget.onSelectionChanged(
        _selectedIds,
        _requiredEquipment,
      );
    });

    // Play animation
    _animationController.reset();
    _animationController.forward();
  }

  /// Toggle required status of an equipment item
  void _toggleRequired(String equipmentId) {
    if (!_selectedIds.contains(equipmentId)) return;

    setState(() {
      _requiredEquipment[equipmentId] =
          !(_requiredEquipment[equipmentId] ?? false);

      // Notify parent of selection change
      widget.onSelectionChanged(
        _selectedIds,
        _requiredEquipment,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar with loading indicator
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search equipment...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _isFiltering
                ? Container(
                    width: 24,
                    height: 24,
                    padding: const EdgeInsets.all(6),
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),

        const SizedBox(height: 16),

        // Filter controls
        Row(
          children: [
            // Category filter
            Expanded(
              child: DropdownButtonFormField<String?>(
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                value: _selectedCategory,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All Categories'),
                  ),
                  ..._categories.map((category) => DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                    _filterEquipment();
                  });
                },
              ),
            ),

            if (widget.showAvailabilityFilter) ...[
              const SizedBox(width: 16),

              // Availability filter
              Expanded(
                child: DropdownButtonFormField<bool?>(
                  decoration: InputDecoration(
                    labelText: 'Availability',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  value: _availabilityFilter,
                  items: const [
                    DropdownMenuItem<bool?>(
                      value: null,
                      child: Text('All'),
                    ),
                    DropdownMenuItem<bool>(
                      value: true,
                      child: Text('Available'),
                    ),
                    DropdownMenuItem<bool>(
                      value: false,
                      child: Text('Unavailable'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _availabilityFilter = value;
                      _filterEquipment();
                    });
                  },
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 16),

        // Selected count and refresh button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Selected: ${_selectedIds.length} items',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh equipment list',
              onPressed: _refreshEquipment,
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Equipment list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _refreshEquipment,
                  child: _filteredEquipment.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.medical_services_outlined,
                                    size: 64,
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No equipment found',
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try adjusting your filters or search terms',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _filteredEquipment.length,
                          itemBuilder: (context, index) {
                            final equipment = _filteredEquipment[index];
                            final isSelected =
                                _selectedIds.contains(equipment.id);
                            final isRequired =
                                _requiredEquipment[equipment.id] ?? false;

                            return AnimatedBuilder(
                              animation: _animationController,
                              builder: (context, child) {
                                return Card(
                                  elevation: isSelected ? 2 : 0,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  color: isSelected
                                      ? theme.colorScheme.primaryContainer
                                          .withOpacity(
                                          isSelected &&
                                                  _animationController
                                                      .isAnimating
                                              ? _animationController.value
                                              : 1.0,
                                        )
                                      : theme.colorScheme.surface,
                                  child: child,
                                );
                              },
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                title: Text(
                                  equipment.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'Category: ${equipment.category}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          equipment.isAvailable
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          size: 16,
                                          color: equipment.isAvailable
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          equipment.isAvailable
                                              ? 'Available'
                                              : 'Unavailable',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: equipment.isAvailable
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: isSelected
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Required/Optional toggle
                                          FilterChip(
                                            label: Text(
                                              isRequired
                                                  ? 'Required'
                                                  : 'Optional',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isRequired
                                                    ? theme.colorScheme
                                                        .onSecondaryContainer
                                                    : theme
                                                        .colorScheme.onSurface,
                                              ),
                                            ),
                                            selected: isRequired,
                                            onSelected: (_) =>
                                                _toggleRequired(equipment.id),
                                            backgroundColor:
                                                theme.colorScheme.surface,
                                            selectedColor: theme
                                                .colorScheme.secondaryContainer,
                                            checkmarkColor:
                                                theme.colorScheme.secondary,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.check_circle,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ],
                                      )
                                    : null,
                                onTap: () => _toggleSelection(equipment.id),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

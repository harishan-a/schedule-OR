// =============================================================================
// Equipment Catalog Screen
// =============================================================================
// A full interface for browsing and viewing equipment specifications
// Features:
// - Grid/list view of all equipment
// - Detailed information display
// - Category filtering
// - Integration with equipment repository
// - Caching for improved performance
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_orscheduler/features/equipment/models/equipment.dart';
import 'package:firebase_orscheduler/features/equipment/repositories/equipment_repository.dart';

/// Screen for browsing and viewing detailed equipment information
class EquipmentCatalogScreen extends StatefulWidget {
  const EquipmentCatalogScreen({super.key});

  @override
  State<EquipmentCatalogScreen> createState() => _EquipmentCatalogScreenState();
}

class _EquipmentCatalogScreenState extends State<EquipmentCatalogScreen>
    with TickerProviderStateMixin {
  // Repository for equipment data
  final _equipmentRepository = EquipmentRepository();

  // Currently selected equipment for detail view
  Equipment? _selectedEquipment;

  // All equipment items
  List<Equipment> _allEquipment = [];

  // Filtered equipment based on search and category
  List<Equipment> _filteredEquipment = [];

  // Search controller
  final _searchController = TextEditingController();

  // Category filter
  String? _selectedCategory;

  // List of unique categories
  List<String> _categories = [];

  // Whether to use grid view (true) or list view (false)
  bool _isGridView = true;

  // Loading state
  bool _isLoading = true;
  bool _isFiltering = false;

  // Debounce timer for search
  Timer? _debounce;

  // Animation controllers
  late AnimationController _listGridToggleController;
  late AnimationController _detailSlideController;

  // Tab controller for the detail view
  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _listGridToggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _detailSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Initialize tab controller for detail view
    _tabController = TabController(length: 2, vsync: this);

    // Set up debounced search listener
    _searchController.addListener(_onSearchChanged);

    // Load equipment data
    _loadEquipment();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listGridToggleController.dispose();
    _detailSlideController.dispose();
    _tabController.dispose();
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

  /// Load equipment data from repository with caching
  Future<void> _loadEquipment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use the repository's caching mechanism
      final equipment = await _equipmentRepository.getAllEquipment();

      if (!mounted) return;

      setState(() {
        _allEquipment = equipment;
        _filteredEquipment = List.from(_allEquipment);
        _extractCategories();
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

  /// Extract unique categories from equipment data
  void _extractCategories() {
    final categorySet = <String>{};
    for (final equipment in _allEquipment) {
      categorySet.add(equipment.category);
    }
    _categories = categorySet.toList()..sort();
  }

  /// Filter equipment based on search text and category
  void _filterEquipment() {
    final searchText = _searchController.text.toLowerCase();

    setState(() {
      _isFiltering = true;
    });

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

        return matchesSearch && matchesCategory;
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

  /// Show detail view for the selected equipment
  void _showEquipmentDetail(Equipment equipment) {
    setState(() {
      _selectedEquipment = equipment;
    });

    // Animate detail panel in
    _detailSlideController.forward();
  }

  /// Close the equipment detail view
  void _closeEquipmentDetail() {
    // Animate detail panel out
    _detailSlideController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _selectedEquipment = null;
        });
      }
    });
  }

  /// Toggle between grid and list view
  void _toggleViewMode() {
    setState(() {
      _isGridView = !_isGridView;
    });

    if (_isGridView) {
      _listGridToggleController.forward();
    } else {
      _listGridToggleController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    // Calculate responsive grid column count based on screen width
    final gridColumnCount = mediaQuery.size.width < 600
        ? 2
        : mediaQuery.size.width < 900
            ? 3
            : 4;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipment Catalog'),
        actions: [
          // View toggle button
          IconButton(
            icon: AnimatedIcon(
              icon: AnimatedIcons.list_view,
              progress: _listGridToggleController,
            ),
            onPressed: _toggleViewMode,
            tooltip: _isGridView ? 'Show as list' : 'Show as grid',
          ),

          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEquipment,
            tooltip: 'Refresh equipment data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                // Clear the cache and reload equipment data
                _equipmentRepository.clearCache();
                return _loadEquipment();
              },
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Search and filter section
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Search field
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
                                        child: const CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Category filter chips
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: const Text('All'),
                                      selected: _selectedCategory == null,
                                      onSelected: (_) {
                                        setState(() {
                                          _selectedCategory = null;
                                          _filterEquipment();
                                        });
                                      },
                                    ),
                                  ),
                                  ..._categories.map(
                                    (category) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: FilterChip(
                                        label: Text(category),
                                        selected: _selectedCategory == category,
                                        onSelected: (_) {
                                          setState(() {
                                            _selectedCategory =
                                                _selectedCategory == category
                                                    ? null
                                                    : category;
                                            _filterEquipment();
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Results count
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              'Showing ${_filteredEquipment.length} of ${_allEquipment.length} items',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Equipment list/grid
                      Expanded(
                        child: _filteredEquipment.isEmpty
                            ? Center(
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
                                      style:
                                          theme.textTheme.bodyLarge?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.6),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: _isGridView
                                    ? _buildEquipmentGrid(gridColumnCount)
                                    : _buildEquipmentList(),
                              ),
                      ),
                    ],
                  ),

                  // Detail view overlay
                  if (_selectedEquipment != null)
                    AnimatedBuilder(
                      animation: _detailSlideController,
                      builder: (context, child) {
                        final slideValue = Tween<Offset>(
                          begin: const Offset(1, 0),
                          end: Offset.zero,
                        ).evaluate(_detailSlideController);

                        return SlideTransition(
                          position: AlwaysStoppedAnimation(slideValue),
                          child: child,
                        );
                      },
                      child: _buildDetailView(context),
                    ),
                ],
              ),
            ),
    );
  }

  /// Builds the equipment grid view
  Widget _buildEquipmentGrid(int columnCount) {
    return GridView.builder(
      key: const ValueKey('equipment_grid'),
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnCount,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredEquipment.length,
      itemBuilder: (context, index) {
        final equipment = _filteredEquipment[index];

        return Card(
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          child: InkWell(
            onTap: () => _showEquipmentDetail(equipment),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Equipment image/placeholder
                Hero(
                  tag: 'equipment_${equipment.id}',
                  child: Container(
                    height: 120,
                    color: equipment.isAvailable
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    child: Center(
                      child: Icon(
                        Icons.medical_services,
                        size: 48,
                        color:
                            equipment.isAvailable ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Equipment name
                        Text(
                          equipment.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),

                        // Category
                        Text(
                          equipment.category,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),

                        const Spacer(),

                        // Availability indicator
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
                              style: TextStyle(
                                fontSize: 14,
                                color: equipment.isAvailable
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds the equipment list view
  Widget _buildEquipmentList() {
    return ListView.separated(
      key: const ValueKey('equipment_list'),
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _filteredEquipment.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final equipment = _filteredEquipment[index];

        return Card(
          elevation: 1,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Hero(
              tag: 'equipment_${equipment.id}',
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: equipment.isAvailable
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    Icons.medical_services,
                    color: equipment.isAvailable ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ),
            title: Text(
              equipment.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Category: ${equipment.category}'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      equipment.isAvailable ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: equipment.isAvailable ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      equipment.isAvailable ? 'Available' : 'Unavailable',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            equipment.isAvailable ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showEquipmentDetail(equipment),
          ),
        );
      },
    );
  }

  /// Builds the equipment detail view
  Widget _buildDetailView(BuildContext context) {
    final theme = Theme.of(context);
    final equipment = _selectedEquipment!;

    // Extract specifications for display
    final specs = equipment.specifications.entries.toList();

    return Container(
      color: theme.scaffoldBackgroundColor,
      width: double.infinity,
      height: double.infinity,
      child: Column(
        children: [
          // Detail view app bar
          AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _closeEquipmentDetail,
            ),
            title: Text(equipment.name),
            actions: [
              IconButton(
                icon: Icon(
                  equipment.isAvailable ? Icons.check_circle : Icons.cancel,
                  color: equipment.isAvailable ? Colors.green : Colors.red,
                ),
                onPressed: null,
                tooltip: equipment.isAvailable ? 'Available' : 'Unavailable',
              ),
            ],
          ),

          // Equipment detail content
          Expanded(
            child: Column(
              children: [
                // Equipment header section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: theme.colorScheme.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Equipment icon
                      Hero(
                        tag: 'equipment_${equipment.id}',
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: equipment.isAvailable
                                ? Colors.green.withOpacity(0.2)
                                : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.medical_services,
                              size: 40,
                              color: equipment.isAvailable
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Equipment name and category
                      Text(
                        equipment.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 8),

                      Text(
                        equipment.category,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Availability chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: equipment.isAvailable
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
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
                            const SizedBox(width: 8),
                            Text(
                              equipment.isAvailable
                                  ? 'Available'
                                  : 'Unavailable',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: equipment.isAvailable
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab bar
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Specifications'),
                    Tab(text: 'Location'),
                  ],
                ),

                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Specifications tab
                      specs.isEmpty
                          ? Center(
                              child: Text(
                                'No specifications available',
                                style: theme.textTheme.bodyLarge,
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: specs.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, index) {
                                final spec = specs[index];
                                return ListTile(
                                  title: Text(
                                    spec.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    spec.value.toString(),
                                  ),
                                );
                              },
                            ),

                      // Location tab
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Location section
                            Text(
                              'Location Details',
                              style: theme.textTheme.titleLarge,
                            ),

                            const SizedBox(height: 16),

                            Card(
                              elevation: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Current Location',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Location ID: ${equipment.locationId}',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

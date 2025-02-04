/// A screen that displays a filterable list of surgeries with real-time updates.
/// 
/// This screen provides:
/// - Real-time surgery data streaming from Firestore
/// - Multi-criteria filtering (date range, status, search text)
/// - Modern Material Design 3 UI with cards and chips
/// - Error handling for network and data issues
/// - Search functionality across patient names and surgery types
/// 
/// The filtering logic is implemented at the UI level to maintain flexibility,
/// though this means some logic is duplicated between widgets.
/// Note: Filtering logic duplication is maintained in this phase for stability.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../features/home/services/home_service.dart';
import './surgery_details.dart';
import 'package:firebase_orscheduler/shared/widgets/custom_navigation_bar.dart';

class SurgeryLogScreen extends StatefulWidget {
  const SurgeryLogScreen({super.key});

  @override
  State<SurgeryLogScreen> createState() => _SurgeryLogScreenState();
}

class _SurgeryLogScreenState extends State<SurgeryLogScreen> {
  // Service for fetching surgery data
  final HomeService _homeService = HomeService();
  
  // Controllers and state variables for filtering
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedStatus = 'All';
  String _searchQuery = '';
  bool _isLoading = false;

  // Available status options for filtering
  final List<String> _statusFilters = [
    'All',
    'Scheduled',
    'In Progress',
    'Completed',
    'Cancelled',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Returns a color based on the surgery status for visual indication
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'in progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Surgery Log'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(
            child: _buildSurgeryList(),
          ),
        ],
      ),
      bottomNavigationBar: CustomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          // Handle navigation
        },
      ),
    );
  }

  /// Builds a search bar that filters surgeries by patient name or surgery type
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search surgeries...',
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
    );
  }

  /// Builds a row of filter chips for quick status and date filtering
  /// Note: This widget contains filtering logic that is duplicated in _buildSurgeryList
  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          // Date range filter chip
          if (_startDate != null || _endDate != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(
                  'Date: ${_formatDateRange()}',
                ),
                onSelected: (_) => _showFilterDialog(),
                selected: true,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          // Status filter chips
          ..._statusFilters.map((status) {
            final isSelected = _selectedStatus == status;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(status),
                selected: isSelected,
                onSelected: (bool selected) {
                  setState(() {
                    _selectedStatus = selected ? status : 'All';
                  });
                },
                backgroundColor: isSelected
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                    : null,
                labelStyle: TextStyle(
                  color: isSelected ? Theme.of(context).colorScheme.primary : null,
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// Builds the main surgery list with real-time updates and filtering
  /// Contains the core filtering logic for the screen
  Widget _buildSurgeryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _homeService.getSurgeriesStream(),
      builder: (context, snapshot) {
        // Error handling for stream errors
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Retry stream connection
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Loading state
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filter surgeries based on search, status, and date range
        final allSurgeries = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final surgeryDate = (data['startTime'] as Timestamp).toDate();
          final patientName = (data['patientName'] ?? '').toString().toLowerCase();
          final surgeryType = (data['surgeryType'] ?? '').toString().toLowerCase();
          final status = data['status'] ?? '';

          // Text search matching
          bool matchesSearch = patientName.contains(_searchQuery) ||
              surgeryType.contains(_searchQuery);
          
          // Status filtering
          bool matchesStatus =
              _selectedStatus == 'All' || status == _selectedStatus;
          
          // Date range filtering
          bool matchesDateRange = true;
          if (_startDate != null) {
            matchesDateRange = surgeryDate.isAfter(_startDate!);
          }
          if (_endDate != null) {
            matchesDateRange =
                matchesDateRange && surgeryDate.isBefore(_endDate!.add(const Duration(days: 1)));
          }

          return matchesSearch && matchesStatus && matchesDateRange;
        }).toList();

        // Empty state handling
        if (allSurgeries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No surgeries found',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try adjusting your filters',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          );
        }

        // Build the filtered surgery list
        return ListView.builder(
          itemCount: allSurgeries.length,
          itemBuilder: (context, index) {
            final surgery = allSurgeries[index].data() as Map<String, dynamic>;
            final surgeryDate = (surgery['startTime'] as Timestamp).toDate();
            final surgeryEndTime = (surgery['endTime'] as Timestamp).toDate();

            return Card(
              margin: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _getStatusColor(surgery['status']).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SurgeryDetailsScreen(
                        surgeryId: allSurgeries[index].id,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  surgery['patientName'] ?? 'Unknown Patient',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  surgery['surgeryType'] ?? 'Unknown Surgery',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(surgery['status'])
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              surgery['status'] ?? 'Unknown',
                              style: TextStyle(
                                color: _getStatusColor(surgery['status']),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMM d, y').format(surgeryDate),
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${DateFormat('h:mm a').format(surgeryDate)} - ${DateFormat('h:mm a').format(surgeryEndTime)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Shows a dialog for advanced filtering options
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Filter Surgeries'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDateRangePicker(setState),
                const SizedBox(height: 16),
                _buildStatusDropdown(setState),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                    _selectedStatus = 'All';
                  });
                },
                child: const Text('Clear'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  this.setState(() {});
                  Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Builds the date range picker section of the filter dialog
  Widget _buildDateRangePicker(StateSetter setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Date Range'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2025),
                  );
                  if (date != null) {
                    setState(() {
                      _startDate = date;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Start Date',
                  ),
                  child: Text(
                    _startDate != null
                        ? DateFormat('MMM d, y').format(_startDate!)
                        : 'Select',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2025),
                  );
                  if (date != null) {
                    setState(() {
                      _endDate = date;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'End Date',
                  ),
                  child: Text(
                    _endDate != null
                        ? DateFormat('MMM d, y').format(_endDate!)
                        : 'Select',
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the status dropdown section of the filter dialog
  Widget _buildStatusDropdown(StateSetter setState) {
    return DropdownButtonFormField<String>(
      value: _selectedStatus,
      decoration: const InputDecoration(
        labelText: 'Status',
      ),
      items: _statusFilters.map((String status) {
        return DropdownMenuItem<String>(
          value: status,
          child: Text(status),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedStatus = newValue;
          });
        }
      },
    );
  }

  /// Formats the date range for display in the filter chip
  String _formatDateRange() {
    if (_startDate != null && _endDate != null) {
      return '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_endDate!)}';
    } else if (_startDate != null) {
      return 'From ${DateFormat('MMM d').format(_startDate!)}';
    } else if (_endDate != null) {
      return 'Until ${DateFormat('MMM d').format(_endDate!)}';
    }
    return '';
  }
} 
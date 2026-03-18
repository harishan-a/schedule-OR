// =============================================================================
// Staff Directory Filter Screen
// =============================================================================
// This screen manages filter options for the staff directory, including:
// - Role-based filtering (Doctor, Nurse, etc.)
// - Department-based filtering (Emergency, Surgery, etc.)
// - Modern UI with clear filter options
// - Proper state management
// - Responsive design
// =============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// FilterScreen manages and displays filter options for staff directory
class FilterScreen extends StatefulWidget {
  final String? selectedRole;
  final String? selectedDepartment;
  final Function(String?, String?) onApplyFilters;

  const FilterScreen({
    super.key,
    this.selectedRole,
    this.selectedDepartment,
    required this.onApplyFilters,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  // Filter state variables
  late String? _selectedRole;
  late String? _selectedDepartment;

  // Lists to store available roles and departments from Firestore
  List<String> _roles = [];
  List<String> _departments = [];

  // Loading state
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize filters with passed values
    _selectedRole = widget.selectedRole;
    _selectedDepartment = widget.selectedDepartment;

    // Load available roles and departments from Firestore
    _fetchFilterOptions();
  }

  /// Fetch unique roles and departments from Firestore users collection
  Future<void> _fetchFilterOptions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Query Firestore for all users
      final QuerySnapshot usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      // Extract unique roles and departments
      final Set<String> uniqueRoles = {};
      final Set<String> uniqueDepartments = {};

      for (final doc in usersSnapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>? ?? {};

        final String? role = userData['role']?.toString();
        final String? department = userData['department']?.toString();

        if (role != null && role.isNotEmpty) {
          uniqueRoles.add(role);
        }

        if (department != null && department.isNotEmpty) {
          uniqueDepartments.add(department);
        }
      }

      setState(() {
        _roles = uniqueRoles.toList()..sort();
        _departments = uniqueDepartments.toList()..sort();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        // Fallback to default options if query fails
        _roles = ['Doctor', 'Nurse', 'Technician', 'Administrator'];
        _departments = ['Emergency', 'Surgery', 'Pediatrics', 'Cardiology'];
        _isLoading = false;
      });
    }
  }

  /// Builds a filter section with title and radio options
  Widget _buildFilterSection({
    required String title,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Empty state for no options
        if (options.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'No options available',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ),

        // Filter options list
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            return RadioListTile<String>(
              title: Text(
                option,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              value: option,
              groupValue: selectedValue,
              onChanged: onChanged,
              activeColor: Theme.of(context).colorScheme.primary,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              dense: true,
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Filter Staff',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: isDark ? colorScheme.surfaceVariant : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Clear all filters button
          TextButton(
            onPressed: () {
              setState(() {
                _selectedRole = null;
                _selectedDepartment = null;
              });
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text('Loading filter options...'),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Role filter section
                  _buildFilterSection(
                    title: 'Role',
                    options: _roles,
                    selectedValue: _selectedRole,
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value;
                      });
                    },
                  ),
                  const Divider(height: 1),
                  // Department filter section
                  _buildFilterSection(
                    title: 'Department',
                    options: _departments,
                    selectedValue: _selectedDepartment,
                    onChanged: (value) {
                      setState(() {
                        _selectedDepartment = value;
                      });
                    },
                  ),
                ],
              ),
            ),
      // Apply filters button
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              widget.onApplyFilters(_selectedRole, _selectedDepartment);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Apply Filters',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

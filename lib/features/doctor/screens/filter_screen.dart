// =============================================================================
// Staff Directory Filter Screen
// =============================================================================
// This screen manages filter options for the staff directory, including:
// - Role-based filtering (Doctor, Nurse, etc.)
// - Department-based filtering (Emergency, Surgery, etc.)
// - Filter state management
// - Filter UI components
// - Filter application callbacks
// 
// IMPORTANT: The filter options are hardcoded and must remain unchanged to
// maintain consistency with the rest of the application.
// =============================================================================

import 'package:flutter/material.dart';

/// FilterScreen manages and displays filter options for staff directory
/// Parameters:
/// - selectedRole: Currently active role filter
/// - selectedDepartment: Currently active department filter
/// - onApplyFilters: Callback when filters are applied
class FilterScreen extends StatefulWidget {
  final String? selectedRole;
  final String? selectedDepartment;
  final Function(String?, String?) onApplyFilters;

  const FilterScreen({
    Key? key,
    this.selectedRole,
    this.selectedDepartment,
    required this.onApplyFilters,
  }) : super(key: key);

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  // Filter state variables
  late String? _selectedRole;         // Currently selected role
  late String? _selectedDepartment;   // Currently selected department

  // IMPORTANT: Hardcoded filter options - must match backend expectations
  final List<String> _roles = [
    'Doctor',
    'Nurse',
    'Receptionist',
    'Administrator',
    'Technician',
  ];

  final List<String> _departments = [
    'Emergency',
    'Surgery',
    'Pediatrics',
    'Cardiology',
    'Neurology',
    'Oncology',
    'Orthopedics',
    'Radiology',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize filters with passed values
    _selectedRole = widget.selectedRole;
    _selectedDepartment = widget.selectedDepartment;
  }

  /// Builds a filter section with title and radio options
  /// Parameters:
  /// - title: Section header text
  /// - options: Available filter choices
  /// - selectedValue: Currently selected option
  /// - onChanged: Selection change callback
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
              activeColor: Theme.of(context).primaryColor,
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
        backgroundColor: isDark ? theme.primaryColor.withOpacity(0.1) : Colors.white,
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
      body: SingleChildScrollView(
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


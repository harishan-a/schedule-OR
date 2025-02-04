// =============================================================================
// Doctor/Staff Details Page
// =============================================================================
// This screen displays detailed information about a specific staff member:
// - Personal information (name, role, department)
// - Contact details
// - Professional background
// - Responsive layout with grid system
// - Theme-aware UI components
// - Navigation integration
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'staff_details.dart';
import 'package:firebase_orscheduler/shared/widgets/custom_navigation_bar.dart';

/// DoctorPage widget displays detailed information about a specific staff member
class DoctorPage extends StatefulWidget {
  const DoctorPage({super.key});

  @override
  State<DoctorPage> createState() => _DoctorPageState();
}

class _DoctorPageState extends State<DoctorPage> {
  // Navigation and UI state
  int _selectedIndex = 0;  // Current navigation index
  bool _isFilterExpanded = false;  // Controls filter sidebar visibility
  
  // Filter state
  String? _selectedRole;  // Selected role filter
  String? _selectedDepartment;  // Selected department filter
  
  // IMPORTANT: Direct Firestore query - must remain unchanged
  final Stream<QuerySnapshot> _usersStream = FirebaseFirestore.instance
      .collection('users')
      .snapshots();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              // Animated filter sidebar with expandable width
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _isFilterExpanded ? 250 : 0,
                child: Card(
                  margin: EdgeInsets.zero,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Filter header with close button
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Filters',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _isFilterExpanded = false;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        // Role filter options
                        _buildFilterSection(
                          'Role',
                          ['Doctor', 'Nurse', 'Technologist', 'Admin'],
                          _selectedRole,
                          (value) => setState(() => _selectedRole = value),
                          Icons.work,
                        ),
                        // Department filter options
                        _buildFilterSection(
                          'Department',
                          ['Cardiology', 'Neurology', 'Pediatrics', 'Orthopedics'],
                          _selectedDepartment,
                          (value) => setState(() => _selectedDepartment = value),
                          Icons.local_hospital,
                        ),
                        const SizedBox(height: 16),
                        // Clear filters button
                        if (_selectedRole != null || _selectedDepartment != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedRole = null;
                                  _selectedDepartment = null;
                                });
                              },
                              child: const Text('Clear Filters'),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
              // Main content area with staff data
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _usersStream,
                  builder: (context, snapshot) {
                    // Loading state
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    // Error state with retry option
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading data',
                              style: theme.textTheme.titleLarge,
                            ),
                            TextButton(
                              onPressed: () => setState(() {}),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    final filteredDocs = _filterUsers(snapshot.data!.docs);

                    // Empty state when no results match filters
                    if (filteredDocs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: theme.disabledColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No results found',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your filters',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      );
                    }

                    // Staff grid with responsive layout
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _calculateCrossAxisCount(context),
                        childAspectRatio: _calculateChildAspectRatio(context),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final user = filteredDocs[index];
                        return _buildStaffCard(user, theme);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      // Filter toggle button
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isFilterExpanded = !_isFilterExpanded;
          });
        },
        child: Icon(_isFilterExpanded ? Icons.filter_list_off : Icons.filter_list),
      ),
      // Bottom navigation
      bottomNavigationBar: CustomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  /// Calculates the aspect ratio for staff cards based on screen width
  /// Adjusts card dimensions for optimal display on different screen sizes
  double _calculateChildAspectRatio(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width < 600) return 2.5;  // Compact layout for mobile
    if (width < 900) return 2.3;  // Balanced layout for tablet
    return 2.1;  // Spacious layout for desktop
  }

  /// Calculates the number of grid columns based on available screen width
  /// Accounts for filter sidebar when expanded
  int _calculateCrossAxisCount(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (_isFilterExpanded) {
      width -= 250;  // Adjust for filter sidebar width
    }
    if (width < 600) return 1;  // Single column for mobile
    if (width < 900) return 2;  // Two columns for tablet
    if (width < 1200) return 3; // Three columns for desktop
    return 4;  // Four columns for large screens
  }

  /// Builds a filter section with title, icon, and radio options
  /// Parameters:
  /// - title: Section header text
  /// - items: List of filter options
  /// - selectedValue: Currently selected option
  /// - onChanged: Selection change callback
  /// - icon: Section icon
  Widget _buildFilterSection(
    String title,
    List<String> items,
    String? selectedValue,
    Function(String?) onChanged,
    IconData icon,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with icon
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // Filter options list
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              title: Text(
                item,
                style: const TextStyle(fontSize: 14),
              ),
              leading: Radio<String>(
                value: item,
                groupValue: selectedValue,
                onChanged: onChanged,
              ),
              onTap: () => onChanged(item == selectedValue ? null : item),
            );
          },
        ),
      ],
    );
  }

  /// Builds a staff member card with profile information and styling
  /// Parameters:
  /// - user: Firestore document with staff member data
  /// - theme: Current theme for styling consistency
  Widget _buildStaffCard(DocumentSnapshot user, ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => StaffDetailPage(
                user: user,
                selectedIndex: _selectedIndex
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isDarkMode ? Colors.grey[850]! : Colors.white,
                isDarkMode ? Colors.grey[900]! : const Color(0xFFF5F5F5),
              ],
            ),
          ),
          // Responsive layout builder for card contents
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Staff member header with avatar and name
                  SizedBox(
                    height: 36,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar with initials
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.primaryColor.withOpacity(0.1),
                          child: Text(
                            '${user['firstName']?[0] ?? ''}${user['lastName']?[0] ?? ''}'.toUpperCase(),
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Name and role
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                user['role']?.toString() ?? 'Role not specified',
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Department badge
                  if (user['department'] != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        user['department'].toString(),
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const Spacer(),
                  // View profile button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => StaffDetailPage(
                              user: user,
                              selectedIndex: _selectedIndex
                            ),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: theme.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View Profile',
                            style: TextStyle(
                              fontSize: 9,
                              color: theme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 1),
                          Icon(
                            Icons.arrow_forward,
                            size: 9,
                            color: theme.primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Filters the user list based on selected role and department
  /// Returns filtered list of staff members matching the criteria
  List<DocumentSnapshot> _filterUsers(List<DocumentSnapshot> userDocs) {
    return userDocs.where((user) {
      final role = (user['role'] ?? '').toString().toLowerCase();
      final department = (user['department'] ?? '').toString().toLowerCase();

      bool matchesDepartment = _selectedDepartment == null || 
                             department == _selectedDepartment!.toLowerCase();
      bool matchesRole = _selectedRole == null || 
                        role == _selectedRole!.toLowerCase();

      return matchesDepartment && matchesRole;
    }).toList();
  }
}

// =============================================================================
// Staff Directory Page
// =============================================================================
// A modern, responsive directory of medical staff with features:
// - Real-time staff listing from Firestore
// - Role and department filtering
// - Responsive grid layout
// - Staff detail view navigation
// - Proper profile image display
// - Modern card design
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_orscheduler/shared/widgets/user_avatar.dart';
import 'package:firebase_orscheduler/shared/providers/user_profile_provider.dart';

import 'staff_details.dart';
import 'package:firebase_orscheduler/shared/widgets/custom_navigation_bar.dart';
import 'filter_screen.dart';

/// StaffDirectoryPage displays a filterable directory of medical staff
class DoctorPage extends StatefulWidget {
  const DoctorPage({super.key});

  @override
  State<DoctorPage> createState() => _DoctorPageState();
}

class _DoctorPageState extends State<DoctorPage> {
  // Navigation state
  int _selectedIndex = 3; // Index 3 represents the staff section

  // Filter criteria state
  String? _selectedRole;
  String? _selectedDepartment;

  // Stream for real-time staff data
  final Stream<QuerySnapshot> _usersStream =
      FirebaseFirestore.instance.collection('users').snapshots();

  @override
  void initState() {
    super.initState();
    _selectedIndex = 3;
  }

  /// Handles navigation between main app sections
  void _handleNavigation(int index) {
    if (index == _selectedIndex) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        break;
      case 1:
        Navigator.pushNamedAndRemoveUntil(
            context, '/schedule', (route) => false);
        break;
      case 2:
        Navigator.pushNamedAndRemoveUntil(context, '/doctor', (route) => false);
        break;
      case 3:
        Navigator.pushNamedAndRemoveUntil(
            context, '/settings', (route) => false);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Staff Directory',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: isDark ? colorScheme.surfaceVariant : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Search coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _usersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading staff data',
                    style: theme.textTheme.titleLarge,
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final filteredDocs = _filterUsers(snapshot.data!.docs);

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
                    'No staff members found',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try adjusting your filters',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  if (_selectedRole != null || _selectedDepartment != null)
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedRole = null;
                          _selectedDepartment = null;
                        });
                      },
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear Filters'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filteredDocs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final user = filteredDocs[index];
              return _buildStaffCard(user, theme);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FilterScreen(
                selectedRole: _selectedRole,
                selectedDepartment: _selectedDepartment,
                onApplyFilters: (role, department) {
                  setState(() {
                    _selectedRole = role;
                    _selectedDepartment = department;
                  });
                },
              ),
            ),
          );
        },
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        tooltip: 'Filter staff',
        child: const Icon(Icons.filter_list_rounded),
      ),
      bottomNavigationBar: CustomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _handleNavigation,
      ),
    );
  }

  /// Builds a modern staff member card
  Widget _buildStaffCard(DocumentSnapshot user, ThemeData theme) {
    final Map<String, dynamic> userData = user.data() as Map<String, dynamic>;
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Extract user profile information
    final String firstName = userData['firstName'] ?? '';
    final String lastName = userData['lastName'] ?? '';
    final String fullName = '$firstName $lastName'.trim();
    final String role = userData['role'] ?? 'No role specified';
    final String department = userData['department'] ?? '';
    final String? profileImageUrl = userData['profileImageUrl'];
    final String? selectedAvatar = userData['selectedDefaultAvatar'];

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            isDark ? BorderSide.none : BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StaffDetailPage(
                user: user,
                selectedIndex: _selectedIndex,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Profile image with proper handling
              Hero(
                tag: 'staff_avatar_${user.id}',
                child: UserAvatar(
                  radius: 30,
                  name: fullName,
                  imageUrl: profileImageUrl,
                  assetPath: selectedAvatar,
                  backgroundColor: colorScheme.primaryContainer,
                  textColor: colorScheme.onPrimaryContainer,
                  showBorder: true,
                  borderColor: colorScheme.surface,
                  borderWidth: 2,
                ),
              ),
              const SizedBox(width: 16),

              // Staff details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Role
                    Text(
                      role,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    // Department chip if available
                    if (department.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          department,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // View profile arrow
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.primary.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Filters users based on selected role and department
  List<DocumentSnapshot> _filterUsers(List<DocumentSnapshot> userDocs) {
    return userDocs.where((user) {
      final userData = user.data() as Map<String, dynamic>? ?? {};

      final role = (userData['role'] ?? '').toString().toLowerCase();
      final department =
          (userData['department'] ?? '').toString().toLowerCase();

      final bool matchesDepartment = _selectedDepartment == null ||
          department == _selectedDepartment!.toLowerCase();
      final bool matchesRole =
          _selectedRole == null || role == _selectedRole!.toLowerCase();

      return matchesDepartment && matchesRole;
    }).toList();
  }
}

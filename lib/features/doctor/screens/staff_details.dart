// =============================================================================
// Staff Member Details Screen
// =============================================================================
// This screen displays comprehensive information about a staff member including:
// - Professional profile with role-based icon and animations
// - Contact information
// - Department and specialization details
// - Experience and background
// - Quick action buttons for messaging and scheduling
// 
// Features:
// - Hero animations for smooth transitions
// - Fade and slide animations for content
// - Responsive layout with custom cards
// - Theme-aware styling
// - Error handling for missing data
// =============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_orscheduler/shared/widgets/custom_navigation_bar.dart';

/// StaffDetailPage displays detailed information about a specific staff member
/// Parameters:
/// - user: Firestore document containing staff member data
/// - selectedIndex: Current navigation index for bottom bar
class StaffDetailPage extends StatefulWidget {
  final DocumentSnapshot user;  // IMPORTANT: Direct Firestore document reference
  final int selectedIndex;

  const StaffDetailPage({
    super.key, 
    required this.user,
    required this.selectedIndex,
  });

  @override
  State<StaffDetailPage> createState() => _StaffDetailPageState();
}

class _StaffDetailPageState extends State<StaffDetailPage> with SingleTickerProviderStateMixin {
  // Animation controllers and animations
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Navigation state
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
    
    // Initialize animations
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),  // Animation duration
      vsync: this,
    );

    // Fade-in animation for content
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    // Slide-up animation for content
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),  // Start slightly below final position
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();  // Start animations
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Safely retrieves a field value from the Firestore document
  /// Returns 'Not specified' if the field is missing or null
  String _getField(String field) {
    try {
      return widget.user[field]?.toString() ?? 'Not specified';
    } catch (e) {
      return 'Not specified';
    }
  }

  /// Handles navigation between main app sections
  /// Preserves state when navigating to the same page
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
        Navigator.pushNamedAndRemoveUntil(context, '/schedule', (route) => false);
        break;
      case 2:
        Navigator.pushNamedAndRemoveUntil(context, '/doctor', (route) => false);
        break;
      case 3:
        Navigator.pushNamedAndRemoveUntil(context, '/settings', (route) => false);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract staff member information
    final fullName = '${_getField('firstName')} ${_getField('lastName')}'.trim();
    final role = _getField('role');
    final department = _getField('department');
    final email = _getField('email');
    final phone = _getField('phoneNumber');
    final specialization = _getField('specialization');
    final experience = _getField('experience');
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(context, '/doctor', (route) => false);
          },
        ),
        title: Text(
          'Staff Details',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,  // Fixed size for consistency
          ),
        ),
        backgroundColor: isDark ? theme.primaryColor.withOpacity(0.1) : Colors.white,
        elevation: 0,
        actions: [
          // Search placeholder - to be implemented
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Search functionality coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Profile header with gradient background
          SliverToBoxAdapter(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.3,  // 30% of screen height
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.primaryColor,
                    theme.primaryColor.withOpacity(0.8),
                    theme.primaryColor.withOpacity(0.6),
                  ],
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Profile avatar with role icon
                  Center(
                    child: Hero(
                      tag: 'staff_avatar_${widget.user.id}',
                      child: Container(
                        width: 120,  // Fixed avatar size
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.9),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          _getIconForRole(role),
                          size: 60,  // Icon size relative to avatar
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  // Staff name and role overlay
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        Text(
                          fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          role,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Animated content section
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Professional information card
                      _buildInfoCard(
                        context,
                        'Professional Information',
                        [
                          _buildInfoRow(context, Icons.work, 'Role', role),
                          _buildInfoRow(context, Icons.business, 'Department', department),
                          _buildInfoRow(context, Icons.star, 'Specialization', specialization),
                          _buildInfoRow(context, Icons.timeline, 'Experience', experience),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Contact information card
                      _buildInfoCard(
                        context,
                        'Contact Information',
                        [
                          _buildInfoRow(context, Icons.email, 'Email', email),
                          if (phone != 'Not specified')
                            _buildInfoRow(context, Icons.phone, 'Phone', phone),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Quick action buttons
                      _buildActionButtons(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _handleNavigation,
      ),
    );
  }

  /// Returns appropriate icon based on staff member's role
  IconData _getIconForRole(String role) {
    switch (role.toLowerCase()) {
      case 'doctor':
        return Icons.medical_services;
      case 'nurse':
        return Icons.healing;
      case 'technologist':
        return Icons.biotech;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  /// Builds an information card with title and content
  Widget _buildInfoCard(BuildContext context, String title, List<Widget> children) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 4,
      shadowColor: theme.shadowColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.black12,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card title with accent bar
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Builds an information row with icon and label-value pair
  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 24,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          // Label and value
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds action buttons for messaging and scheduling
  Widget _buildActionButtons(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            context,
            'Message',
            Icons.message_rounded,
            () => _showFeatureSnackbar(context, 'Message'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            context,
            'Schedule',
            Icons.calendar_month_rounded,
            () => _showFeatureSnackbar(context, 'Schedule view'),
          ),
        ),
      ],
    );
  }

  /// Builds a styled action button with icon and label
  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    final theme = Theme.of(context);
    
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: theme.primaryColor.withOpacity(0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Shows a snackbar for features that are not yet implemented
  void _showFeatureSnackbar(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }
}


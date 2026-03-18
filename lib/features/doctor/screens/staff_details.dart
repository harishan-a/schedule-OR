// =============================================================================
// Staff Member Details Screen
// =============================================================================
// This screen displays comprehensive information about a staff member including:
// - Professional profile with profile image
// - Contact information
// - Department and role details
// - Staff member's scheduled surgeries
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
import 'package:firebase_orscheduler/shared/widgets/user_avatar.dart';
import 'package:intl/intl.dart';

/// StaffDetailPage displays detailed information about a specific staff member
/// Parameters:
/// - user: Firestore document containing staff member data
/// - selectedIndex: Current navigation index for bottom bar
class StaffDetailPage extends StatefulWidget {
  final DocumentSnapshot user;
  final int selectedIndex;

  const StaffDetailPage({
    super.key,
    required this.user,
    required this.selectedIndex,
  });

  @override
  State<StaffDetailPage> createState() => _StaffDetailPageState();
}

class _StaffDetailPageState extends State<StaffDetailPage>
    with SingleTickerProviderStateMixin {
  // Animation controllers and animations
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Navigation state
  late int _selectedIndex;

  // Stream for staff surgeries
  Stream<QuerySnapshot>? _surgeriesStream;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;

    // Initialize animations
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Fade-in animation for content
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    // Slide-up animation for content
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    // Initialize surgeries stream
    _initSurgeriesStream();
  }

  /// Initialize the stream for fetching staff member's surgeries
  void _initSurgeriesStream() {
    final userData = widget.user.data() as Map<String, dynamic>? ?? {};
    final firstName = userData['firstName'] as String? ?? '';
    final lastName = userData['lastName'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();

    // Only initialize if we have a valid name
    if (fullName.isNotEmpty) {
      _surgeriesStream = FirebaseFirestore.instance
          .collection('surgeries')
          .where(Filter.or(
            Filter('surgeon', isEqualTo: fullName),
            Filter('nurses', arrayContains: fullName),
            Filter('technologists', arrayContains: fullName),
          ))
          .where('status', whereIn: ['Scheduled', 'Confirmed', 'In Progress'])
          .where('startTime', isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .orderBy('startTime')
          .limit(10)
          .snapshots();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Safely retrieves a field value from the Firestore document
  String _getField(String field) {
    final userData = widget.user.data() as Map<String, dynamic>? ?? {};
    return userData[field]?.toString() ?? '';
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
    final userData = widget.user.data() as Map<String, dynamic>? ?? {};

    // Extract required profile fields
    final String firstName = _getField('firstName');
    final String lastName = _getField('lastName');
    final String fullName = '$firstName $lastName'.trim();
    final String role = _getField('role');
    final String department = _getField('department');
    final String email = _getField('email');
    final String phone = _getField('phoneNumber');
    final String? profileImageUrl = userData['profileImageUrl'];
    final String? selectedAvatar = userData['selectedDefaultAvatar'];

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black87),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Staff Profile',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: isDark ? colorScheme.surfaceVariant : Colors.white,
        elevation: 0,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Profile header with gradient background
          SliverToBoxAdapter(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withOpacity(0.8),
                    colorScheme.primary.withOpacity(0.6),
                  ],
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Profile avatar
                  Center(
                    child: Hero(
                      tag: 'staff_avatar_${widget.user.id}',
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: UserAvatar(
                          radius: 60,
                          name: fullName,
                          imageUrl: profileImageUrl,
                          assetPath: selectedAvatar,
                          backgroundColor: Colors.white.withOpacity(0.9),
                          textColor: colorScheme.primary,
                          showBorder: true,
                          borderColor: Colors.white,
                          borderWidth: 3,
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
                        if (role.isNotEmpty)
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Professional information card - only show if data exists
                      if (role.isNotEmpty || department.isNotEmpty)
                        _buildInfoCard(
                          context,
                          'Professional Information',
                          [
                            if (role.isNotEmpty)
                              _buildInfoRow(context, Icons.work, 'Role', role),
                            if (department.isNotEmpty)
                              _buildInfoRow(context, Icons.business,
                                  'Department', department),
                          ],
                        ),

                      const SizedBox(height: 20),

                      // Contact information card
                      _buildInfoCard(
                        context,
                        'Contact Information',
                        [
                          if (email.isNotEmpty)
                            _buildInfoRow(context, Icons.email, 'Email', email),
                          if (phone.isNotEmpty)
                            _buildInfoRow(context, Icons.phone, 'Phone', phone),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Scheduled Surgeries Section
                      _buildScheduledSurgeriesSection(context),
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

  /// Builds a section displaying scheduled surgeries for this staff member
  Widget _buildScheduledSurgeriesSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_surgeriesStream == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Icon(Icons.calendar_month, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Scheduled Surgeries',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Surgeries stream builder
        StreamBuilder<QuerySnapshot>(
          stream: _surgeriesStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Card(
                color: colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Error loading surgeries',
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final surgeries = snapshot.data?.docs ?? [];

            if (surgeries.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.event_busy, color: theme.disabledColor),
                      const SizedBox(width: 12),
                      Text(
                        'No upcoming surgeries scheduled',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: surgeries.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final surgery = surgeries[index].data() as Map<String, dynamic>;
                return _buildSurgeryCard(context, surgery);
              },
            );
          },
        ),
      ],
    );
  }

  /// Builds a card displaying surgery information
  Widget _buildSurgeryCard(BuildContext context, Map<String, dynamic> surgery) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final DateTime startTime = (surgery['startTime'] as Timestamp).toDate();
    final DateTime endTime = (surgery['endTime'] as Timestamp).toDate();
    final String surgeryType =
        surgery['surgeryType'] as String? ?? 'Unknown Surgery';
    final String patientName =
        surgery['patientName'] as String? ?? 'Unknown Patient';
    final String room =
        surgery['room'] is List && (surgery['room'] as List).isNotEmpty
            ? (surgery['room'] as List).first.toString()
            : 'Unassigned';
    final String status = surgery['status'] as String? ?? 'Scheduled';

    // Format date and time
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final formattedDate = dateFormat.format(startTime);
    final formattedStartTime = timeFormat.format(startTime);
    final formattedEndTime = timeFormat.format(endTime);

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getStatusColor(status, colorScheme).withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Surgery type and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    surgeryType,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        _getStatusColor(status, colorScheme).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _getStatusColor(status, colorScheme),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Patient and Room
            Row(
              children: [
                _buildInfoItem(
                  context,
                  Icons.person,
                  'Patient',
                  patientName,
                ),
                const SizedBox(width: 16),
                _buildInfoItem(
                  context,
                  Icons.room,
                  'Room',
                  room,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Date and Time
            Row(
              children: [
                Icon(
                  Icons.event,
                  size: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  formattedDate,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '$formattedStartTime - $formattedEndTime',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Helper widget to build surgery card info item
  Widget _buildInfoItem(
      BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Returns the appropriate color for a surgery status
  Color _getStatusColor(String status, ColorScheme colorScheme) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return colorScheme.primary;
      case 'in progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'confirmed':
        return Colors.blue;
      default:
        return colorScheme.primary;
    }
  }

  /// Builds an information card with title and content
  Widget _buildInfoCard(
      BuildContext context, String title, List<Widget> children) {
    // Don't show empty cards
    if (children.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                    color: colorScheme.primary,
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
  Widget _buildInfoRow(
      BuildContext context, IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 24,
              color: colorScheme.primary,
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
}

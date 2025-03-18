// =============================================================================
// CustomNavigationBar: Main App Navigation Component
// =============================================================================
// A custom bottom navigation bar that provides the main navigation structure
// for the application. Features include:
// - Home, Schedule, Add Surgery, Staff, and More options
// - Platform-specific adaptations (web vs mobile)
// - Animated transitions between screens
// - Modal bottom sheet for additional options
//
// Navigation Structure:
// - Primary Items: Home, Schedule, Add Surgery, Staff
// - Secondary Items (More menu): Profile, Resource Check, Surgery Log, Settings, Logout
// =============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_orscheduler/features/home/screens/home.dart';
import 'package:firebase_orscheduler/features/schedule/screens/schedule.dart';
import 'package:firebase_orscheduler/features/surgery/screens/add_surgery.dart';
import 'package:firebase_orscheduler/features/profile/screens/profile.dart';
import 'package:firebase_orscheduler/features/surgery/screens/surgery_log.dart';
import 'package:firebase_orscheduler/features/schedule/screens/resource_check_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_orscheduler/features/settings/screens/settings.dart';
import 'package:firebase_orscheduler/features/doctor/screens/doctor_page.dart';
import 'package:firebase_orscheduler/shared/widgets/notification_badge.dart';
import 'package:firebase_orscheduler/features/notifications/screens/notifications_screen.dart';

/// A custom navigation bar widget that handles the main app navigation
/// 
/// Properties:
/// - currentIndex: The currently selected navigation item (0-3)
/// - onTap: Callback function when a navigation item is selected
class CustomNavigationBar extends StatelessWidget {
  // Constants for layout dimensions
  static const double _navBarHeight = 65.0;
  static const double _iconSize = 24.0;
  static const double _fabSize = 70.0;
  static const double _labelSize = 12.0;

  final int currentIndex;
  final Function(int) onTap;

  const CustomNavigationBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  /// Handles navigation to different screens based on the selected index
  /// Includes platform-specific logic for web vs mobile views
  void _handleNavigation(BuildContext context, int index) {
    if (index == currentIndex) return;

    Widget targetScreen;
    switch (index) {
      case 0:
        targetScreen = const HomeScreen();
        break;
      case 1:
        // Web platform shows month view by default, mobile shows day view
        targetScreen = ScheduleScreen(
          initialView: kIsWeb ? ViewType.month : ViewType.day,
          allowViewChange: true,  // Always allow view changes
        );
        break;
      case 2:
        targetScreen = AddSurgeryScreen();
        break;
      case 3:
        targetScreen = const DoctorPage();
        break;
      case 4:
        targetScreen = const NotificationsScreen();
        break;
      default:
        return;
    }

    onTap(index);
    // Use fade transition for smooth navigation
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  /// Shows the more options modal bottom sheet
  /// Contains secondary navigation items and logout option
  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Secondary navigation options
            _buildMoreOption(
              context: context,
              icon: Icons.person,
              title: 'View Profile',
              screen: const ProfileScreen(),
            ),
            _buildMoreOption(
              context: context,
              icon: Icons.search,
              title: 'Resource Check',
              screen: const ResourceCheckScreen(),
            ),
            _buildMoreOption(
              context: context,
              icon: Icons.history,
              title: 'Surgery Log',
              screen: const SurgeryLogScreen(),
            ),
            _buildMoreOption(
              context: context,
              icon: Icons.settings,
              title: 'Settings',
              screen: const SettingsScreen(),
            ),
            const Divider(),
            // Logout option
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/auth');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Helper method to build more options menu items
  Widget _buildMoreOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Widget screen,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => screen),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: _navBarHeight,
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Main navigation items
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(context, 0, Icons.home_outlined, Icons.home, 'Home'),
              _buildNavItem(context, 1, Icons.calendar_month_outlined, Icons.calendar_month, 'Schedule'),
              const SizedBox(width: _fabSize), // Space for FAB
              _buildNavItem(context, 3, Icons.people_outline, Icons.people, 'Staff'),
              _buildMoreOptionsButton(context),
            ],
          ),
          // Floating Action Button (Add Surgery)
          Positioned(
            top: 2,
            left: 0,
            right: 0,
            child: Center(
              child: _buildFAB(context, theme),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a navigation item with icon and label
  Widget _buildNavItem(BuildContext context, int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = currentIndex == index;
    final theme = Theme.of(context);
    final color = isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6);

    return InkWell(
      onTap: () => _handleNavigation(context, index),
      child: SizedBox(
        height: _navBarHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: color,
              size: _iconSize,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: _labelSize,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Builds the notification item with badge
  Widget _buildNotificationItem(BuildContext context, int index) {
    final isSelected = currentIndex == index;
    final theme = Theme.of(context);
    final color = isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6);

    return InkWell(
      onTap: () => _handleNavigation(context, index),
      child: SizedBox(
        height: _navBarHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            NotificationBadge(
              onTap: () => _handleNavigation(context, index),
            ),
            const SizedBox(height: 4),
            Text(
              'Alerts',
              style: TextStyle(
                color: color,
                fontSize: _labelSize,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the more options button
  Widget _buildMoreOptionsButton(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _showMoreOptions(context),
      child: SizedBox(
        height: _navBarHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.more_horiz,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              size: _iconSize,
            ),
            const SizedBox(height: 4),
            Text(
              'More',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: _labelSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the floating action button for adding surgeries
  Widget _buildFAB(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onTap: () => _handleNavigation(context, 2),
      child: Container(
        width: _fabSize,
        height: _fabSize,
        decoration: BoxDecoration(
          color: currentIndex == 2 ? theme.colorScheme.primary : theme.colorScheme.secondary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          Icons.add,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}

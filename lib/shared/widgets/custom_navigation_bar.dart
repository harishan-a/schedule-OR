// =============================================================================
// CustomNavigationBar: Main App Navigation Component
// =============================================================================
// A custom bottom navigation bar that provides the main navigation structure
// for the application. Features include:
// - Home, Schedule, Add Surgery, Staff, and More options
// - Platform-specific adaptations (web vs mobile)
// - Animated transitions between screens
// - Navigation to More screen (Profile, Resource Check, Surgery Log, Settings, Logout)
//
// Navigation Structure:
// - Primary Items: Home, Schedule, Add Surgery, Staff, More
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:firebase_orscheduler/features/more/screens/more_screen.dart';
import 'package:firebase_orscheduler/shared/utils/transitions.dart';

/// Custom navigation bar that provides a modern, animated bottom navigation
/// with notification badges and custom styling.
class CustomNavigationBar extends StatelessWidget {
  /// Current selected index
  final int currentIndex;

  /// Callback when an item is tapped
  final Function(int) onTap;

  /// Whether to show notification badges
  final bool showBadges;

  /// Number of unread notifications
  final int notificationCount;

  /// Custom animation duration
  final Duration animationDuration;

  /// Custom curve for animations
  final Curve animationCurve;

  /// Creates a CustomNavigationBar
  const CustomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.showBadges = true,
    this.notificationCount = 0,
    this.animationDuration = const Duration(milliseconds: 200),
    this.animationCurve = Curves.easeInOut,
  });

  // Constants for layout dimensions
  static const double _navBarHeight = 65.0; // Increased height to fix overflow
  static const double _iconSize = 22.0; // Slightly smaller icons
  static const double _fabSize = 48.0; // Smaller FAB to prevent overflow
  static const double _labelSize = 10.5; // Smaller label for better fit

  /// Handles navigation to different screens based on the selected index
  /// Includes platform-specific logic for web vs mobile views
  void _handleNavigation(BuildContext context, int index) {
    if (index == currentIndex)
      return; // Prevent navigating to the same screen repeatedly

    // Add haptic feedback for button press
    HapticFeedback.lightImpact();

    Widget targetScreen;
    switch (index) {
      case 0:
        targetScreen = const HomeScreen();
        break;
      case 1:
        // Web platform shows month view by default, mobile shows day view
        targetScreen = ScheduleScreen(
          initialView: kIsWeb ? ViewType.month : ViewType.day,
          allowViewChange: true, // Always allow view changes
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
      case 5: // New case for More screen
        targetScreen = const MoreScreen();
        break;
      default:
        return;
    }

    onTap(index);

    // Use consistent page transition using our utility
    Navigator.of(context).pushReplacement(createAppTransition(targetScreen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Use SafeArea to handle system insets automatically
    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        height: _navBarHeight,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16.0), topRight: Radius.circular(16.0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
                child: _buildNavItem(
                    context, 0, Icons.home_outlined, Icons.home, 'Home')),
            Expanded(
                child: _buildNavItem(context, 1, Icons.calendar_month_outlined,
                    Icons.calendar_month, 'Schedule')),
            Expanded(child: _buildFABItem(context, theme)),
            Expanded(
                child: _buildNavItem(
                    context, 3, Icons.people_outline, Icons.people, 'Staff')),
            Expanded(child: _buildMoreOptionsButton(context)),
          ],
        ),
      ),
    );
  }

  /// Builds a navigation item with icon and label with animation effects
  Widget _buildNavItem(BuildContext context, int index, IconData icon,
      IconData activeIcon, String label) {
    final isSelected = currentIndex == index;
    final theme = Theme.of(context);
    final color = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withOpacity(0.6);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleNavigation(context, index),
        splashColor: theme.colorScheme.primary.withOpacity(0.1),
        highlightColor: theme.colorScheme.primary.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Simple animated icon
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  key: ValueKey<bool>(isSelected),
                  color: color,
                  size: _iconSize,
                ),
              ),
              const SizedBox(height: 4),
              // Text with animation
              AnimatedDefaultTextStyle(
                duration: animationDuration,
                curve: animationCurve,
                style: TextStyle(
                  color: color,
                  fontSize: _labelSize,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Animated indicator bar for selected item
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(top: 4),
                height: 3,
                width: isSelected ? 24 : 0,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a center FAB navigation item that's integrated with the navigation bar
  Widget _buildFABItem(BuildContext context, ThemeData theme) {
    final isSelected = currentIndex == 2;
    final backgroundColor =
        isSelected ? theme.colorScheme.primary : theme.colorScheme.secondary;

    return DefaultTextStyle(
      style: TextStyle(
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withOpacity(0.6),
        fontSize: _labelSize,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _fabSize,
            height: _fabSize,
            child: AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: backgroundColor.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Material(
                  elevation: 0,
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback
                          .mediumImpact(); // Stronger feedback for main action
                      _handleNavigation(context, 2);
                    },
                    splashColor: Colors.white.withOpacity(0.3),
                    highlightColor: Colors.white.withOpacity(0.1),
                    child: Ink(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            backgroundColor,
                            backgroundColor.brighten(isSelected
                                ? 20
                                : 15), // More contrast when selected
                          ],
                        ),
                      ),
                      child: AnimatedRotation(
                        turns:
                            isSelected ? 0.375 : 0, // 135 degrees when selected
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Add',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Builds the notification item with badge
  Widget _buildNotificationItem(BuildContext context, int index) {
    final isSelected = currentIndex == index;
    final theme = Theme.of(context);
    final color = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withOpacity(0.6);

    return InkWell(
      onTap: () => _handleNavigation(context, index),
      child: SizedBox(
        height: _navBarHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            NotificationBadge(
              onTap: () => _handleNavigation(context, index),
            ),
            const SizedBox(height: 3),
            Text(
              'Alerts',
              style: TextStyle(
                color: color,
                fontSize: _labelSize,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the more options button with animations
  Widget _buildMoreOptionsButton(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = currentIndex == 5;
    final color = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withOpacity(0.6);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleNavigation(context, 5),
        splashColor: theme.colorScheme.primary.withOpacity(0.1),
        highlightColor: theme.colorScheme.primary.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Simple animated dots for more icon
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isSelected
                    ? Row(
                        key: const ValueKey<bool>(true),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.circle,
                            color: color,
                            size: 5,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.circle,
                            color: color,
                            size: 5,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.circle,
                            color: color,
                            size: 5,
                          ),
                        ],
                      )
                    : Icon(
                        Icons.more_horiz,
                        key: const ValueKey<bool>(false),
                        color: color,
                        size: _iconSize,
                      ),
              ),
              const SizedBox(height: 4),
              // Text with animation
              AnimatedDefaultTextStyle(
                duration: animationDuration,
                curve: animationCurve,
                style: TextStyle(
                  color: color,
                  fontSize: _labelSize,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                child: const Text(
                  'More',
                  textAlign: TextAlign.center,
                ),
              ),
              // Animated indicator bar for selected item
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(top: 4),
                height: 3,
                width: isSelected ? 24 : 0,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Extension method to brighten colors
extension ColorBrightness on Color {
  Color brighten(int percent) {
    assert(1 <= percent && percent <= 100);
    final p = percent / 100;
    return Color.fromARGB(
      alpha,
      red + ((255 - red) * p).round(),
      green + ((255 - green) * p).round(),
      blue + ((255 - blue) * p).round(),
    );
  }
}

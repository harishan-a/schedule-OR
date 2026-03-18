// =============================================================================
// Schedule Screen
// =============================================================================
// The main schedule management screen that provides multiple views of surgeries:
// - Day View: List-based view of today's surgeries
// - Week View: Calendar view of the work week
// - Month View: Monthly calendar with agenda
// - TV View: Large display optimized view
//
// Navigation Features:
// - View switching through app bar menu
// - Bottom navigation integration
// - Optional view locking
//
// State Management:
// - Real-time surgery updates via Firestore stream
// - View type persistence
// - Configurable initial view
//
// Note: This screen serves as the container for all schedule views and
// handles the navigation between them. Each view is implemented in its own file
// for maintainability.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_orscheduler/features/schedule/screens/schedule_view_month.dart'
    as month;
import 'package:firebase_orscheduler/features/schedule/screens/schedule_view_week.dart'
    as week;
import 'package:firebase_orscheduler/features/schedule/screens/schedule_view_day.dart';
import 'package:firebase_orscheduler/features/schedule/screens/schedule_view_tv.dart';
import 'package:firebase_orscheduler/features/home/screens/home.dart';
import 'package:firebase_orscheduler/features/surgery/screens/add_surgery.dart';
import 'package:firebase_orscheduler/features/doctor/screens/doctor_page.dart';
import 'package:firebase_orscheduler/shared/widgets/custom_navigation_bar.dart';
import 'package:firebase_orscheduler/features/schedule/models/surgery.dart';
import 'package:intl/intl.dart';

/// Available schedule view types
enum ViewType {
  day, // List view of today's surgeries
  week, // Work week calendar view
  month, // Monthly calendar with agenda
  tv // Large display optimized view
}

/// Main schedule screen with multiple view options
class ScheduleScreen extends StatefulWidget {
  /// Initial view to display when screen loads
  final ViewType initialView;

  /// Whether to allow users to change views
  /// Set to false to lock the view type
  final bool allowViewChange;

  const ScheduleScreen({
    super.key,
    this.initialView = ViewType.day,
    this.allowViewChange = true,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  /// Currently active view type
  late ViewType _currentView;

  /// Stream of surgery data from Firestore
  late Stream<QuerySnapshot> _surgeriesStream;

  /// Current date focus for navigation
  DateTime _focusedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Initialize with provided view type
    _currentView = widget.initialView;
    // Set up real-time surgery data stream
    _surgeriesStream = FirebaseFirestore.instance
        .collection('surgeries')
        .orderBy('startTime')
        .snapshots();
  }

  /// Navigates to the previous time period (day/week/month)
  void _navigateToPrevious() {
    setState(() {
      switch (_currentView) {
        case ViewType.day:
          _focusedDate = _focusedDate.subtract(const Duration(days: 1));
          break;
        case ViewType.week:
          _focusedDate = _focusedDate.subtract(const Duration(days: 7));
          break;
        case ViewType.month:
          _focusedDate = DateTime(
            _focusedDate.year,
            _focusedDate.month - 1,
            _focusedDate.day,
          );
          break;
        case ViewType.tv:
          // TV view typically shows current data, but we'll support navigation
          _focusedDate = _focusedDate.subtract(const Duration(days: 1));
          break;
      }
    });
  }

  /// Navigates to the next time period (day/week/month)
  void _navigateToNext() {
    setState(() {
      switch (_currentView) {
        case ViewType.day:
          _focusedDate = _focusedDate.add(const Duration(days: 1));
          break;
        case ViewType.week:
          _focusedDate = _focusedDate.add(const Duration(days: 7));
          break;
        case ViewType.month:
          _focusedDate = DateTime(
            _focusedDate.year,
            _focusedDate.month + 1,
            _focusedDate.day,
          );
          break;
        case ViewType.tv:
          // TV view typically shows current data, but we'll support navigation
          _focusedDate = _focusedDate.add(const Duration(days: 1));
          break;
      }
    });
  }

  /// Reset focus to today
  void _navigateToToday() {
    setState(() {
      _focusedDate = DateTime.now();
    });
  }

  /// Handles navigation from bottom navigation bar
  ///
  /// Index mapping:
  /// - 0: Home screen
  /// - 1: Schedule screen (current)
  /// - 2: Add surgery screen
  /// - 3: Doctor profile screen
  void _handleNavigation(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        break;
      case 1:
        // Already on schedule screen
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AddSurgeryScreen()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DoctorPage(),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              _getViewIcon(_currentView),
              size: 24,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Schedule',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 2,
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Previous period button
                IconButton(
                  icon: Icon(Icons.chevron_left,
                      color: theme.colorScheme.primary),
                  onPressed: _navigateToPrevious,
                  tooltip: 'Previous ${_getViewPeriodName()}',
                ),
                // Center period display with today button
                GestureDetector(
                  onTap: _navigateToToday,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getFormattedPeriod(),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                // Next period button
                IconButton(
                  icon: Icon(Icons.chevron_right,
                      color: theme.colorScheme.primary),
                  onPressed: _navigateToNext,
                  tooltip: 'Next ${_getViewPeriodName()}',
                ),
              ],
            ),
          ),
        ),
        actions: [
          // Today button
          IconButton(
            icon: Icon(Icons.today, color: theme.colorScheme.primary),
            onPressed: _navigateToToday,
            tooltip: 'Today',
          ),
          // View switching menu (if enabled)
          if (widget.allowViewChange)
            PopupMenuButton<ViewType>(
              icon: Icon(Icons.calendar_view_month,
                  color: theme.colorScheme.primary),
              offset: const Offset(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (ViewType result) {
                setState(() {
                  _currentView = result;
                });
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<ViewType>>[
                _buildViewMenuItem(
                  icon: Icons.view_day,
                  title: 'Day View',
                  value: ViewType.day,
                  isSelected: _currentView == ViewType.day,
                ),
                _buildViewMenuItem(
                  icon: Icons.view_week,
                  title: 'Week View',
                  value: ViewType.week,
                  isSelected: _currentView == ViewType.week,
                ),
                _buildViewMenuItem(
                  icon: Icons.calendar_month,
                  title: 'Month View',
                  value: ViewType.month,
                  isSelected: _currentView == ViewType.month,
                ),
                _buildViewMenuItem(
                  icon: Icons.tv,
                  title: 'TV View',
                  value: ViewType.tv,
                  isSelected: _currentView == ViewType.tv,
                ),
              ],
            ),
        ],
      ),
      // Real-time surgery data stream builder
      body: StreamBuilder<QuerySnapshot>(
        stream: _surgeriesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading schedule...',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading surgeries',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        // Refresh the stream
                        _surgeriesStream = FirebaseFirestore.instance
                            .collection('surgeries')
                            .orderBy('startTime')
                            .snapshots();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Convert Firestore documents to Surgery objects
          final surgeries = snapshot.data!.docs.map((doc) {
            return Surgery.fromFirestore(
                doc.id, doc.data() as Map<String, dynamic>);
          }).toList();

          return _buildViewContent(surgeries);
        },
      ),
      bottomNavigationBar: CustomNavigationBar(
        currentIndex: 1, // Schedule tab
        onTap: _handleNavigation,
      ),
    );
  }

  /// Builds the appropriate view based on current view type
  ///
  /// Each view receives the full list of surgeries and handles
  /// its own filtering and display logic
  Widget _buildViewContent(List<Surgery> surgeries) {
    switch (_currentView) {
      case ViewType.day:
        return DayListView(
          surgeries: surgeries,
          focusedDate: _focusedDate,
        );
      case ViewType.week:
        return week.WeekViewContent(
          surgeries: surgeries,
          focusedDate: _focusedDate,
        );
      case ViewType.month:
        return month.MonthViewContent(
          surgeries: surgeries,
          focusedDate: _focusedDate,
        );
      case ViewType.tv:
        return TVViewContent(
          surgeries: surgeries,
          focusedDate: _focusedDate,
        );
    }
  }

  /// Builds a menu item for view selection with selected state indication
  PopupMenuItem<ViewType> _buildViewMenuItem({
    required IconData icon,
    required String title,
    required ViewType value,
    required bool isSelected,
  }) {
    return PopupMenuItem<ViewType>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(
              Icons.check_circle,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }

  /// Returns the appropriate icon for the current view type
  IconData _getViewIcon(ViewType viewType) {
    switch (viewType) {
      case ViewType.day:
        return Icons.view_day;
      case ViewType.week:
        return Icons.view_week;
      case ViewType.month:
        return Icons.calendar_month;
      case ViewType.tv:
        return Icons.tv;
    }
  }

  /// Returns the formatted period based on the current view type
  String _getFormattedPeriod() {
    switch (_currentView) {
      case ViewType.day:
        return DateFormat('EEEE, MMMM d').format(_focusedDate);
      case ViewType.week:
        // Find the first day of the week (Monday) for the focused date
        final DateTime weekStart = _focusedDate.subtract(
          Duration(days: _focusedDate.weekday - 1),
        );
        final DateTime weekEnd = weekStart.add(const Duration(days: 6));
        return '${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d, y').format(weekEnd)}';
      case ViewType.month:
        return DateFormat('MMMM yyyy').format(_focusedDate);
      case ViewType.tv:
        return DateFormat('EEEE, MMMM d').format(_focusedDate);
    }
  }

  /// Returns the period name based on the current view type
  String _getViewPeriodName() {
    switch (_currentView) {
      case ViewType.day:
        return 'day';
      case ViewType.week:
        return 'week';
      case ViewType.month:
        return 'month';
      case ViewType.tv:
        return 'day';
    }
  }
}

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
import 'package:firebase_orscheduler/features/schedule/screens/schedule_view_month.dart' as month;
import 'package:firebase_orscheduler/features/schedule/screens/schedule_view_week.dart' as week;
import 'package:firebase_orscheduler/features/schedule/screens/schedule_view_day.dart';
import 'package:firebase_orscheduler/features/schedule/screens/schedule_view_tv.dart';
import 'package:firebase_orscheduler/features/home/screens/home.dart';
import 'package:firebase_orscheduler/features/surgery/screens/add_surgery.dart';
import 'package:firebase_orscheduler/features/doctor/screens/doctor_page.dart';
import 'package:firebase_orscheduler/shared/widgets/custom_navigation_bar.dart';
import 'package:firebase_orscheduler/features/schedule/models/surgery.dart';

/// Available schedule view types
enum ViewType {
  day,    // List view of today's surgeries
  week,   // Work week calendar view
  month,  // Monthly calendar with agenda
  tv      // Large display optimized view
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        automaticallyImplyLeading: false,
        actions: [
          // View switching menu (if enabled)
          if (widget.allowViewChange)
            PopupMenuButton<ViewType>(
              icon: const Icon(Icons.calendar_view_month),
              onSelected: (ViewType result) {
                setState(() {
                  _currentView = result;
                });
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<ViewType>>[
                const PopupMenuItem<ViewType>(
                  value: ViewType.day,
                  child: Text('Day View'),
                ),
                const PopupMenuItem<ViewType>(
                  value: ViewType.week,
                  child: Text('Week View'),
                ),
                const PopupMenuItem<ViewType>(
                  value: ViewType.month,
                  child: Text('Month View'),
                ),
                const PopupMenuItem<ViewType>(
                  value: ViewType.tv,
                  child: Text('TV View'),
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
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error loading surgeries'));
          }

          // Convert Firestore documents to Surgery objects
          final surgeries = snapshot.data!.docs.map((doc) {
            return Surgery.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
          }).toList();

          return _buildViewContent(surgeries);
        },
      ),
      bottomNavigationBar: CustomNavigationBar(
        currentIndex: 1,  // Schedule tab
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
        return DayListView(surgeries: surgeries);
      case ViewType.week:
        return week.WeekViewContent(surgeries: surgeries);
      case ViewType.month:
        return month.MonthViewContent(surgeries: surgeries);
      case ViewType.tv:
        return TVViewContent(surgeries: surgeries);
    }
  }
}

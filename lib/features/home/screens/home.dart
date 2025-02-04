// =============================================================================
// Home Screen - Dashboard
// =============================================================================
// This screen serves as the main dashboard of the application, featuring:
// - Real-time surgery statistics and upcoming procedures
// - Push notification integration for schedule updates
// - Quick access to key features (Add Surgery, View Schedule)
// - User profile management and navigation
// - Responsive layout with custom scroll behavior
//
// Firebase Integration:
// - Firestore: Real-time surgery and user stats streams
// - FCM: Push notifications for schedule updates
// - Authentication: User profile management
// =============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:io' show Platform;

import '../services/home_service.dart';
import '../models/user_stats.dart';
import '../widgets/stat_card.dart';
import '../../../shared/widgets/custom_navigation_bar.dart';
import '../../schedule/screens/schedule.dart';
import '../../surgery/screens/add_surgery.dart';
import '../../profile/screens/profile.dart';
import '../../surgery/screens/surgery_details.dart';

/// HomeScreen serves as the main dashboard of the application, providing real-time
/// updates on surgeries, statistics, and quick access to key features.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeService _homeService = HomeService();
  final _scrollController = ScrollController();
  
  // Navigation and UI state
  int _selectedIndex = 0;
  bool _isLoading = true;
  String _userFirstName = '';
  
  // Real-time data streams
  late Stream<UserStats> _userStatsStream;
  late Stream<List<QueryDocumentSnapshot>> _userSurgeriesStream;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupPushNotifications();
    
    // Initialize real-time data streams
    _userStatsStream = _homeService.getUserStatsStream();
    _userSurgeriesStream = _homeService.getUserSurgeriesStream();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Loads the user's profile data and initializes the dashboard state
  Future<void> _loadInitialData() async {
    if (!mounted) return;

    try {
      final profile = await _homeService.getUserProfile();
      if (mounted) {
        setState(() {
          _userFirstName = profile['firstName'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Configures Firebase Cloud Messaging for push notifications
  /// Handles platform-specific setup for iOS and Android
  Future<void> _setupPushNotifications() async {
    if (kIsWeb) return; // Web platform doesn't support FCM topics

    try {
      final fcm = FirebaseMessaging.instance;
      final settings = await fcm.requestPermission();
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await fcm.getToken(); // Get FCM token for device identification
        
        if (Platform.isIOS) {
          final apnsToken = await fcm.getAPNSToken();
          if (apnsToken != null) {
            await fcm.subscribeToTopic('schedule_updates');
          }
        } else {
          // Android platform
          await fcm.subscribeToTopic('schedule_updates');
        }
      }
    } catch (e) {
      // Handle notification setup errors silently
    }
  }

  /// Navigates to the user's profile screen
  void _navigateToProfile() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => const ProfileScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInitialData,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  _buildSliverAppBar(),
                  SliverToBoxAdapter(child: _buildWelcomeBanner()),
                  SliverToBoxAdapter(child: _buildStatistics()),
                  SliverToBoxAdapter(child: _buildQuickActions()),
                  _buildUpcomingSurgeries(),
                ],
              ),
            ),
      bottomNavigationBar: CustomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  /// Builds the collapsible app bar with gradient background and action buttons
  /// Features:
  /// - Gradient background with theme colors
  /// - Decorative circle overlay for visual interest
  /// - Quick access to notifications and profile
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      floating: true,
      pinned: true,
      expandedHeight: 120.0,
      backgroundColor: Theme.of(context).colorScheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text('Dashboard'),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            // Notifications feature to be implemented
          },
        ),
        IconButton(
          icon: const Icon(Icons.person_outline),
          onPressed: _navigateToProfile,
        ),
      ],
    );
  }

  /// Builds the welcome banner with user greeting and avatar
  /// Features:
  /// - Personalized greeting with user's first name
  /// - Circular avatar with user's initial
  /// - Real-time surgery status updates
  Widget _buildWelcomeBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    Text(
                      _userFirstName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 30,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Text(
                  _userFirstName.isNotEmpty ? _userFirstName[0].toUpperCase() : '',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<UserStats>(
            stream: _userStatsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Error loading stats');
              }
              
              final stats = snapshot.data ?? UserStats.empty();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You have ${stats.scheduledSurgeries} upcoming surgeries',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (stats.inProgressSurgeries > 0)
                    Text(
                      '${stats.inProgressSurgeries} surgeries in progress',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.orange,
                          ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Builds the statistics section with real-time surgery metrics
  /// Features:
  /// - Real-time updates via Firestore stream
  /// - Color-coded stat cards for different surgery states
  /// - Responsive grid layout
  Widget _buildStatistics() {
    return StreamBuilder<UserStats>(
      stream: _userStatsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading statistics'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data ?? UserStats.empty();
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Your Statistics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Scheduled',
                      value: stats.scheduledSurgeries.toString(),
                      color: Colors.blue,
                      icon: Icons.schedule,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'In Progress',
                      value: stats.inProgressSurgeries.toString(),
                      color: Colors.orange,
                      icon: Icons.sync,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Completed',
                      value: stats.completedSurgeries.toString(),
                      color: Colors.green,
                      icon: Icons.check_circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Cancelled',
                      value: stats.cancelledSurgeries.toString(),
                      color: Colors.red,
                      icon: Icons.cancel,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds the quick actions section for common tasks
  /// Features:
  /// - Add Surgery shortcut
  /// - View Schedule shortcut
  /// - Themed cards with icons
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  title: 'Add Surgery',
                  icon: Icons.add_circle_outline,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddSurgeryScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionCard(
                  title: 'View Schedule',
                  icon: Icons.calendar_today,
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ScheduleScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds an action card with icon and title
  /// Parameters:
  /// - title: Action name
  /// - icon: Action icon
  /// - color: Accent color
  /// - onTap: Action callback
  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the upcoming surgeries section with real-time updates
  /// Features:
  /// - Real-time Firestore stream for surgery updates
  /// - Grouped by surgery status
  /// - Interactive cards with navigation to details
  Widget _buildUpcomingSurgeries() {
    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: _userSurgeriesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final surgeries = snapshot.data!;
        if (surgeries.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(child: Text('No upcoming surgeries')),
          );
        }

        final groupedSurgeries = groupBy(surgeries, (surgery) {
          final data = surgery.data() as Map<String, dynamic>;
          return data['status'] ?? 'Unknown';
        });

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final status = groupedSurgeries.keys.elementAt(index);
              final surgeriesInStatus = groupedSurgeries[status]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      status,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: surgeriesInStatus.length,
                    itemBuilder: (context, idx) {
                      final surgery = surgeriesInStatus[idx];
                      final data = surgery.data() as Map<String, dynamic>;
                      final surgeryDate = (data['startTime'] as Timestamp).toDate();
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            data['patientName'] ?? 'Unknown Patient',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(data['surgeryType'] ?? 'Unknown Surgery'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('MMM d, y').format(surgeryDate),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onTap: () => _navigateToSurgeryDetails(surgery.id),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
            childCount: groupedSurgeries.length,
          ),
        );
      },
    );
  }

  /// Navigates to the surgery details screen
  void _navigateToSurgeryDetails(String surgeryId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SurgeryDetailsScreen(surgeryId: surgeryId),
      ),
    );
  }
}

/// Groups a list of items by a key function
/// Returns a map of keys to lists of items
Map<String, List<T>> groupBy<T>(List<T> items, String Function(T) key) {
  return items.fold<Map<String, List<T>>>(
    {},
    (Map<String, List<T>> map, T item) {
      final k = key(item);
      map[k] = [...?map[k], item];
      return map;
    },
  );
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'schedule.dart';
import 'add_surgery.dart';
import 'profile.dart';
import 'doctor_details.dart';

/// HomeScreen is the main screen of the application, providing navigation
/// to various features like viewing schedules, adding surgeries, and more.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userFirstName = '';
  bool _isLoading = true;
  int _selectedIndex = 0;
  String _nextSurgeryDate = '';

  /// Sets up push notifications for the user.
  /// Requests permission and subscribes to the 'schedule_updates' topic.
  void setupPushNotifications() async {
    final fcm = FirebaseMessaging.instance;
    await fcm.requestPermission();
    fcm.subscribeToTopic('schedule_updates');
  }

  @override
  void initState() {
    super.initState();
    setupPushNotifications();
    _fetchUserFirstName();
    _fetchNextSurgeryDate();
  }

  /// Fetches the first name of the current user from Firestore.
  /// Updates the state with the user's first name and stops the loading indicator.
  Future<void> _fetchUserFirstName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        _userFirstName = userData['firstName'] ?? '';
        _isLoading = false;
      });
    }
  }

  /// Fetches the next surgery date for the current user from Firestore.
  /// Updates the state with the formatted surgery date or an empty string if not found.
  Future<void> _fetchNextSurgeryDate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid.isEmpty) {
      print("Error: User is not authenticated or UID is missing");
      return;
    }

    try {
      final surgeryData = await FirebaseFirestore.instance
          .collection('surgeries')
          .doc(user.uid)
          .get();

      if (surgeryData.exists) {
        setState(() {
          _nextSurgeryDate = surgeryData['startTime'] != null
              ? DateFormat('MMMM dd, yyyy').format((surgeryData['startTime'] as Timestamp).toDate())
              : '';
        });
      } else {
        setState(() {
          _nextSurgeryDate = '';
        });
      }
    } catch (e) {
      print("Error fetching next surgery date: $e");
    }
  }

  /// Navigates to the Profile screen.
  void _navigateToProfile() {
    Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const ProfileScreen()));
  }

  /// Handles navigation based on the selected index in the bottom navigation bar.
  void _onItemTapped(int index) {
    switch (index) {
      case 1:
        Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => ScheduleScreen()));
        break;
      case 2:
        Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => AddSurgeryScreen()));
        break;
      case 3:
        Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const ProfileScreen()));
        break;
      case 4:
        Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => DoctorDetailsScreen()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        automaticallyImplyLeading: false,    // removes the back button
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: _navigateToProfile,
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacementNamed('/auth');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildWelcomeBanner(),
                  _buildQuickActions(),
                  _buildRecentActivities(),
                  _buildStatistics(),
                  _buildAnnouncements(),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
            backgroundColor: Color.fromARGB(218, 1, 196, 164),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'View Surgery Schedule',
            backgroundColor: Color.fromARGB(218, 1, 196, 164),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medication),
            label: 'Add New Surgery',
            backgroundColor: Color.fromARGB(248, 230, 203, 150),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
            backgroundColor: Color.fromARGB(248, 230, 203, 150),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts),
            label: 'View Doctor List',
            backgroundColor: Color.fromARGB(248, 230, 203, 150),
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }

  /// Builds a welcome banner displaying the user's first name and next surgery date.
  Widget _buildWelcomeBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal, Colors.tealAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, $_userFirstName!',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _nextSurgeryDate.isNotEmpty
                ? 'Your next surgery date is: $_nextSurgeryDate'
                : 'No surgeries scheduled',
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a row of quick action buttons for easy navigation.
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildActionButton(
              label: 'Schedule',
              icon: Icons.calendar_today,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => ScheduleScreen())),
              color: Colors.green,
            ),
            _buildActionButton(
              label: 'Add Surgery',
              icon: Icons.add,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => AddSurgeryScreen())),
              color: Colors.orange,
            ),
            _buildActionButton(
              label: 'Profile',
              icon: Icons.person,
              onPressed: _navigateToProfile,
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a section displaying recent activities related to surgeries.
  Widget _buildRecentActivities() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activities',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('Surgery scheduled for March 10, 2023'),
              subtitle: Text('Dr. Smith - Operating Room 1'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.cancel, color: Colors.red),
              title: Text('Surgery canceled for March 8, 2023'),
              subtitle: Text('Dr. Johnson - Operating Room 2'),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a row of statistics cards showing surgery counts.
  Widget _buildStatistics() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatisticCard('Scheduled', '5', Colors.blue),
          _buildStatisticCard('Completed', '12', Colors.green),
          _buildStatisticCard('Canceled', '2', Colors.red),
        ],
      ),
    );
  }

  /// Builds a card displaying a statistic with a title and count.
  Widget _buildStatisticCard(String title, String count, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 16, color: color),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a section displaying announcements.
  Widget _buildAnnouncements() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Announcements',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.announcement, color: Colors.orange),
              title: Text('New COVID-19 protocols in place'),
              subtitle: Text('Please review the updated guidelines.'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.announcement, color: Colors.orange),
              title: Text('Maintenance scheduled for March 15, 2023'),
              subtitle: Text('The system will be down from 2 AM to 4 AM.'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.announcement, color: Colors.orange),
              title: Text('New feature release'),
              subtitle: Text('Check out the new surgery tracking feature.'),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds an action button with a label, icon, and color.
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: const TextStyle(fontSize: 18),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }
}

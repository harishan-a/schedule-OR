import 'package:firebase_orscheduler/screens/doctor_details.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'schedule.dart';
import 'add_surgery.dart';
import 'profile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userFirstName = '';
  bool _isLoading = true;

  // Method to handle Firebase push notifications
  void setupPushNotifications() async {
    final fcm = FirebaseMessaging.instance;

    await fcm.requestPermission();
    fcm.subscribeToTopic('schedule_updates'); // Subscribing to schedule updates
  }

  @override
  void initState() {
    super.initState();
    setupPushNotifications(); // Set up push notifications when the screen is initialized
    _fetchUserFirstName(); // Fetch user's first name
  }

  Future<void> _fetchUserFirstName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        _userFirstName = userData['firstName'] ?? '';
        _isLoading = false;
      });
    }
  }

  void _navigateToProfile() {
    Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const ProfileScreen()));
  }

  void _navigateToSchedule() {
    Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => ScheduleScreen()));
  }

  void _navigateToAddSurgery() {
    Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => AddSurgeryScreen()));
  }

  void _navigateToViewDoctorDetails() {
    Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => DoctorDetailsScreen()));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: _navigateToProfile, // Navigate to Profile Screen
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              FirebaseAuth.instance.signOut(); // Log the user out
              Navigator.of(context).pushReplacementNamed('/auth'); // Redirect to login screen
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Welcome, $_userFirstName!',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildActionButton(
                    label: 'View Surgery Schedule',
                    icon: Icons.calendar_today,
                    onPressed: _navigateToSchedule,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 15),
                  _buildActionButton(
                    label: 'Add New Surgery',
                    icon: Icons.add_circle_outline,
                    onPressed: _navigateToAddSurgery,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 15),
                  _buildActionButton(
                    label: 'Profile',
                    icon: Icons.person_outline,
                    onPressed: _navigateToProfile,
                    color: Colors.purple,
                  ),
                  const SizedBox(height: 15),
                  _buildActionButton(
                    label: 'View Doctor List',
                    icon: Icons.person_outline,
                    onPressed: _navigateToViewDoctorDetails,
                    color: Colors.lightBlueAccent,
                  ),

                ],
              ),
            ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 24),
      label: Text(
        label,
        style: const TextStyle(fontSize: 18),
      ),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }
}

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
  int _selectedIndex = 0;
  String _nextSurgeryDate = '';

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
    _fetchNextSurgeryDate();
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

  Future<void> _fetchNextSurgeryDate() async {
    final surgeryData = await FirebaseFirestore.instance.collection('surgeries').doc(_userFirstName).get();

    setState((){
      _nextSurgeryDate = surgeryData[_userFirstName] ?? 'No surgeries scheduled';
      _isLoading = false;
    });
  }

  void _navigateToProfile() {
    Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const ProfileScreen()));
  }

  void _onItemTapped(int index){
    if (index == 1){
      Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => ScheduleScreen()));
    } else if (index == 2){
      Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => AddSurgeryScreen()));
    } else if (index == 3){
      Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const ProfileScreen()));
    }
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
                  Text(
                    'Your next surgery date will be: $_nextSurgeryDate',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.normal,
                    )
                  )
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
            backgroundColor:  Color.fromARGB(218, 1, 196, 164),
            ),       
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'View Surgery Schedule',
            backgroundColor:  Color.fromARGB(218, 1, 196, 164),
            ), 
          BottomNavigationBarItem(
            icon: Icon(Icons.medication),
            label: 'Add New Surgery',
            backgroundColor:  Color.fromARGB(248, 230, 203, 150),
            ), 
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
            backgroundColor:  Color.fromARGB(248, 230, 203, 150),
            ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
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

import 'package:firebase_orscheduler/screens/home.dart';
import 'package:firebase_orscheduler/screens/profile.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_orscheduler/utils/schedule/schedule_view_month.dart';
import 'package:firebase_orscheduler/utils/schedule/schedule_view_tv.dart';
import 'package:firebase_orscheduler/utils/schedule/schedule_view_week.dart';
import 'package:firebase_orscheduler/utils/schedule/surgery_details.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'add_surgery.dart';
import 'doctor_details.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  ViewType _currentView = ViewType.list;
  final Stream<QuerySnapshot> _surgeriesStream = FirebaseFirestore.instance
      .collection('surgeries')
      .orderBy('startTime', descending: false)
      .snapshots();

  String _userFirstName = '';
  String _nextSurgeryDate = '';
  bool _isLoading = true;
  int _selectedIndex = 1;

  // Handles navigation based on the selected index in the BottomNavigationBar
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (ctx) => const HomeScreen()));
        break;
      case 1:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (ctx) => ScheduleScreen()));
        break;
      case 2:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (ctx) => AddSurgeryScreen()));
        break;
      case 3:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (ctx) => ProfileScreen()));
        break;
      case 4:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (ctx) => const DoctorDetailsScreen()));
        break;
    }
  }


  void _showViewSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _buildViewOption(ViewType.list, 'List View', Icons.list),
            _buildViewOption(ViewType.week, 'Week View', Icons.calendar_view_week),
            _buildViewOption(ViewType.month, 'Month View', Icons.calendar_month),
            _buildViewOption(ViewType.tv, 'TV View', Icons.tv),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }


  Widget _buildViewOption(ViewType type, String title, IconData icon) {
    final isSelected = _currentView == type;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Theme.of(context).primaryColor : null),
      title: Text(
        title,
        style: TextStyle(color: isSelected ? Theme.of(context).primaryColor : null),
      ),
      tileColor: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
      onTap: () {
        setState(() {
          _currentView = type;
        });
        Navigator.pop(context);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    setupPushNotifications(); // Set up push notifications when the screen is initialized
    _fetchUserFirstName(); // Fetch user's first name
    _fetchNextSurgeryDate();
  }

  // Method to handle Firebase push notifications
  void setupPushNotifications() async {
    if (kIsWeb) {
      // Web-specific code
      print("Web platform does not support subscribeToTopic");
    } else {
      final fcm = FirebaseMessaging.instance;

      await fcm.requestPermission();
      fcm.subscribeToTopic('schedule_updates'); // Subscribing to schedule updates
    }
  }

  Future<void> _fetchUserFirstName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _userFirstName = userData['firstName'] ?? '';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchNextSurgeryDate() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.uid.isEmpty) {
      print("Error: User is not authenticated or UID is missing");
      return;  // Exit early if the user is not logged in or UID is empty
    }

    try {
      final surgeryData = await FirebaseFirestore.instance
          .collection('surgeries')
          .doc(user.uid) // Use the user ID as the document path
          .get();

      if (surgeryData.exists) {
        if (mounted) {
          setState(() {
            _nextSurgeryDate = surgeryData['startTime'] != null
                ? DateFormat('MMMM dd, yyyy').format((surgeryData['startTime'] as Timestamp).toDate())
                : 'No surgeries scheduled';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _nextSurgeryDate = 'No surgeries scheduled';
          });
        }
      }
    } catch (e) {
      print("Error fetching next surgery date: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        automaticallyImplyLeading: false,    // removes the back button
        actions: [
          IconButton(
            icon: const Icon(Icons.view_list),
            onPressed: _showViewSelector,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _surgeriesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error loading surgeries'));
          }

          final surgeries = snapshot.data!.docs.map((doc) {
            return Surgery.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
          }).toList();

          return _buildViewContent(surgeries);
        },
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
            label: 'Surgery Schedule',
            backgroundColor: Color.fromARGB(218, 1, 196, 164),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medication),
            label: 'Add New Surgery',
            backgroundColor: Color.fromARGB(218, 1, 196, 164),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
            backgroundColor: Color.fromARGB(218, 1, 196, 164),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts),
            label: 'Doctor List',
            backgroundColor: Color.fromARGB(218, 1, 196, 164),
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildViewContent(List<Surgery> surgeries) {
    switch (_currentView) {
      case ViewType.list:
        return ListViewContent(surgeries: surgeries);
      case ViewType.week:
        return WeekViewContent(surgeries: surgeries);
      case ViewType.month:
        return MonthViewContent(surgeries: surgeries);
      case ViewType.tv:
        return TVViewContent(surgeries: surgeries);
      default:
        return ListViewContent(surgeries: surgeries);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'in progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showSurgeryDetails(BuildContext context, Surgery surgery) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, controller) => SurgeryDetails(
          surgery: surgery,
          scrollController: controller,
        ),
      ),
    );
  }
}

class Surgery {
  final String id;
  final String surgeryType;
  final List<String> room;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final String surgeon;
  final List<String> nurses;
  final List<String> technologists;
  final String notes;

  Surgery({
    required this.id,
    required this.surgeryType,
    required this.room,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.surgeon,
    required this.nurses,
    required this.technologists,
    required this.notes,
  });

  factory Surgery.fromFirestore(String id, Map<String, dynamic> data) {
    return Surgery(
      id: id,
      surgeryType: data['surgeryType'] ?? '',
      room: data['room'] is List ? List<String>.from(data['room']) : [data['room']],
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      status: data['status'] ?? 'Scheduled',
      surgeon: data['surgeon'] ?? '',
      nurses: List<String>.from(data['nurses'] ?? []),
      technologists: List<String>.from(data['technologists'] ?? []),
      notes: data['notes'] ?? '',
    );
  }
}

enum ViewType { list, week, month, tv }

class ListViewContent extends StatelessWidget {
  final List<Surgery> surgeries;

  const ListViewContent({super.key, required this.surgeries});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // Get in progress surgeries
    final inProgressSurgeries = surgeries
        .where((s) => s.status.toLowerCase() == 'in progress')
        .toList();

    // Get today's scheduled surgeries
    final todaySurgeries = surgeries.where((surgery) {
      return surgery.startTime.year == now.year &&
          surgery.startTime.month == now.month &&
          surgery.startTime.day == now.day &&
          surgery.status.toLowerCase() == 'scheduled';
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // Get upcoming surgeries (future dates)
    final upcomingSurgeries = surgeries.where((surgery) {
      return surgery.startTime.isAfter(now.add(const Duration(days: 1))) &&
          surgery.status.toLowerCase() == 'scheduled';
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return CustomScrollView(
      slivers: [
        if (inProgressSurgeries.isNotEmpty) ...[
          _buildSectionHeader('In Progress', Colors.orange),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSurgeryCard(
                context,
                inProgressSurgeries[index],
                isHighlighted: true,
              ),
              childCount: inProgressSurgeries.length,
            ),
          ),
        ],

        if (todaySurgeries.isNotEmpty) ...[
          _buildSectionHeader('Today\'s Surgeries', Colors.blue),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSurgeryCard(
                context,
                todaySurgeries[index],
              ),
              childCount: todaySurgeries.length,
            ),
          ),
        ],

        if (upcomingSurgeries.isNotEmpty) ...[
          _buildSectionHeader('Upcoming Surgeries', Colors.green),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSurgeryCard(
                context,
                upcomingSurgeries[index],
              ),
              childCount: upcomingSurgeries.length,
            ),
          ),
        ],

        if (surgeries.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Text('No surgeries scheduled'),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color.withOpacity(0.8),
          ),
        ),
      ),
    );
  }

  Widget _buildSurgeryCard(
    BuildContext context,
    Surgery surgery, {
    bool isHighlighted = false,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isHighlighted ? 4 : 1,
      child: Container(
        decoration: BoxDecoration(
          border: isHighlighted
              ? Border.all(
                  color: _getStatusColor(surgery.status),
                  width: 2,
                )
              : null,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  surgery.surgeryType,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(surgery.status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  surgery.status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16),
                  const SizedBox(width: 4),
                  Text(DateFormat('h:mm a').format(surgery.startTime)),
                  const SizedBox(width: 8),
                  const Icon(Icons.timer, size: 16),
                  const SizedBox(width: 4),
                  Text(DateFormat('h:mm a').format(surgery.endTime)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.room, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      surgery.room.join(", "),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Dr. ${surgery.surgeon}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Cancel Surgery Button
              if (surgery.status.toLowerCase() != 'cancelled') // Show only if not already cancelled
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: () => _cancelSurgery(context, surgery.id), // Call the cancellation method
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    label: const Text(
                      'Cancel Surgery',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, // Set button color to red
                    ),
                  ),
                ),
            ],
          ),
          onTap: () => _showSurgeryDetails(context, surgery),

        ),

      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'in progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showSurgeryDetails(BuildContext context, Surgery surgery) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, controller) => SurgeryDetails(
          surgery: surgery,
          scrollController: controller,
        ),
      ),
    );
  }

  void _cancelSurgery(BuildContext context, String surgeryId) async {
    try {
      await FirebaseFirestore.instance
          .collection('surgeries')
          .doc(surgeryId)
          .update({'status': 'Cancelled'});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Surgery has been cancelled successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel surgery: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StaffDetailPage extends StatelessWidget {
  final DocumentSnapshot user;

  const StaffDetailPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final fullName = '${user['firstName']} ${user['lastName']}';
    final role = user['role'];
    final department = user['department'];
    final email = user['email'];
    final phone = user['phoneNumber'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Details'),
      ),
      backgroundColor: Color(0xFFDEF0EF),
      body: Padding(

        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text("General Information", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text("Name: ${fullName}", style: const TextStyle(fontSize: 18, )),
            const SizedBox(height: 16),
            Text('Role: $role', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('Department: $department', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('Email: $email', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('Phone: $phone', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Navigate back
              },
              child: const Text('Go Back',  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            ),
          ],
        ),
      ),
    );
  }
}

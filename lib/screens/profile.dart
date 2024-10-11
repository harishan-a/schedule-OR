import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  var _firstName = '';
  var _lastName = '';
  var _phoneNumber = '';
  var _email = '';
  var _role = '';
  var _department = '';

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Loads user data from Firebase Firestore
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        _firstName = userData['firstName'] ?? '';
        _lastName = userData['lastName'] ?? '';
        _phoneNumber = userData['phoneNumber'] ?? '';
        _email = user.email ?? '';
        _role = userData['role'] ?? '';
        _department = userData['department'] ?? '';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop(); // Back navigation
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                children: [
                  // Profile picture with edit button
                  Stack(
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage('https://via.placeholder.com/150'),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          height: 30,
                          width: 30,
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                            onPressed: () {
                              // Handle profile picture change
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Profile Info Fields (non-editable)
                  buildProfileRow('Username', '$_firstName $_lastName'), // Combines first and last name
                  const SizedBox(height: 10),
                  buildProfileRow('Email', _email),
                  const SizedBox(height: 10),
                  buildProfileRow('Phone', _phoneNumber),
                  const SizedBox(height: 10),
                  buildProfileRow('Role', _role),
                  const SizedBox(height: 10),
                  buildProfileRow('Department', _department),
                  const SizedBox(height: 30),

                  // Change password button
  ElevatedButton(
    onPressed: () {
      // Password reset functionality
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.redAccent, // Use backgroundColor instead of primary
      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    child: const Text('Change Password'),
  )
  ,
                ],
              ),
            ),
    );
  }

  // Helper method to build rows for profile fields
  Widget buildProfileRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
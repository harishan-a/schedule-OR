// =============================================================================
// Profile Screen
// =============================================================================
// A screen that displays and manages user profile information including:
// - Personal details (name, contact information)
// - Professional information (role, department)
// - Profile picture management
// - Password change functionality
//
// Firebase Integration:
// - Firestore: User profile data storage
// - Authentication: Email and password management
//
// Layout Features:
// - Responsive design with scroll support
// - Consistent styling with the app's theme
// - Clear visual hierarchy for information display
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:firebase_orscheduler/shared/widgets/custom_navigation_bar.dart';

/// A screen widget that displays and manages user profile information
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // UI state management
  bool _isLoading = true;
  
  // User profile data
  var _firstName = '';
  var _lastName = '';
  var _phoneNumber = '';
  var _email = '';
  var _role = '';
  var _department = '';
  
  // Navigation state
  int _selectedIndex = 3; // Profile tab index

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Loads user profile data from Firestore
  /// 
  /// Fetches both authentication and profile data:
  /// - Basic info from Auth (email)
  /// - Extended info from Firestore (name, role, etc.)
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
      // Clean, minimal app bar with no back button
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                children: [
                  // Profile picture section with edit button overlay
                  _buildProfilePicture(),
                  const SizedBox(height: 20),

                  // Profile information section
                  _buildProfileInformation(),
                  const SizedBox(height: 30),

                  // Action buttons section
                  _buildActionButtons(),
                ],
              ),
            ),
      bottomNavigationBar: CustomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  /// Builds the profile picture section with edit button
  Widget _buildProfilePicture() {
    return Stack(
      children: [
        // Profile image - currently using placeholder
        const CircleAvatar(
          radius: 50, // Fixed size for consistency
          backgroundImage: NetworkImage('https://via.placeholder.com/150'),
        ),
        // Edit button overlay
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
              icon: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 16, // Small icon for better aesthetics
              ),
              onPressed: () {
                // Image upload functionality to be implemented
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the profile information section
  Widget _buildProfileInformation() {
    return Column(
      children: [
        buildProfileRow('Username', '$_firstName $_lastName'),
        const SizedBox(height: 10),
        buildProfileRow('Email', _email),
        const SizedBox(height: 10),
        buildProfileRow('Phone', _phoneNumber),
        const SizedBox(height: 10),
        buildProfileRow('Role', _role),
        const SizedBox(height: 10),
        buildProfileRow('Department', _department),
      ],
    );
  }

  /// Builds the action buttons section
  Widget _buildActionButtons() {
    return ElevatedButton(
      onPressed: () {
        // Password reset functionality to be implemented
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        padding: const EdgeInsets.symmetric(
          horizontal: 50,
          vertical: 15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: const Text('Change Password'),
    );
  }

  /// Helper method to build consistent profile information rows
  /// 
  /// Parameters:
  /// - label: The field name or category
  /// - value: The actual value to display
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

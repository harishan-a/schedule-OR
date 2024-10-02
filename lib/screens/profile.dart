import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  var _firstName = '';
  var _lastName = '';
  var _phoneNumber = '';
  var _email = '';
  var _role = ''; // Track the role of the user
  var _department = '';
  bool _isLoading = true;
  bool _isCustomDepartment = false; // Tracks whether "Other" is selected

  // Predefined role and department lists
  final List<String> _roles = [
    'Doctor',
    'Nurse',
    'Admin',
    'Surgical Coordinator',
    'Technologist'
  ];

  final List<String> _departments = [
    'Cardiology',
    'Neurology',
    'Radiology',
    'Orthopedics',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
        _role = userData['role'] ?? ''; // Load user role
        _department = userData['department'] ?? ''; // Load department
        _isCustomDepartment = !_departments.contains(_department); // Determine if it's a custom department
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserData() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) return;

    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'firstName': _firstName,
        'lastName': _lastName,
        'phoneNumber': _phoneNumber,
        'role': _role,
        'department': _department, // Save the department, whether it's custom or predefined
      });
    }

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully')),
    );
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: _email);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send password reset email: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // First Name
                    TextFormField(
                      initialValue: _firstName,
                      decoration: const InputDecoration(labelText: 'First Name'),
                      onSaved: (value) {
                        _firstName = value!;
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your first name.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    // Last Name
                    TextFormField(
                      initialValue: _lastName,
                      decoration: const InputDecoration(labelText: 'Last Name'),
                      onSaved: (value) {
                        _lastName = value!;
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your last name.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    // Email (Read-only)
                    TextFormField(
                      initialValue: _email,
                      decoration: const InputDecoration(labelText: 'Email'),
                      readOnly: true,
                    ),
                    const SizedBox(height: 10),
                    // Phone Number
                    TextFormField(
                      initialValue: _phoneNumber,
                      decoration: const InputDecoration(labelText: 'Phone Number'),
                      keyboardType: TextInputType.phone,
                      onSaved: (value) {
                        _phoneNumber = value!;
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your phone number.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    // Role Dropdown
                    DropdownButtonFormField<String>(
                      value: _role,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: _roles.map((String role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(role),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          _role = value!;
                        });
                      },
                      onSaved: (String? value) {
                        _role = value!;
                      },
                    ),
                    const SizedBox(height: 10),
                    // Department dropdown or custom input
                    DropdownButtonFormField<String>(
                      value: _isCustomDepartment ? 'Other' : _department,
                      decoration: const InputDecoration(labelText: 'Department'),
                      items: _departments.map((String department) {
                        return DropdownMenuItem<String>(
                          value: department,
                          child: Text(department),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          if (value == 'Other') {
                            _isCustomDepartment = true;
                            _department = ''; // Allow user to type in a custom department
                          } else {
                            _isCustomDepartment = false;
                            _department = value!;
                          }
                        });
                      },
                      onSaved: (String? value) {
                        if (!_isCustomDepartment) {
                          _department = value!;
                        }
                      },
                    ),
                    if (_isCustomDepartment)
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Custom Department'),
                        onSaved: (value) {
                          _department = value!;
                        },
                        validator: (value) {
                          if (_isCustomDepartment && (value == null || value.trim().isEmpty)) {
                            return 'Please enter your department.';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 20),
                    // Change password button
                    ElevatedButton(
                      onPressed: _changePassword,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                      child: const Text('Change Password'),
                    ),
                    const SizedBox(height: 20),
                    // Save Changes button
                    ElevatedButton(
                      onPressed: _updateUserData,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

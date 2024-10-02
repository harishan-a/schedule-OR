import 'package:firebase_orscheduler/screens/home.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_orscheduler/utils/formatters.dart';

final _firebase = FirebaseAuth.instance;

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() {
    return _AuthScreenState();
  }
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  var _isLogin = true;
  var _enteredEmail = '';
  var _enteredPassword = '';
  var _enteredFirstName = '';
  var _enteredLastName = '';
  var _enteredPhoneNumber = '';
  var _customDepartment = '';
  var _selectedRole = 'Doctor'; // Default selected role
  var _selectedDepartment = 'Cardiology'; // Default department
  var _isAuthenticating = false;

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

  void _submit() async {
  final isValid = _form.currentState!.validate();
  if (!isValid) return;

  _form.currentState!.save();

  try {
    setState(() {
      _isAuthenticating = true;
    });

    if (_isLogin) {
      // Login user
      final userCredentials = await _firebase.signInWithEmailAndPassword(
        email: _enteredEmail,
        password: _enteredPassword,
      );

      // Navigate to home screen after successful login
      if (mounted) {
        Navigator.of(context).pushReplacement(_createRoute());
      }

    } else {
      // Sign up user
      final userCredentials = await _firebase.createUserWithEmailAndPassword(
        email: _enteredEmail,
        password: _enteredPassword,
      );

      // Determine the department (custom or selected)
      String department = _selectedDepartment == 'Other'
          ? _customDepartment
          : _selectedDepartment;

      // Write user information to Firestore after successful authentication
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredentials.user!.uid)
          .set({
        'firstName': _enteredFirstName,
        'lastName': _enteredLastName,
        'email': _enteredEmail,
        'phoneNumber': _enteredPhoneNumber,
        'role': _selectedRole,
        'department': department,
      });

      // Navigate to home screen after successful signup
      if (mounted) {
        Navigator.of(context).pushReplacement(_createRoute());
      }
    }
  } on FirebaseAuthException catch (error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.message ?? 'Authentication failed.'),
      ),
    );
  } finally {
    setState(() {
      _isAuthenticating = false;
    });
  }
}


  Route _createRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Smooth fade-in animation for logo
              AnimatedSize(
                duration: const Duration(seconds: 1),
                child: Container(
                  margin: const EdgeInsets.only(top: 30, bottom: 20),
                  width: 200,
                  child: Image.asset(
                      'assets/images/doctorlogo.png'),
                ),
              ),
              Card(
                margin: const EdgeInsets.all(20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 10,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // First Name field (Sign up only)
                        if (!_isLogin)
                          _buildTextField(
                            labelText: 'First Name',
                            onSaved: (value) {
                              _enteredFirstName = value!;
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your first name.';
                              }
                              return null;
                            },
                          ),

                        // Last Name field (Sign up only)
                        if (!_isLogin)
                          _buildTextField(
                            labelText: 'Last Name',
                            onSaved: (value) {
                              _enteredLastName = value!;
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your last name.';
                              }
                              return null;
                            },
                          ),

                        // Role selection dropdown
                        if (!_isLogin)
                          _buildDropdownField(
                            label: 'Select Role',
                            value: _selectedRole,
                            items: _roles,
                            onChanged: (value) {
                              setState(() {
                                _selectedRole = value!;
                              });
                            },
                          ),

                        // Department field with "Other" option
                        if (!_isLogin)
                          _buildDropdownField(
                            label: 'Department / Specialization',
                            value: _selectedDepartment,
                            items: _departments,
                            onChanged: (value) {
                              setState(() {
                                _selectedDepartment = value!;
                                if (_selectedDepartment != 'Other') {
                                  _customDepartment = '';
                                }
                              });
                            },
                          ),
                        if (!_isLogin && _selectedDepartment == 'Other')
                          _buildTextField(
                            labelText: 'Custom Department',
                            onSaved: (value) {
                              _customDepartment = value!;
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your custom department.';
                              }
                              return null;
                            },
                          ),

                        // Email field
                        _buildTextField(
                          labelText: 'Email Address',
                          onSaved: (value) {
                            _enteredEmail = value!;
                          },
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty ||
                                !value.contains('@')) {
                              return 'Please enter a valid email address.';
                            }
                            return null;
                          },
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 10),

                        // Password field
                        _buildTextField(
                          labelText: 'Password',
                          obscureText: true,
                          onSaved: (value) {
                            _enteredPassword = value!;
                          },
                          validator: (value) {
                            if (value == null || value.trim().length < 6) {
                              return 'Password must be at least 6 characters long.';
                            }
                            return null;
                          },
                        ),

                        // Phone Number field (Sign up only)
                        if (!_isLogin)
                          _buildTextField(
                            labelText: 'Phone Number',
                            hintText: '(123)-123-1234',
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              PhoneNumberFormatter(),
                            ],
                            onSaved: (value) {
                              _enteredPhoneNumber = value!;
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your phone number.';
                              } else if (value.length != 14) {
                                return 'Please enter a valid phone number.';
                              }
                              return null;
                            },
                          ),

                        const SizedBox(height: 12),

                        if (_isAuthenticating)
                          const CircularProgressIndicator(),

                        if (!_isAuthenticating)
                          ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 15,
                              ),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(_isLogin ? 'Login' : 'Signup'),
                          ),

                        if (!_isAuthenticating)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isLogin = !_isLogin;
                              });
                            },
                            child: Text(
                              _isLogin
                                  ? 'Create an account'
                                  : 'I already have an account',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String labelText,
    String? hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    required Function(String?) onSaved,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onSaved: onSaved,
      validator: validator,
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label),
      value: value,
      items: items.map((role) {
        return DropdownMenuItem(
          value: role,
          child: Text(role),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

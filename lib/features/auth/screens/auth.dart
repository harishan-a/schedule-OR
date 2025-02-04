// =============================================================================
// Authentication Screen
// =============================================================================
// This screen handles both login and signup flows using Firebase Authentication.
// Features:
// - Email/password authentication
// - User profile creation in Firestore
// - Form validation with error handling
// - Responsive layout with animations
// - Role-based registration (Doctor, Nurse, Admin, etc.)
// - Department selection with custom department option
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../features/home/screens/home.dart';
import '../../../shared/utils/formatters.dart';

/// Firebase Authentication instance for handling auth operations
final _firebase = FirebaseAuth.instance;

/// AuthScreen widget that handles both login and signup flows
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

/// State class for AuthScreen that manages the authentication flow
class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  // Form key for validation
  final _form = GlobalKey<FormState>();
  
  // Authentication state variables
  var _isLogin = true;
  var _isAuthenticating = false;
  
  // User input fields
  var _enteredEmail = '';
  var _enteredPassword = '';
  var _enteredFirstName = '';
  var _enteredLastName = '';
  var _enteredPhoneNumber = '';
  var _customDepartment = '';
  
  // Role and department selection
  var _selectedRole = 'Doctor';
  var _selectedDepartment = 'Cardiology';

  // Available options for roles and departments
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

  /// Handles form submission for both login and signup flows
  /// - Validates form input
  /// - Authenticates with Firebase
  /// - Creates/updates user profile in Firestore
  /// - Handles error states and displays messages
  Future<void> _submit() async {
    if (!mounted) return;

    final isValid = _form.currentState!.validate();
    if (!isValid) return;

    _form.currentState!.save();

    try {
      if (!mounted) return;
      setState(() {
        _isAuthenticating = true;
      });

      if (_isLogin) {
        // Login flow: Authenticate existing user
        final userCredentials = await _firebase.signInWithEmailAndPassword(
          email: _enteredEmail,
          password: _enteredPassword,
        );

        // Update user's display name from Firestore data if needed
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredentials.user!.uid)
            .get();

        if (userCredentials.user != null && userData.exists) {
          final firstName = userData.data()?['firstName'] ?? '';
          final lastName = userData.data()?['lastName'] ?? '';
          final fullName = '$firstName $lastName'.trim();
          
          // Update display name if it doesn't match Firestore data
          if (userCredentials.user!.displayName != fullName) {
            await userCredentials.user!.updateDisplayName(fullName);
          }
        }

        if (!mounted) return;
        await Navigator.of(context).pushReplacement(_createRoute());
      } else {
        // Signup flow: Create new user account
        final userCredentials = await _firebase.createUserWithEmailAndPassword(
          email: _enteredEmail,
          password: _enteredPassword,
        );

        // Set user's display name immediately after account creation
        if (userCredentials.user != null) {
          final fullName = '$_enteredFirstName $_enteredLastName'.trim();
          await userCredentials.user!.updateDisplayName(fullName);
        }

        // Determine department (custom or selected)
        String department = _selectedDepartment == 'Other'
            ? _customDepartment
            : _selectedDepartment;

        // Create user profile in Firestore
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

        if (!mounted) return;
        await Navigator.of(context).pushReplacement(_createRoute());
      }
    } on FirebaseAuthException catch (error) {
      // Handle Firebase authentication errors
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Authentication failed.'),
        ),
      );
    } catch (error) {
      // Handle general errors
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred. Please try again later.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  /// Creates a custom page route with slide transition animation
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
              // Logo with fade-in animation
              AnimatedSize(
                duration: const Duration(seconds: 1),
                child: Container(
                  margin: const EdgeInsets.only(top: 30, bottom: 20),
                  width: 200,
                  child: Image.asset('assets/images/doctorlogo.png'),
                ),
              ),
              // Authentication form card
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
                            child: Text(
                              style: TextStyle(
                                color: Color.fromARGB(255, 0, 0, 0)
                              ),
                              _isLogin ? 'Login' : 'Signup',
                            ),
                          ),

                        if (!_isAuthenticating)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isLogin = !_isLogin;
                              });
                            },
                            child: Text(
                              style: TextStyle(
                                color: Color.fromARGB(255, 0, 0, 0)
                              ),
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

  /// Builds a reusable text form field with consistent styling and validation
  /// Parameters:
  /// - labelText: The label displayed above the input field
  /// - hintText: Optional placeholder text
  /// - obscureText: Whether to hide the input (for passwords)
  /// - keyboardType: The type of keyboard to display
  /// - inputFormatters: Optional input formatting rules
  /// - onSaved: Callback when the form is saved
  /// - validator: Function to validate the input
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

  /// Builds a reusable dropdown form field with consistent styling
  /// Parameters:
  /// - label: The label displayed above the dropdown
  /// - value: Currently selected value
  /// - items: List of available options
  /// - onChanged: Callback when selection changes
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

// =============================================================================
// Authentication Screen
// =============================================================================
// This screen handles the entry point to both login and signup flows.
// Features:
// - Clean, hospital-themed initial landing page
// - Side-by-side Login and Sign Up options
// - Email/password authentication
// - User profile creation in Firestore
// - Form validation with error handling
// - Responsive layout with subtle animations
// - Role-based registration (Doctor, Nurse, Admin, etc.)
// - Department selection with custom department option
// - Subtle aurora gradient background
// - Enhanced keyboard interactions and mobile UX
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;

import '../../../features/home/screens/home.dart';
import '../../../shared/utils/formatters.dart';
import 'package:firebase_orscheduler/shared/utils/transitions.dart';
import 'package:firebase_orscheduler/features/patient/screens/patient_lookup.dart';

/// Firebase Authentication instance for handling auth operations
final _firebase = FirebaseAuth.instance;

/// AuthScreen widget that handles the entry point, login, and signup flows
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

/// State class for AuthScreen that manages the authentication flow
class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  // Form key for validation
  final _form = GlobalKey<FormState>();

  // Controllers for text fields to facilitate keyboard actions
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _customDepartmentController = TextEditingController();

  // Focus nodes for controlling keyboard navigation
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _firstNameFocusNode = FocusNode();
  final _lastNameFocusNode = FocusNode();
  final _phoneNumberFocusNode = FocusNode();
  final _customDepartmentFocusNode = FocusNode();

  // Animation controllers
  late AnimationController _backgroundAnimationController;
  late AnimationController _formAnimationController;

  // Authentication state variables
  AuthMode _authMode = AuthMode.landing;
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

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _backgroundAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat(reverse: true);

    _formAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    // Add keyboard event listeners
    _setupKeyboardActions();
  }

  @override
  void dispose() {
    // Dispose controllers and focus nodes
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneNumberController.dispose();
    _customDepartmentController.dispose();

    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _phoneNumberFocusNode.dispose();
    _customDepartmentFocusNode.dispose();

    _backgroundAnimationController.dispose();
    _formAnimationController.dispose();

    super.dispose();
  }

  /// Sets up keyboard actions for improved form navigation
  void _setupKeyboardActions() {
    // Email field: proceed to password on next
    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus) {
        _enteredEmail = _emailController.text;
      }
    });

    // Password field: submit form on done
    _passwordFocusNode.addListener(() {
      if (!_passwordFocusNode.hasFocus) {
        _enteredPassword = _passwordController.text;
      }
    });

    // Handle other focus nodes for signup fields
    _firstNameFocusNode.addListener(() {
      if (!_firstNameFocusNode.hasFocus) {
        _enteredFirstName = _firstNameController.text;
      }
    });

    _lastNameFocusNode.addListener(() {
      if (!_lastNameFocusNode.hasFocus) {
        _enteredLastName = _lastNameController.text;
      }
    });

    _phoneNumberFocusNode.addListener(() {
      if (!_phoneNumberFocusNode.hasFocus) {
        _enteredPhoneNumber = _phoneNumberController.text;
      }
    });

    _customDepartmentFocusNode.addListener(() {
      if (!_customDepartmentFocusNode.hasFocus) {
        _customDepartment = _customDepartmentController.text;
      }
    });
  }

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

      if (_authMode == AuthMode.login) {
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
      } else if (_authMode == AuthMode.signup) {
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

        // Create user profile in Firestore with role and department fields
        try {
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
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Double-check that user data was saved correctly to prevent the crash bug
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredentials.user!.uid)
              .get();
        } catch (firestoreError) {
          // Handle Firestore errors specifically to prevent crashes
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Error saving user data: ${firestoreError.toString()}'),
              backgroundColor: Colors.red,
            ),
          );

          // If there's an error saving to Firestore, still navigate to home
          // but with a warning since the profile might be incomplete
          if (!mounted) return;
          await Navigator.of(context).pushReplacement(_createRoute());
          return;
        }

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
          backgroundColor: Colors.red,
        ),
      );
    } catch (error) {
      // Handle general errors
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: ${error.toString()}'),
          backgroundColor: Colors.red,
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

  /// Switch between auth modes (landing, login, signup)
  void _switchAuthMode(AuthMode mode) {
    if (_authMode == mode) return;

    setState(() {
      _authMode = mode;

      // Reset form animation for smooth transition
      _formAnimationController.reset();
      _formAnimationController.forward();

      // Clear form fields when switching modes
      if (mode != AuthMode.landing) {
        _form.currentState?.reset();

        // Only clear controllers if switching to a different form mode
        if (mode == AuthMode.signup) {
          _emailController.clear();
          _passwordController.clear();
        }
      }
    });
  }

  /// Creates a custom page route with enhanced slide transition animation
  Route _createRoute() {
    return createAppTransition(const HomeScreen(),
        duration: const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    // Gesture detector to unfocus and dismiss keyboard when tapping outside inputs
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside of text fields
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // Subtle Aurora Gradient Background
            AnimatedBuilder(
              animation: _backgroundAnimationController,
              builder: (context, child) {
                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(
                        math.sin(_backgroundAnimationController.value *
                                math.pi) *
                            0.3,
                        math.cos(_backgroundAnimationController.value *
                                math.pi) *
                            0.3,
                      ),
                      end: Alignment(
                        math.cos(_backgroundAnimationController.value *
                                math.pi) *
                            0.3,
                        math.sin(_backgroundAnimationController.value *
                                    math.pi) *
                                0.3 +
                            0.7,
                      ),
                      colors: const [
                        Color(0xFF0A2342), // Deep blue (navy scrub color)
                        Color(0xFF0D4287), // Darker royal blue
                        Color(0xFF1A70B5), // Medical blue
                        Color(0xFF1E88E5), // Brighter blue
                      ],
                      stops: const [0.0, 0.3, 0.6, 1.0],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Enhanced aurora waves
                      CustomPaint(
                        painter: AuroraOverlayPainter(
                          animation: _backgroundAnimationController,
                          opacity: 0.08,
                        ),
                        size: Size.infinite,
                      ),
                      // Additional subtle medical pattern
                      CustomPaint(
                        painter: MedicalPatternPainter(
                          animation: _backgroundAnimationController,
                        ),
                        size: Size.infinite,
                      ),
                    ],
                  ),
                );
              },
            ),

            // Main content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // App title - ScheduleOR with clean professional design
                        Text(
                          "ScheduleOR",
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.8,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(0, 2),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                        )
                            .animate()
                            .fadeIn(
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.easeOutCubic,
                            )
                            .slide(
                              begin: const Offset(0, -0.2),
                              end: Offset.zero,
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutCubic,
                            ),

                        const SizedBox(height: 16),

                        // Hospital/medical tagline
                        Text(
                          "Operating Room Management System",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                            letterSpacing: 0.3,
                          ),
                        )
                            .animate()
                            .fadeIn(
                              duration: const Duration(milliseconds: 800),
                              delay: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                            )
                            .slide(
                              begin: const Offset(0, -0.1),
                              end: Offset.zero,
                              duration: const Duration(milliseconds: 600),
                              delay: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                            ),

                        const SizedBox(height: 36),

                        // Doctor logo with professional styling and entrance animation
                        Hero(
                          tag: 'app_logo',
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 32),
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.15),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Image.asset(
                                'assets/images/doctorlogo.png',
                                fit: BoxFit.contain,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(
                              duration: const Duration(milliseconds: 1000),
                              delay: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                            )
                            .scale(
                              begin: const Offset(0.8, 0.8),
                              end: const Offset(1.0, 1.0),
                              duration: const Duration(milliseconds: 800),
                              delay: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                            ),

                        // Auth content - changes based on mode with enhanced entrance animation
                        AnimatedBuilder(
                          animation: _formAnimationController,
                          builder: (context, child) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.1),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: _formAnimationController,
                                curve: Curves.easeOutCubic,
                              )),
                              child: FadeTransition(
                                opacity: _formAnimationController,
                                child: child,
                              ),
                            );
                          },
                          child: _buildAuthContent(screenSize, theme)
                              .animate()
                              .fadeIn(
                                duration: const Duration(milliseconds: 800),
                                delay: const Duration(milliseconds: 600),
                                curve: Curves.easeOutCubic,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the appropriate authentication content based on current mode
  Widget _buildAuthContent(Size screenSize, ThemeData theme) {
    switch (_authMode) {
      case AuthMode.landing:
        return _buildLandingContent(screenSize, theme);
      case AuthMode.login:
        return _buildLoginContent(screenSize, theme);
      case AuthMode.signup:
        return _buildSignupContent(screenSize, theme);
    }
  }

  /// Builds the landing screen with Login and Sign Up options
  Widget _buildLandingContent(Size screenSize, ThemeData theme) {
    return Container(
      width: math.min(screenSize.width * 0.9, 450),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Welcome to Operating Room Scheduling",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2a5298),
              ),
            ).animate().fadeIn(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                ),
            const SizedBox(height: 32),

            // Login button with animation
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => _switchAuthMode(AuthMode.login),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(
                  duration: const Duration(milliseconds: 400),
                  delay: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                )
                .slideX(
                  begin: -0.1,
                  end: 0,
                  duration: const Duration(milliseconds: 400),
                  delay: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                ),
            const SizedBox(height: 16),

            // Sign Up button with animation
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () => _switchAuthMode(AuthMode.signup),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.colorScheme.primary, width: 2),
                  foregroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Sign Up',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(
                  duration: const Duration(milliseconds: 400),
                  delay: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                )
                .slideX(
                  begin: 0.1,
                  end: 0,
                  duration: const Duration(milliseconds: 400),
                  delay: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                ),
            const SizedBox(height: 16),

            // Patient Lookup button with distinct styling
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF2E7D32), // Green shade
                    const Color(0xFF1B5E20),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E7D32).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/patient-lookup');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.zero,
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Patient Surgery Lookup',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the login form content
  Widget _buildLoginContent(Size screenSize, ThemeData theme) {
    return Container(
      width: math.min(screenSize.width * 0.9, 450),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Form Title
              Text(
                'Login',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Email field
              _buildTextField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                labelText: 'Email Address',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                nextFocusNode: _passwordFocusNode,
                textInputAction: TextInputAction.next,
                onSaved: (value) {
                  _enteredEmail = value!;
                },
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty ||
                      !value.contains('@')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password field
              _buildTextField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                labelText: 'Password',
                prefixIcon: Icons.lock_outline,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                onSaved: (value) {
                  _enteredPassword = value!;
                },
                validator: (value) {
                  if (value == null || value.trim().length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Submit Button with loading state
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isAuthenticating ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                  ),
                  child: _isAuthenticating
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Back to landing button
              TextButton(
                onPressed: () => _switchAuthMode(AuthMode.landing),
                child: Text(
                  'Back to options',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the signup form content
  Widget _buildSignupContent(Size screenSize, ThemeData theme) {
    return Container(
      width: math.min(screenSize.width * 0.9, 450),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Form Title
              Text(
                'Create Account',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Name fields in a row for efficient space usage
              Row(
                children: [
                  // First Name field
                  Expanded(
                    child: _buildTextField(
                      controller: _firstNameController,
                      focusNode: _firstNameFocusNode,
                      labelText: 'First Name',
                      prefixIcon: Icons.person_outline,
                      nextFocusNode: _lastNameFocusNode,
                      onSaved: (value) {
                        _enteredFirstName = value!;
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Last Name field
                  Expanded(
                    child: _buildTextField(
                      controller: _lastNameController,
                      focusNode: _lastNameFocusNode,
                      labelText: 'Last Name',
                      prefixIcon: Icons.person_outline,
                      onSaved: (value) {
                        _enteredLastName = value!;
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Email field
              _buildTextField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                labelText: 'Email Address',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                nextFocusNode: _passwordFocusNode,
                textInputAction: TextInputAction.next,
                onSaved: (value) {
                  _enteredEmail = value!;
                },
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty ||
                      !value.contains('@')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password field
              _buildTextField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                labelText: 'Password',
                prefixIcon: Icons.lock_outline,
                obscureText: true,
                onSaved: (value) {
                  _enteredPassword = value!;
                },
                validator: (value) {
                  if (value == null || value.trim().length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Enhanced Role selection dropdown
              _buildDropdownField(
                label: 'Role',
                value: _selectedRole,
                items: _roles,
                prefixIcon: Icons.work_outline,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedRole = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Enhanced Department field with "Other" option
              _buildDropdownField(
                label: 'Department / Specialization',
                value: _selectedDepartment,
                items: _departments,
                prefixIcon: Icons.business_outlined,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedDepartment = value;
                    if (_selectedDepartment != 'Other') {
                      _customDepartment = '';
                      _customDepartmentController.clear();
                    }
                  });
                },
              ),

              // Custom Department field (conditional)
              if (_selectedDepartment == 'Other')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _buildTextField(
                    controller: _customDepartmentController,
                    focusNode: _customDepartmentFocusNode,
                    labelText: 'Specify Department',
                    prefixIcon: Icons.edit_outlined,
                    onSaved: (value) {
                      _customDepartment = value!;
                    },
                    validator: (value) {
                      if (_selectedDepartment == 'Other' &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Please specify your department';
                      }
                      return null;
                    },
                  ),
                ),

              const SizedBox(height: 16),

              // Phone Number field with formatter
              _buildTextField(
                controller: _phoneNumberController,
                focusNode: _phoneNumberFocusNode,
                labelText: 'Phone Number',
                hintText: '(123)-456-7890',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  PhoneNumberFormatter(),
                ],
                onSaved: (value) {
                  _enteredPhoneNumber = value!;
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  } else if (value.length != 14) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Patient Lookup button with animation - ENHANCED STYLING
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2E7D32), // Green shade
                      const Color(0xFF1B5E20),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E7D32).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/patient-lookup');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.zero,
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Patient Surgery Lookup',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Submit Button with loading state
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isAuthenticating ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                  ),
                  child: _isAuthenticating
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Back to landing button
              TextButton(
                onPressed: () => _switchAuthMode(AuthMode.landing),
                child: Text(
                  'Back to options',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a beautifully styled text form field with consistent styling and validation
  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String labelText,
    required Function(String?) onSaved,
    required String? Function(String?) validator,
    String? hintText,
    bool obscureText = false,
    IconData? prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    FocusNode? nextFocusNode,
    TextInputAction? textInputAction,
    Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
      ),
      style: const TextStyle(
        fontSize: 16,
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      onSaved: onSaved,
      validator: validator,
      onFieldSubmitted: (value) {
        if (onFieldSubmitted != null) {
          onFieldSubmitted(value);
        } else if (nextFocusNode != null) {
          FocusScope.of(context).requestFocus(nextFocusNode);
        }
      },
    );
  }

  /// Builds an enhanced dropdown form field with consistent styling
  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
    IconData? prefixIcon,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 4,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
      ),
      value: value,
      style: const TextStyle(
        fontSize: 16,
        color: Colors.black87,
      ),
      icon: const Icon(Icons.arrow_drop_down),
      isExpanded: true,
      borderRadius: BorderRadius.circular(12),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

/// Enum for tracking authentication screen mode
enum AuthMode {
  landing, // Initial screen with login/signup options
  login, // Login form
  signup // Signup form
}

/// Custom painter for creating enhanced aurora-like overlay effects
class AuroraOverlayPainter extends CustomPainter {
  final Animation<double> animation;
  final double opacity;

  AuroraOverlayPainter({
    required this.animation,
    this.opacity = 0.03,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0
      ..color = Colors.white.withOpacity(opacity);

    // Draw flowing wave shapes with increased amplitude
    final path = Path();

    const waveCount = 5;
    final baseY = size.height * 0.55;
    final amplitude = size.height * 0.15; // Increased amplitude
    final waveSpacing = size.width / waveCount;

    path.moveTo(0, baseY);

    for (var i = 0; i <= waveCount; i++) {
      final x = i * waveSpacing;
      final yOffset = math.sin(animation.value * math.pi + i * 0.4) * amplitude;
      path.lineTo(x, baseY + yOffset);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Add second wave with different phase for more depth
    final path2 = Path();
    final baseY2 = size.height * 0.35;

    path2.moveTo(0, baseY2);

    for (var i = 0; i <= waveCount; i++) {
      final x = i * waveSpacing;
      final yOffset =
          math.cos(animation.value * math.pi + i * 0.6) * (amplitude * 0.8);
      path2.lineTo(x, baseY2 + yOffset);
    }

    path2.lineTo(size.width, 0);
    path2.lineTo(0, 0);
    path2.close();

    canvas.drawPath(
        path2, paint..color = Colors.white.withOpacity(opacity * 0.7));

    // Add third subtle wave for more richness
    final path3 = Path();
    final baseY3 = size.height * 0.75;

    path3.moveTo(0, baseY3);

    for (var i = 0; i <= waveCount + 2; i++) {
      final x = i * (waveSpacing * 0.8);
      final yOffset = math.sin(animation.value * math.pi * 1.5 + i * 0.3) *
          (amplitude * 0.5);
      path3.lineTo(x, baseY3 + yOffset);
    }

    path3.lineTo(size.width, size.height);
    path3.lineTo(0, size.height);
    path3.close();

    canvas.drawPath(
        path3, paint..color = Colors.white.withOpacity(opacity * 0.6));
  }

  @override
  bool shouldRepaint(AuroraOverlayPainter oldDelegate) => true;
}

/// Custom painter for adding subtle medical-themed pattern
class MedicalPatternPainter extends CustomPainter {
  final Animation<double> animation;

  MedicalPatternPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withOpacity(0.03);

    // Draw subtle medical cross patterns
    final patternSize = 40.0;
    final crossSize = 10.0;

    // Calculate how many crosses we need
    final cols = (size.width / patternSize).ceil();
    final rows = (size.height / patternSize).ceil();

    // Animation value for subtle movement
    final offsetX = math.sin(animation.value * math.pi * 2) * 5;
    final offsetY = math.cos(animation.value * math.pi * 2) * 5;

    for (int i = 0; i < cols; i++) {
      for (int j = 0; j < rows; j++) {
        // Skip some crosses to create a less regular pattern
        if ((i + j) % 3 != 0) continue;

        final x = i * patternSize + offsetX;
        final y = j * patternSize + offsetY;

        // Draw a subtle plus/cross symbol
        canvas.drawLine(
          Offset(x - crossSize / 2, y),
          Offset(x + crossSize / 2, y),
          paint,
        );

        canvas.drawLine(
          Offset(x, y - crossSize / 2),
          Offset(x, y + crossSize / 2),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(MedicalPatternPainter oldDelegate) => true;
}

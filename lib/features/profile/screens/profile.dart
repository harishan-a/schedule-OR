// =============================================================================
// Profile Screen
// =============================================================================
// A modern, unified screen that displays and manages all user profile information:
// - View mode: Shows profile as others would see it
// - Edit mode: Allows editing personal information
// - Role and Department selection with proper dropdowns
// - Security features
//
// Features:
// - Distinct view/edit modes
// - Proper field validation
// - Beautiful profile presentation
// - Consistency with signup flow
// =============================================================================

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:firebase_orscheduler/shared/widgets/custom_navigation_bar.dart';
import 'package:firebase_orscheduler/shared/widgets/user_avatar.dart';
import 'package:firebase_orscheduler/shared/providers/user_profile_provider.dart';
import 'package:firebase_orscheduler/features/profile/utils/platform_image_handler.dart';
import 'package:firebase_orscheduler/config/feature_flags.dart';

// Data class for info items
class InfoItem {
  final IconData icon;
  final String label;
  final String value;

  InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

/// A modern screen widget that manages all user profile functionality
class ProfileScreen extends StatefulWidget {
  final bool isTestMode;
  final String? userId;
  final bool fromMoreScreen;

  const ProfileScreen({
    Key? key,
    this.isTestMode = false,
    this.userId,
    this.fromMoreScreen = false,
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // UI state management
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditMode = false;
  bool _isUploadingImage = false;

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Current user
  User? _currentUser;
  String? _userId;

  // Text editing controllers for form fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  // Original values to detect changes
  String _originalFirstName = '';
  String _originalLastName = '';
  String _originalPhone = '';
  String _originalEmail = '';
  String _originalRole = '';
  String _originalDepartment = '';
  String? _originalProfileImageUrl;
  String? _originalDefaultAvatar;
  String _originalOtherRole = '';
  String _originalOtherDepartment = '';

  // Dropdown values
  String _selectedRole = '';
  String _selectedDepartment = '';

  // Profile image
  String? _profileImageUrl;
  File? _imageFile;
  String? _selectedDefaultAvatar;

  // Dropdown options - these should match your signup page options
  final List<String> _roleOptions = [
    'Doctor',
    'Nurse',
    'Admin',
    'Surgical Coordinator',
    'Technologist',
    'Other'
  ];

  final List<String> _departmentOptions = [
    'Cardiology',
    'Neurology',
    'Radiology',
    'Orthopedics',
    'Other'
  ];

  // Default avatar options
  final List<String> _defaultAvatars = [
    'assets/avatars/avatar1.png',
    'assets/avatars/avatar2.png',
    'assets/avatars/avatar3.png',
    'assets/avatars/avatar4.png',
    'assets/avatars/avatar5.png',
  ];

  // Navigation state
  int _selectedIndex = 5; // Default to More tab if from more screen

  // Additional controllers for custom role and department
  final _otherRoleController = TextEditingController();
  final _otherDepartmentController = TextEditingController();

  // Instance of platform-specific image handler
  late final _imageHandler = getProfileImageHandler(context);

  @override
  void initState() {
    super.initState();
    // Only set the selected index if we're coming from the more screen
    if (widget.fromMoreScreen) {
      _selectedIndex = 5; // More tab index
    }
    _loadUserData();
  }

  @override
  void dispose() {
    // Clean up the controllers
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _otherRoleController.dispose();
    _otherDepartmentController.dispose();
    super.dispose();
  }

  /// Loads user profile data from Firestore
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    if (widget.isTestMode) {
      setState(() {
        _firstNameController.text = 'Test';
        _lastNameController.text = 'User';
        _phoneController.text = '(000) 000-0000';
        _emailController.text = 'test@example.com';
        _selectedRole = _roleOptions[0];
        _selectedDepartment = _departmentOptions[0];
        _profileImageUrl = null;
        _isLoading = false;

        // Save original values for change detection
        _saveOriginalValues();
      });
      return;
    }

    try {
      _currentUser = FirebaseAuth.instance.currentUser;

      if (_currentUser != null) {
        _userId = _currentUser!.uid;
        _emailController.text = _currentUser!.email ?? '';

        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .get();

        if (userData.exists) {
          setState(() {
            _firstNameController.text = userData['firstName'] ?? '';
            _lastNameController.text = userData['lastName'] ?? '';
            _phoneController.text = userData['phoneNumber'] ?? '';

            // Handle image URL
            _profileImageUrl = userData['profileImageUrl'];
            _selectedDefaultAvatar = userData['selectedDefaultAvatar'];

            // Get role - check if it's in standard options or custom
            String role = userData['role'] ?? '';
            if (role.isNotEmpty) {
              if (_roleOptions.contains(role)) {
                _selectedRole = role;
                _otherRoleController.clear();
              } else {
                _selectedRole = 'Other';
                _otherRoleController.text = role;
              }
            } else if (_roleOptions.isNotEmpty) {
              _selectedRole = _roleOptions.first;
            }

            // Get department - check if it's in standard options or custom
            String department = userData['department'] ?? '';
            if (department.isNotEmpty) {
              if (_departmentOptions.contains(department)) {
                _selectedDepartment = department;
                _otherDepartmentController.clear();
              } else {
                _selectedDepartment = 'Other';
                _otherDepartmentController.text = department;
              }
            } else if (_departmentOptions.isNotEmpty) {
              _selectedDepartment = _departmentOptions.first;
            }

            // Save original values for change detection
            _saveOriginalValues();

            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        // Handle no user logged in
        setState(() => _isLoading = false);
      }
    } catch (e) {
      // Handle errors
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    }
  }

  // Save original values for change detection
  void _saveOriginalValues() {
    _originalFirstName = _firstNameController.text;
    _originalLastName = _lastNameController.text;
    _originalPhone = _phoneController.text;
    _originalEmail = _emailController.text;
    _originalRole = _selectedRole;
    _originalDepartment = _selectedDepartment;
    _originalProfileImageUrl = _profileImageUrl;
    _originalDefaultAvatar = _selectedDefaultAvatar;
    _originalOtherRole = _otherRoleController.text;
    _originalOtherDepartment = _otherDepartmentController.text;
  }

  // Check if any form values have changed
  bool _hasFormChanged() {
    if (_imageFile != null) return true;

    if (_originalFirstName != _firstNameController.text) return true;
    if (_originalLastName != _lastNameController.text) return true;
    if (_originalPhone != _phoneController.text) return true;
    if (_originalEmail != _emailController.text) return true;
    if (_originalRole != _selectedRole) return true;
    if (_originalDepartment != _selectedDepartment) return true;

    // Check custom fields only if relevant
    if (_selectedRole == 'Other' &&
        _originalOtherRole != _otherRoleController.text) return true;
    if (_selectedDepartment == 'Other' &&
        _originalOtherDepartment != _otherDepartmentController.text)
      return true;

    // Check if avatar changed
    if (_originalProfileImageUrl != _profileImageUrl) return true;
    if (_originalDefaultAvatar != _selectedDefaultAvatar) return true;

    return false;
  }

  // Check if name contains invalid characters
  bool _containsInvalidCharacters(String name) {
    // Regex to check for invalid characters (allows letters, spaces, hyphens, and apostrophes)
    final RegExp validNameRegex = RegExp(r"^[a-zA-Z\s\-']+$");
    return !validNameRegex.hasMatch(name);
  }

  /// Saves user profile changes to Firestore
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if nothing has changed
    if (!_hasFormChanged()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No changes to save'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (widget.isTestMode) {
      setState(() => _isSaving = true);
      await Future.delayed(
          const Duration(seconds: 1)); // Simulate network delay
      setState(() {
        _isSaving = false;
        _isEditMode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully (Test Mode)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Upload profile image if selected
      String? newProfileImageUrl = _profileImageUrl;

      if (_imageFile != null) {
        // Show a snackbar to indicate upload is in progress
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading profile image...'),
            behavior: SnackBarBehavior.floating,
          ),
        );

        newProfileImageUrl = await _uploadProfileImage();

        // If upload failed but we were trying to update the image
        if (newProfileImageUrl == null && _imageFile != null) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Failed to upload profile image. Please try again.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }

      // Determine the actual role value to save
      String roleToSave = _selectedRole;
      if (_selectedRole == 'Other' && _otherRoleController.text.isNotEmpty) {
        roleToSave = _otherRoleController.text;
      }

      // Determine the actual department value to save
      String departmentToSave = _selectedDepartment;
      if (_selectedDepartment == 'Other' &&
          _otherDepartmentController.text.isNotEmpty) {
        departmentToSave = _otherDepartmentController.text;
      }

      // Update Firestore
      final userData = {
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'phoneNumber': _phoneController.text,
        'role': roleToSave,
        'department': departmentToSave,
        'profileImageUrl': newProfileImageUrl,
        'selectedDefaultAvatar': _selectedDefaultAvatar,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .update(userData);

      // Update local state
      setState(() {
        _profileImageUrl = newProfileImageUrl;
        _imageFile = null;
        // Save new original values
        _saveOriginalValues();
      });

      // Update email if changed
      if (_currentUser != null &&
          _currentUser!.email != _emailController.text) {
        try {
          await _currentUser!.updateEmail(_emailController.text);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Email update requires recent authentication: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      // Reload user profile in the provider
      final userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: false);
      await userProfileProvider.loadUserProfile();

      setState(() {
        _isSaving = false;
        _isEditMode = false;
      });

      // Show success message with animation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Profile updated successfully'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Upload profile image to Firebase Storage
  Future<String?> _uploadProfileImage() async {
    if (_imageFile == null) return null;

    setState(() => _isUploadingImage = true);

    try {
      // Check file size before uploading
      final fileSize = await _imageFile!.length();
      if (fileSize > 5 * 1024 * 1024) {
        // 5MB
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Image size exceeds 5MB limit. Please choose a smaller image.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
        return null;
      }

      // Generate a unique file name with user ID prefix for security
      final fileName =
          '${_userId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(_imageFile!.path)}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(fileName);

      // Upload with metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': _userId ?? '',
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      // Create a progress tracker
      double _uploadProgress = 0;
      bool _isUploading = true;

      // Show progress indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Uploading Image'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Please wait while your image is uploaded...'),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: _uploadProgress),
                    const SizedBox(height: 8),
                    Text('${(_uploadProgress * 100).toStringAsFixed(0)}%'),
                  ],
                ),
              );
            },
          );
        },
      );

      // Start upload with progress tracking
      final uploadTask = ref.putFile(_imageFile!, metadata);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        // Force dialog rebuild
        if (mounted && _isUploading) {
          setState(() {});
        }
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;
      _isUploading = false;

      // Close progress dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      final downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() => _isUploadingImage = false);
      return downloadUrl;
    } catch (e) {
      // Close progress dialog if open
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // Dialog might not be open, ignore error
        }
      }

      setState(() => _isUploadingImage = false);

      // Handle specific Firebase errors
      String errorMessage = 'Error uploading image: ';
      if (e.toString().contains('network')) {
        errorMessage +=
            'Network connection issue. Please check your connection and try again.';
      } else if (e.toString().contains('permission-denied')) {
        errorMessage +=
            'Permission denied. You may not have access to upload images.';
      } else if (e.toString().contains('quota-exceeded')) {
        errorMessage += 'Storage quota exceeded.';
      } else {
        errorMessage += e.toString();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'RETRY',
            onPressed: () => _uploadProfileImage(),
            textColor: Colors.white,
          ),
        ),
      );
      return null;
    }
  }

  // Pick image from camera
  Future<void> _pickImageFromCamera() async {
    try {
      final imageFile = await _imageHandler.pickImageFromCamera();
      if (imageFile != null) {
        setState(() {
          _imageFile = imageFile;
          _selectedDefaultAvatar = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  // Pick image from gallery
  Future<void> _pickImageFromGallery() async {
    try {
      final imageFile = await _imageHandler.pickImage();
      if (imageFile != null) {
        setState(() {
          _imageFile = imageFile;
          _selectedDefaultAvatar = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  // Show options for selecting a profile image
  Future<void> _showImageSourceOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (_imageHandler.isCameraAvailable())
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromCamera();
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Choose default avatar'),
              onTap: () {
                Navigator.pop(context);
                _showDefaultAvatarSelection();
              },
            ),
            if (_profileImageUrl != null ||
                _selectedDefaultAvatar != null ||
                _imageFile != null)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Remove profile image',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removeProfileImage();
                },
              ),
          ],
        ),
      ),
    );
  }

  // Show default avatar selection dialog
  Future<void> _showDefaultAvatarSelection() async {
    final List<String> defaultAvatars = [
      'assets/avatars/avatar1.png',
      'assets/avatars/avatar2.png',
      'assets/avatars/avatar3.png',
      'assets/avatars/avatar4.png',
      'assets/avatars/avatar5.png',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Default Avatar'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: defaultAvatars.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDefaultAvatar = defaultAvatars[index];
                    _imageFile = null;
                    _profileImageUrl = null;
                  });
                  Navigator.pop(context);
                },
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: AssetImage(defaultAvatars[index]),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Remove the profile image
  void _removeProfileImage() {
    setState(() {
      _profileImageUrl = null;
      _selectedDefaultAvatar = null;
      _imageFile = null;
    });

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile image removed'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Profile' : 'My Profile'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isEditMode)
            TextButton.icon(
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
              onPressed: () {
                setState(() => _isEditMode = false);
                _loadUserData(); // Reload original data
              },
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Edit'),
              onPressed: () => setState(() => _isEditMode = true),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary,
              ),
            )
          : _isEditMode
              ? _buildEditMode()
              : _buildViewMode(),
      // Only show navigation bar if coming from More screen
      bottomNavigationBar: widget.fromMoreScreen
          ? CustomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            )
          : null,
    );
  }

  // VIEW MODE: How others see the profile
  Widget _buildViewMode() {
    final fullName = '${_firstNameController.text} ${_lastNameController.text}';
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final role =
        _selectedRole == 'Other' && _otherRoleController.text.isNotEmpty
            ? _otherRoleController.text
            : _selectedRole;
    final department = _selectedDepartment == 'Other' &&
            _otherDepartmentController.text.isNotEmpty
        ? _otherDepartmentController.text
        : _selectedDepartment;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header with avatar
          Center(
            child: Column(
              children: [
                UserAvatar(
                  radius: 60,
                  name: fullName,
                  imageUrl: _profileImageUrl,
                  assetPath: _selectedDefaultAvatar,
                  backgroundColor: colorScheme.primary,
                  showBorder: true,
                  borderColor: colorScheme.surface,
                  borderWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  fullName,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _emailController.text,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (role.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Chip(
                      label: Text(role),
                      backgroundColor: colorScheme.primaryContainer,
                      labelStyle:
                          TextStyle(color: colorScheme.onPrimaryContainer),
                    ),
                  ),
                if (department.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Chip(
                      label: Text(department),
                      backgroundColor: colorScheme.secondaryContainer,
                      labelStyle:
                          TextStyle(color: colorScheme.onSecondaryContainer),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Contact Information
          _buildInfoCard(
            context: context,
            title: 'Contact Information',
            icon: Icons.contact_mail,
            items: [
              InfoItem(
                icon: Icons.email_outlined,
                label: 'Email',
                value: _emailController.text,
              ),
              InfoItem(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: _phoneController.text,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Security Section
          _buildActionCard(
            context: context,
            title: 'Security',
            icon: Icons.security,
            actionText: 'Reset Password',
            actionIcon: Icons.lock_reset,
            onTap: _showChangePasswordDialog,
          ),

          // Responsive layout for larger screens
          LayoutBuilder(
            builder: (context, constraints) {
              // On wider screens, add additional info
              if (constraints.maxWidth > 600) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'User Information',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          ListTile(
                            leading: Icon(Icons.verified_user,
                                color: colorScheme.primary),
                            title: Text('Role',
                                style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant)),
                            subtitle: Text(
                              role.isEmpty ? 'Not specified' : role,
                              style: textTheme.titleSmall,
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            leading: Icon(Icons.business,
                                color: colorScheme.primary),
                            title: Text('Department',
                                style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant)),
                            subtitle: Text(
                              department.isEmpty ? 'Not specified' : department,
                              style: textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink(); // No additional content on mobile
            },
          ),
        ],
      ),
    );
  }

  // EDIT MODE: Form to edit profile info
  Widget _buildEditMode() {
    final fullName = '${_firstNameController.text} ${_lastNameController.text}';
    final colorScheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile header with editable avatar
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      UserAvatar(
                        radius: 60,
                        name: fullName,
                        imageUrl: _profileImageUrl,
                        file: _imageFile,
                        assetPath: _selectedDefaultAvatar,
                        backgroundColor: colorScheme.primary,
                        showBorder: true,
                        borderColor: colorScheme.surface,
                        borderWidth: 3,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt),
                            color: colorScheme.onPrimary,
                            onPressed:
                                _isSaving ? null : _showImageSourceOptions,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Profile editor section
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section title
                    Row(
                      children: [
                        Icon(Icons.person_outline, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Personal Information',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // First name with validation
                    _buildFirstNameField(),
                    const SizedBox(height: 16),

                    // Last name with validation
                    _buildLastNameField(),
                    const SizedBox(height: 16),

                    // Email with validation
                    _buildEmailField(),
                    const SizedBox(height: 16),

                    // Phone with validation and formatting
                    _buildPhoneField(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Professional Information Section
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.business_center_outlined,
                            color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Professional Information',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Role Selection - Dropdown with "Other" option
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Role',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.work_outline),
                            errorStyle: TextStyle(color: colorScheme.error),
                          ),
                          value: _selectedRole.isNotEmpty &&
                                  _roleOptions.contains(_selectedRole)
                              ? _selectedRole
                              : 'Other',
                          items: _roleOptions.map((String role) {
                            return DropdownMenuItem<String>(
                              value: role,
                              child: Text(role),
                            );
                          }).toList(),
                          onChanged: _isSaving
                              ? null
                              : (String? newValue) {
                                  setState(() {
                                    _selectedRole = newValue ?? '';
                                    // If "Other" is not selected, clear the custom role field
                                    if (_selectedRole != 'Other') {
                                      _otherRoleController.clear();
                                    }
                                  });
                                },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a role';
                            }

                            // If "Other" is selected, ensure custom role is provided
                            if (value == 'Other' &&
                                _otherRoleController.text.isEmpty) {
                              return 'Please specify your role';
                            }
                            return null;
                          },
                        ),

                        // Show custom role input if "Other" is selected
                        if (_selectedRole == 'Other') ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _otherRoleController,
                            enabled: !_isSaving,
                            decoration: InputDecoration(
                              labelText: 'Specify Role',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.edit_outlined),
                              errorStyle: TextStyle(color: colorScheme.error),
                            ),
                            validator: (value) {
                              if (_selectedRole == 'Other' &&
                                  (value == null || value.isEmpty)) {
                                return 'Please specify your role';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Department Selection - Dropdown with "Other" option
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Department',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.business_outlined),
                            errorStyle: TextStyle(color: colorScheme.error),
                          ),
                          value: _selectedDepartment.isNotEmpty &&
                                  _departmentOptions
                                      .contains(_selectedDepartment)
                              ? _selectedDepartment
                              : 'Other',
                          items: _departmentOptions.map((String department) {
                            return DropdownMenuItem<String>(
                              value: department,
                              child: Text(department),
                            );
                          }).toList(),
                          onChanged: _isSaving
                              ? null
                              : (String? newValue) {
                                  setState(() {
                                    _selectedDepartment = newValue ?? '';
                                    // If "Other" is not selected, clear the custom department field
                                    if (_selectedDepartment != 'Other') {
                                      _otherDepartmentController.clear();
                                    }
                                  });
                                },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a department';
                            }

                            // If "Other" is selected, ensure custom department is provided
                            if (value == 'Other' &&
                                _otherDepartmentController.text.isEmpty) {
                              return 'Please specify your department';
                            }
                            return null;
                          },
                        ),

                        // Show custom department input if "Other" is selected
                        if (_selectedDepartment == 'Other') ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _otherDepartmentController,
                            enabled: !_isSaving,
                            decoration: InputDecoration(
                              labelText: 'Custom Department',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.edit_outlined),
                              errorStyle: TextStyle(color: colorScheme.error),
                            ),
                            validator: (value) {
                              if (_selectedDepartment == 'Other' &&
                                  (value == null || value.isEmpty)) {
                                return 'Please specify your department';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                icon: _isSaving
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: colorScheme.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                onPressed:
                    _isSaving || !_hasFormChanged() ? null : _saveChanges,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build info cards
  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<InfoItem> items,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            for (var item in items) ...[
              ListTile(
                leading: Icon(item.icon, color: colorScheme.primary),
                title: Text(item.label,
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
                subtitle: Text(
                  item.value,
                  style: textTheme.titleSmall,
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              if (item != items.last) const Divider(),
            ],
          ],
        ),
      ),
    );
  }

  // Helper method to build action cards
  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String actionText,
    required IconData actionIcon,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            ListTile(
              leading: Icon(actionIcon, color: colorScheme.primary),
              title: Text(actionText),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              contentPadding: EdgeInsets.zero,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a dialog to confirm sending a password reset email
  void _showChangePasswordDialog() {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_reset, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Reset Password'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A password reset email will be sent to:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _emailController.text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'You will receive an email with instructions to reset your password.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.email_outlined),
            onPressed: () async {
              try {
                if (!widget.isTestMode) {
                  await FirebaseAuth.instance.sendPasswordResetEmail(
                    email: _emailController.text,
                  );
                }

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text('Password reset email sent'),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.error, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              'Error sending reset email: ${e.toString().contains('firebase') ? 'Check your internet connection' : e}'),
                        ),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            label: const Text('Send Reset Email'),
          ),
        ],
      ),
    );
  }

  // First name input field with validation
  TextFormField _buildFirstNameField() {
    return TextFormField(
      controller: _firstNameController,
      decoration: InputDecoration(
        labelText: 'First Name',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.person_outline),
        errorStyle: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      keyboardType: TextInputType.name,
      textCapitalization: TextCapitalization.words,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'First name is required';
        }
        if (_containsInvalidCharacters(value)) {
          return 'Name can only contain letters, spaces, hyphens and apostrophes';
        }
        if (value.length > 50) {
          return 'Name is too long (max 50 characters)';
        }
        return null;
      },
    );
  }

  // Last name input field with validation
  TextFormField _buildLastNameField() {
    return TextFormField(
      controller: _lastNameController,
      decoration: InputDecoration(
        labelText: 'Last Name',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.person_outline),
        errorStyle: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      keyboardType: TextInputType.name,
      textCapitalization: TextCapitalization.words,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Last name is required';
        }
        if (_containsInvalidCharacters(value)) {
          return 'Name can only contain letters, spaces, hyphens and apostrophes';
        }
        if (value.length > 50) {
          return 'Name is too long (max 50 characters)';
        }
        return null;
      },
    );
  }

  // Email input field with validation
  TextFormField _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: InputDecoration(
        labelText: 'Email',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.email_outlined),
        errorStyle: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Email is required';
        }
        final emailRegex =
            RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
        if (!emailRegex.hasMatch(value)) {
          return 'Please enter a valid email address';
        }
        return null;
      },
    );
  }

  // Phone number input field with validation and formatting
  TextFormField _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      decoration: InputDecoration(
        labelText: 'Phone Number',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.phone_outlined),
        hintText: '(555) 555-5555',
        errorStyle: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      keyboardType: TextInputType.phone,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Phone number is required';
        }

        // Strip all non-digit characters for validation
        final digitsOnly = value.replaceAll(RegExp(r'\D'), '');

        if (digitsOnly.length < 10 || digitsOnly.length > 15) {
          return 'Phone number must be between 10-15 digits';
        }
        return null;
      },
      // Format phone number as typed
      onChanged: (value) {
        final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
        String formattedNumber = '';

        if (digitsOnly.isNotEmpty) {
          // Format based on digit count
          if (digitsOnly.length <= 3) {
            formattedNumber = '(${digitsOnly.substring(0, digitsOnly.length)}';
          } else if (digitsOnly.length <= 6) {
            formattedNumber =
                '(${digitsOnly.substring(0, 3)}) ${digitsOnly.substring(3, digitsOnly.length)}';
          } else {
            formattedNumber =
                '(${digitsOnly.substring(0, 3)}) ${digitsOnly.substring(3, 6)}-${digitsOnly.substring(6, min(10, digitsOnly.length))}';
          }
        }

        // Only update if the formatted number is different and not empty
        if (formattedNumber.isNotEmpty && formattedNumber != value) {
          _phoneController.value = TextEditingValue(
            text: formattedNumber,
            selection: TextSelection.collapsed(offset: formattedNumber.length),
          );
        }
      },
    );
  }

  void _showMoreActionsMenu() {}
}

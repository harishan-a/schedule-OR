/// A screen that manages user preferences and settings with real-time synchronization.
/// 
/// This screen provides:
/// - Theme customization (dark mode, high contrast, text size)
/// - Notification preferences with Firebase Messaging integration
/// - User profile management with Firestore
/// - Settings persistence using both SharedPreferences (local) and Firestore (cloud)
/// 
/// The settings are stored in two places:
/// 1. SharedPreferences: For immediate theme access on app startup
/// 2. Firestore: For cloud sync and cross-device consistency
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_orscheduler/shared/widgets/custom_navigation_bar.dart';
import 'package:firebase_orscheduler/shared/theme/app_theme.dart';
import 'package:firebase_orscheduler/features/schedule/screens/resource_check_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Firebase and SharedPreferences instances
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _messaging = FirebaseMessaging.instance;
  late SharedPreferences _prefs;
  
  // Theme and accessibility settings
  bool _isDarkMode = false;
  bool _useHighContrast = false;
  bool _useLargeText = false;
  
  // Notification and sound preferences
  bool _enableNotifications = true;
  bool _enableSoundEffects = true;
  
  // Loading and user data state
  bool _isLoading = true;
  Map<String, dynamic> _userProfile = {};

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  /// Initializes settings from both SharedPreferences and Firestore.
  /// 
  /// Order of operations:
  /// 1. Get SharedPreferences instance
  /// 2. Load user profile from Firestore
  /// 3. Load settings from Firestore
  /// 4. Apply theme preferences from SharedPreferences
  Future<void> _initializeSettings() async {
    try {
      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      
      if (user != null) {
        // Load user profile from Firestore
        final profileDoc = await _firestore.collection('users').doc(user.uid).get();
        _userProfile = profileDoc.data() ?? {};

        // Load settings from Firestore for cloud-synced preferences
        final settingsDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('preferences')
            .get();

        // Load theme preferences from SharedPreferences for immediate access
        setState(() {
          _isDarkMode = _prefs.getBool('darkMode') ?? false;
          _useLargeText = _prefs.getBool('largeText') ?? false;
          _useHighContrast = _prefs.getBool('highContrast') ?? false;
          
          // Apply cloud settings if they exist
          if (settingsDoc.exists) {
            final data = settingsDoc.data() ?? {};
            _enableNotifications = data['notifications'] ?? true;
            _enableSoundEffects = data['soundEffects'] ?? true;
          }
        });
      }
    } catch (e) {
      // Error handling is kept minimal as settings will use defaults
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Applies theme settings through the AppTheme provider.
  /// This method should be called whenever theme settings change.
  void _applyThemeSettings() {
    if (!mounted) return;
    final appTheme = AppTheme.of(context);
    appTheme.updateTheme(_isDarkMode, _useLargeText, _useHighContrast);
  }

  /// Saves all settings to both SharedPreferences and Firestore.
  /// Also handles notification permissions and theme updates.
  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Save theme preferences locally for immediate access on next app launch
        await _prefs.setBool('darkMode', _isDarkMode);
        await _prefs.setBool('largeText', _useLargeText);
        await _prefs.setBool('highContrast', _useHighContrast);

        // Save all settings to Firestore for cloud sync
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('preferences')
            .set({
          'darkMode': _isDarkMode,
          'highContrast': _useHighContrast,
          'largeText': _useLargeText,
          'notifications': _enableNotifications,
          'soundEffects': _enableSoundEffects,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Handle notification permissions and topic subscription
        if (_enableNotifications) {
          final settings = await _messaging.requestPermission();
          if (settings.authorizationStatus == AuthorizationStatus.authorized) {
            await _messaging.subscribeToTopic('app_notifications');
          }
        } else {
          await _messaging.unsubscribeFromTopic('app_notifications');
        }

        // Apply theme settings immediately
        _applyThemeSettings();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Shows a dialog for editing user profile information.
  /// Updates are saved to Firestore and reflected in the UI.
  Future<void> _editProfile() async {
    final TextEditingController nameController = TextEditingController(text: _userProfile['name']);
    final TextEditingController phoneController = TextEditingController(text: _userProfile['phone']);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final user = _auth.currentUser;
                if (user != null) {
                  await _firestore.collection('users').doc(user.uid).update({
                    'name': nameController.text.trim(),
                    'phone': phoneController.text.trim(),
                    'lastUpdated': FieldValue.serverTimestamp(),
                  });

                  setState(() {
                    _userProfile['name'] = nameController.text.trim();
                    _userProfile['phone'] = phoneController.text.trim();
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update profile: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Quick Actions Section
                _buildSection(
                  'Quick Actions',
                  [
                    ListTile(
                      leading: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: const Text('Resource Check'),
                      subtitle: const Text('Check availability of rooms and staff'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ResourceCheckScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                // Theme Settings Section
                _buildSection(
                  'Appearance',
                  [
                    SwitchListTile(
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Use dark theme throughout the app'),
                      value: _isDarkMode,
                      onChanged: (value) {
                        setState(() {
                          _isDarkMode = value;
                          _applyThemeSettings();
                        });
                      },
                      secondary: Icon(
                        _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('High Contrast'),
                      subtitle: const Text('Increase contrast for better visibility'),
                      value: _useHighContrast,
                      onChanged: (value) {
                        setState(() {
                          _useHighContrast = value;
                          _applyThemeSettings();
                        });
                      },
                      secondary: Icon(
                        Icons.contrast,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Large Text'),
                      subtitle: const Text('Increase text size for better reading'),
                      value: _useLargeText,
                      onChanged: (value) {
                        setState(() {
                          _useLargeText = value;
                          _applyThemeSettings();
                        });
                      },
                      secondary: Icon(
                        Icons.text_fields,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                // Notification Settings Section
                _buildSection(
                  'Notifications',
                  [
                    SwitchListTile(
                      title: const Text('Enable Notifications'),
                      subtitle: const Text('Receive updates about surgeries and schedules'),
                      value: _enableNotifications,
                      onChanged: (value) async {
                        if (value) {
                          final settings = await _messaging.requestPermission();
                          if (settings.authorizationStatus == AuthorizationStatus.authorized) {
                            setState(() => _enableNotifications = value);
                            await _saveSettings();
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enable notifications in your device settings'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          }
                        } else {
                          setState(() => _enableNotifications = value);
                          await _saveSettings();
                        }
                      },
                      secondary: Icon(
                        _enableNotifications ? Icons.notifications_active : Icons.notifications_off,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Sound Effects'),
                      subtitle: const Text('Play sounds for important notifications'),
                      value: _enableSoundEffects,
                      onChanged: _enableNotifications
                          ? (value) {
                              setState(() => _enableSoundEffects = value);
                              _saveSettings();
                            }
                          : null,
                      secondary: Icon(
                        Icons.volume_up,
                        color: _enableNotifications
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
                // Account Management Section
                _buildSection(
                  'Account',
                  [
                    ListTile(
                      leading: Icon(
                        Icons.person,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: const Text('Edit Profile'),
                      subtitle: Text(_userProfile['name'] ?? 'Update your profile'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _editProfile,
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.password,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: const Text('Change Password'),
                      subtitle: Text(_auth.currentUser?.email ?? ''),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        try {
                          await _auth.sendPasswordResetEmail(
                            email: _auth.currentUser?.email ?? '',
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password reset email sent'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to send password reset email: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
                // About Section
                _buildSection(
                  'About',
                  [
                    ListTile(
                      leading: Icon(
                        Icons.info,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: const Text('Version'),
                      subtitle: const Text('1.0.0'),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.description,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: const Text('Terms of Service'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showLegalDocument('Terms of Service'),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.privacy_tip,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: const Text('Privacy Policy'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showLegalDocument('Privacy Policy'),
                    ),
                  ],
                ),
              ],
            ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveSettings,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save),
                  SizedBox(width: 8),
                  Text('Save Settings'),
                ],
              ),
            ),
          ),
          CustomNavigationBar(
            currentIndex: 4,
            onTap: (index) {
              // Handle navigation
            },
          ),
        ],
      ),
    );
  }

  /// Builds a section in the settings screen with a title and list of widgets
  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }

  /// Shows a dialog with legal document content fetched from Firestore
  Future<void> _showLegalDocument(String title) async {
    try {
      final docRef = await _firestore.collection('legal_documents').doc(title.toLowerCase().replaceAll(' ', '_')).get();
      final content = docRef.data()?['content'] as String? ?? 'Content not available';
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Text(content),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load $title: $e')),
        );
      }
    }
  }
}


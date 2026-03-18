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
import 'dart:io' show Platform;
import 'package:firebase_orscheduler/shared/widgets/custom_navigation_bar.dart';
import 'package:firebase_orscheduler/shared/widgets/user_avatar.dart';
import 'package:firebase_orscheduler/shared/theme/app_theme.dart';
import 'package:firebase_orscheduler/features/schedule/screens/resource_check_screen.dart';
import 'package:firebase_orscheduler/services/notification_manager.dart';
import 'package:firebase_orscheduler/features/profile/screens/profile.dart';
import 'package:firebase_orscheduler/features/settings/screens/developer_settings.dart';

class SettingsScreen extends StatefulWidget {
  final bool isTestMode;

  const SettingsScreen({
    super.key,
    this.isTestMode = false,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  // Tab controller
  late TabController _tabController;

  // Firebase and SharedPreferences instances
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  FirebaseMessaging? _messaging;
  late SharedPreferences _prefs;

  // Theme and accessibility settings
  bool _isDarkMode = false;
  bool _useHighContrast = false;
  bool _useLargeText = false;

  // Notification and sound preferences
  bool _enableNotifications = true;
  bool _enableSoundEffects = true;

  // SMS notification preferences
  bool _enableSmsNotifications = true;
  bool _enableSmsScheduledNotifications = true;
  bool _enableSmsApproachingNotifications = true;
  bool _enableSmsUpdateNotifications = true;
  bool _enableSmsStatusNotifications = true;

  // Push notification preferences
  bool _enablePushNotifications = true;
  bool _enablePushScheduledNotifications = true;
  bool _enablePushApproachingNotifications = true;
  bool _enablePushUpdateNotifications = true;
  bool _enablePushStatusNotifications = true;

  // Email notification preferences
  bool _enableEmailNotifications = false;
  bool _enableEmailScheduledNotifications = false;
  bool _enableEmailApproachingNotifications = false;
  bool _enableEmailUpdateNotifications = false;
  bool _enableEmailStatusNotifications = false;

  // Loading and user data state
  bool _isLoading = true;
  Map<String, dynamic> _userProfile = {};

  // Notification manager
  final NotificationManager _notificationManager = NotificationManager();

  @override
  void initState() {
    super.initState();
    // Initialize tab controller with 3 tabs (removing the legal tab)
    _tabController = TabController(length: 3, vsync: this);

    if (!widget.isTestMode) {
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _messaging = FirebaseMessaging.instance;
    }

    _initializeSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

      if (widget.isTestMode || _auth == null) {
        setState(() {
          // Load local or default settings only.
          _isDarkMode = _prefs.getBool('darkMode') ?? false;
          _useLargeText = _prefs.getBool('largeText') ?? false;
          _useHighContrast = _prefs.getBool('highContrast') ?? false;
          _enableNotifications = true;
          _enableSoundEffects = true;
        });
      } else {
        final user = _auth!.currentUser;

        if (user != null) {
          // Load user profile from Firestore
          final profileDoc =
              await _firestore!.collection('users').doc(user.uid).get();
          _userProfile = profileDoc.data() ?? {};

          // Load settings from Firestore for cloud-synced preferences
          final settingsDoc = await _firestore!
              .collection('users')
              .doc(user.uid)
              .collection('settings')
              .doc('preferences')
              .get();

          // Load notification settings specifically
          final notificationSettingsDoc = await _firestore!
              .collection('users')
              .doc(user.uid)
              .collection('settings')
              .doc('notifications')
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

            // Apply notification settings
            if (notificationSettingsDoc.exists) {
              final data = notificationSettingsDoc.data() ?? {};

              // SMS settings
              _enableSmsNotifications = data['sms_enabled'] ?? true;
              _enableSmsScheduledNotifications =
                  data['sms_scheduled_enabled'] ?? true;
              _enableSmsApproachingNotifications =
                  data['sms_approaching_enabled'] ?? true;
              _enableSmsUpdateNotifications =
                  data['sms_update_enabled'] ?? true;
              _enableSmsStatusNotifications =
                  data['sms_status_enabled'] ?? true;

              // Push settings
              _enablePushNotifications = data['push_enabled'] ?? true;
              _enablePushScheduledNotifications =
                  data['push_scheduled_enabled'] ?? true;
              _enablePushApproachingNotifications =
                  data['push_approaching_enabled'] ?? true;
              _enablePushUpdateNotifications =
                  data['push_update_enabled'] ?? true;
              _enablePushStatusNotifications =
                  data['push_status_enabled'] ?? true;

              // Email settings
              _enableEmailNotifications = data['email_enabled'] ?? false;
              _enableEmailScheduledNotifications =
                  data['email_scheduled_enabled'] ?? false;
              _enableEmailApproachingNotifications =
                  data['email_approaching_enabled'] ?? false;
              _enableEmailUpdateNotifications =
                  data['email_update_enabled'] ?? false;
              _enableEmailStatusNotifications =
                  data['email_status_enabled'] ?? false;
            }
          });
        }
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
    if (widget.isTestMode) {
      // Skip calling AppTheme.of(context) in test mode
      return;
    }
    final appTheme = AppTheme.of(context);
    appTheme.updateTheme(_isDarkMode, _useLargeText, _useHighContrast);
  }

  /// Saves all settings to both SharedPreferences and Firestore.
  /// Also handles notification permissions and theme updates.
  Future<void> _saveSettings({bool showFeedback = true}) async {
    if (showFeedback) {
      setState(() => _isLoading = true);
    }

    try {
      // Save theme settings to SharedPreferences for immediate access on app startup
      await _prefs.setBool('darkMode', _isDarkMode);
      await _prefs.setBool('largeText', _useLargeText);
      await _prefs.setBool('highContrast', _useHighContrast);

      if (!widget.isTestMode && _auth != null) {
        final user = _auth!.currentUser;
        if (user != null) {
          // Save general preferences to Firestore
          await _firestore!
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
            final settings = await _messaging!.requestPermission();
            if (settings.authorizationStatus ==
                AuthorizationStatus.authorized) {
              try {
                final notificationManager = NotificationManager();

                if (Platform.isIOS) {
                  // On iOS, we need to wait for APNS token before subscribing to topics
                  await Future.delayed(const Duration(seconds: 2));
                  final apnsToken = await _messaging!.getAPNSToken();
                  if (apnsToken != null) {
                    await notificationManager
                        .subscribeToTopic('app_notifications');
                  }
                } else {
                  // Android platform
                  await notificationManager
                      .subscribeToTopic('app_notifications');
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error enabling notifications: $e'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            }
          } else {
            try {
              await _notificationManager
                  .unsubscribeFromTopic('app_notifications');
            } catch (e) {
              // Handle error silently
            }
          }

          // Apply theme settings immediately
          _applyThemeSettings();

          // Save notification settings in a separate document
          final notificationSettings = {
            // SMS notification settings
            'sms_enabled': _enableSmsNotifications,
            'sms_scheduled_enabled': _enableSmsScheduledNotifications,
            'sms_approaching_enabled': _enableSmsApproachingNotifications,
            'sms_update_enabled': _enableSmsUpdateNotifications,
            'sms_status_enabled': _enableSmsStatusNotifications,

            // Push notification settings
            'push_enabled': _enablePushNotifications,
            'push_scheduled_enabled': _enablePushScheduledNotifications,
            'push_approaching_enabled': _enablePushApproachingNotifications,
            'push_update_enabled': _enablePushUpdateNotifications,
            'push_status_enabled': _enablePushStatusNotifications,

            // Email notification settings
            'email_enabled': _enableEmailNotifications,
            'email_scheduled_enabled': _enableEmailScheduledNotifications,
            'email_approaching_enabled': _enableEmailApproachingNotifications,
            'email_update_enabled': _enableEmailUpdateNotifications,
            'email_status_enabled': _enableEmailStatusNotifications,

            'lastUpdated': FieldValue.serverTimestamp(),
          };

          await _firestore!
              .collection('users')
              .doc(user.uid)
              .collection('settings')
              .doc('notifications')
              .set(notificationSettings, SetOptions(merge: true));

          // Update notification preferences through the NotificationManager
          final preferences = NotificationPreferences(
            enableNotifications: _enableNotifications,
            enablePush: _enablePushNotifications,
            enableSms: _enableSmsNotifications,
            enableEmail: _enableEmailNotifications,
            channelPreferences: {
              'scheduled': {
                'push': _enablePushScheduledNotifications,
                'sms': _enableSmsScheduledNotifications,
                'email': _enableEmailScheduledNotifications,
              },
              'approaching': {
                'push': _enablePushApproachingNotifications,
                'sms': _enableSmsApproachingNotifications,
                'email': _enableEmailApproachingNotifications,
              },
              'update': {
                'push': _enablePushUpdateNotifications,
                'sms': _enableSmsUpdateNotifications,
                'email': _enableEmailUpdateNotifications,
              },
              'status': {
                'push': _enablePushStatusNotifications,
                'sms': _enableSmsStatusNotifications,
                'email': _enableEmailStatusNotifications,
              },
            },
          );

          await _notificationManager.updateNotificationSettings(preferences);

          if (showFeedback && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Settings saved'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 1),
              ),
            );
          }
        }
      } else {
        _applyThemeSettings();
        if (showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings saved locally'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (showFeedback && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper method to update theme settings with auto-save
  void _updateThemeSetting(String setting, bool value) {
    setState(() {
      switch (setting) {
        case 'darkMode':
          _isDarkMode = value;
          break;
        case 'highContrast':
          _useHighContrast = value;
          break;
        case 'largeText':
          _useLargeText = value;
          break;
      }
      _applyThemeSettings();
    });

    // Auto-save the settings
    _saveSettings(showFeedback: false);
  }

  // Helper method to update notification settings with auto-save
  void _updateNotificationSetting(String setting, bool value) async {
    setState(() {
      switch (setting) {
        case 'notifications':
          _enableNotifications = value;
          break;
        case 'soundEffects':
          _enableSoundEffects = value;
          break;
        case 'pushNotifications':
          _enablePushNotifications = value;
          break;
        case 'smsNotifications':
          _enableSmsNotifications = value;
          break;
        case 'emailNotifications':
          _enableEmailNotifications = value;
          break;
        // Push notification subtypes
        case 'pushScheduled':
          _enablePushScheduledNotifications = value;
          break;
        case 'pushApproaching':
          _enablePushApproachingNotifications = value;
          break;
        case 'pushUpdate':
          _enablePushUpdateNotifications = value;
          break;
        case 'pushStatus':
          _enablePushStatusNotifications = value;
          break;
        // SMS notification subtypes
        case 'smsScheduled':
          _enableSmsScheduledNotifications = value;
          break;
        case 'smsApproaching':
          _enableSmsApproachingNotifications = value;
          break;
        case 'smsUpdate':
          _enableSmsUpdateNotifications = value;
          break;
        case 'smsStatus':
          _enableSmsStatusNotifications = value;
          break;
        // Email notification subtypes
        case 'emailScheduled':
          _enableEmailScheduledNotifications = value;
          break;
        case 'emailApproaching':
          _enableEmailApproachingNotifications = value;
          break;
        case 'emailUpdate':
          _enableEmailUpdateNotifications = value;
          break;
        case 'emailStatus':
          _enableEmailStatusNotifications = value;
          break;
      }
    });

    // For main notification toggle, we need to request permissions if enabled
    if (setting == 'notifications' && value) {
      if (!widget.isTestMode && _messaging != null) {
        final settings = await _messaging!.requestPermission();
        if (settings.authorizationStatus != AuthorizationStatus.authorized) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Please enable notifications in your device settings'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    }

    // Auto-save the settings
    _saveSettings(showFeedback: false);
  }

  /// Shows a dialog for editing user profile information.
  /// Updates are saved to Firestore and reflected in the UI.
  Future<void> _editProfile() async {
    final TextEditingController nameController =
        TextEditingController(text: _userProfile['name']);
    final TextEditingController phoneController =
        TextEditingController(text: _userProfile['phone']);
    final TextEditingController emailController =
        TextEditingController(text: _userProfile['email']);

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
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email Address'),
                keyboardType: TextInputType.emailAddress,
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
                if (!widget.isTestMode && _auth != null) {
                  final user = _auth!.currentUser;
                  if (user != null) {
                    await _firestore!.collection('users').doc(user.uid).update({
                      'name': nameController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'email': emailController.text.trim(),
                      'lastUpdated': FieldValue.serverTimestamp(),
                    });

                    setState(() {
                      _userProfile['name'] = nameController.text.trim();
                      _userProfile['phone'] = phoneController.text.trim();
                      _userProfile['email'] = emailController.text.trim();
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
                } else {
                  setState(() {
                    _userProfile['name'] = nameController.text.trim();
                    _userProfile['phone'] = phoneController.text.trim();
                    _userProfile['email'] = emailController.text.trim();
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated locally'),
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

  /// Sends a test notification to the current user
  Future<void> _sendTestNotification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You must be logged in to test notifications')),
        );
        return;
      }

      // Use the notification manager to send a test notification
      final notificationManager = NotificationManager();
      await notificationManager.sendTestNotification();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification sent successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending test notification: $e')),
      );
    }
  }

  /// Test SMS notification
  Future<void> _testSMSNotification() async {
    try {
      final currentUser = _auth?.currentUser;
      if (currentUser == null) {
        _showSnackBar('Please sign in to test notifications');
        return;
      }

      // Get user phone number from Firestore
      final userDoc =
          await _firestore?.collection('users').doc(currentUser.uid).get();
      final userData = userDoc?.data();

      if (userData == null || userData['phoneNumber'] == null) {
        _showSnackBar('No phone number found. Please update your profile.');
        return;
      }

      final phoneNumber = userData['phoneNumber'];

      // Show loading dialog
      _showLoadingDialog('Sending test SMS...');

      // Send test SMS
      final result = await _notificationManager.sendTestSMS(
        phoneNumber: phoneNumber,
        message:
            'Test notification from ORScheduler: ${DateTime.now().toString()}',
      );

      // Hide loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show result
      if (result) {
        _showSnackBar('Test SMS sent successfully');
      } else {
        _showSnackBar('Failed to send test SMS. Check logs for details.');
      }
    } catch (e) {
      // Hide loading dialog if still showing
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      _showSnackBar('Error sending test SMS: $e');
    }
  }

  /// Test push notification
  Future<void> _testPushNotification() async {
    try {
      final currentUser = _auth?.currentUser;
      if (currentUser == null) {
        _showSnackBar('Please sign in to test notifications');
        return;
      }

      // Show loading dialog
      _showLoadingDialog('Sending test push notification...');

      // Send test push notification via local notification
      await _notificationManager.sendPushNotification(
        title: 'Test Notification',
        body:
            'This is a test notification from ORScheduler: ${DateTime.now().toString()}',
        userId: currentUser.uid,
      );

      // Hide loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      _showSnackBar('Test push notification sent');
    } catch (e) {
      // Hide loading dialog if still showing
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      _showSnackBar('Error sending test push notification: $e');
    }
  }

  /// Show a loading dialog
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  /// Show a snackbar with a message
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
        centerTitle: true,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        leadingWidth: 56, // Give more space for the back button
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: colorScheme.surfaceContainerHighest, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: colorScheme.primary,
              indicatorWeight: 3,
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurface.withOpacity(0.7),
              labelPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              labelStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              unselectedLabelStyle: TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 16,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.person),
                  text: "Account",
                ),
                Tab(
                  icon: Icon(Icons.color_lens),
                  text: "Appearance",
                ),
                Tab(
                  icon: Icon(Icons.notifications),
                  text: "Notifications",
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Account Tab
                _buildAccountTab(),

                // Appearance Tab
                _buildAppearanceTab(),

                // Notifications Tab
                _buildNotificationsTab(),
              ],
            ),
      bottomNavigationBar: CustomNavigationBar(
        currentIndex: 4,
        onTap: (index) {
          // Handle navigation
        },
      ),
    );
  }

  /// Builds the Account tab content
  Widget _buildAccountTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildAccountSection(),
        const SizedBox(height: 16),
        _buildAboutSection(),
      ],
    );
  }

  /// Builds the Appearance tab content
  Widget _buildAppearanceTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildThemeSettings(),
      ],
    );
  }

  /// Builds the Notifications tab content
  Widget _buildNotificationsTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildMainNotificationSettings(),
        const SizedBox(height: 16),
        _buildDetailedNotificationSettings(),
        const SizedBox(height: 16),
        _buildTestNotificationsCard(),
      ],
    );
  }

  /// Builds the account section for the Account tab
  Widget _buildAccountSection() {
    final isAdmin = _userProfile['role'] == 'Admin';

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingsItem(
              icon: Icons.person,
              title: 'Edit Profile',
              subtitle: 'Change your personal information',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const ProfileScreen(fromMoreScreen: false),
                  ),
                );
              },
            ),
            const Divider(),
            _buildSettingsItem(
              icon: Icons.password,
              title: 'Change Password',
              subtitle: 'Update your account password',
              onTap: () {
                _showChangePasswordDialog();
              },
            ),
            if (isAdmin) ...[
              const Divider(),
              _buildSettingsItem(
                icon: Icons.developer_mode,
                title: 'Developer Tools',
                subtitle: 'Import data, test features, and more',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DeveloperSettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds an action tile with icon, title, subtitle and onTap action
  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
          child: Row(
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the theme settings card for the Appearance tab
  Widget _buildThemeSettings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.color_lens,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Theme & Display',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Dark Mode Switch with animation
            _buildThemeToggle(
              icon: _isDarkMode ? Icons.dark_mode : Icons.light_mode,
              title: 'Dark Mode',
              subtitle: 'Use dark theme throughout the app',
              value: _isDarkMode,
              onChanged: (value) => _updateThemeSetting('darkMode', value),
              animate: true,
            ),

            const Divider(),

            // High Contrast Switch
            _buildThemeToggle(
              icon: Icons.contrast,
              title: 'High Contrast',
              subtitle: 'Increase contrast for better visibility',
              value: _useHighContrast,
              onChanged: (value) => _updateThemeSetting('highContrast', value),
            ),

            const Divider(),

            // Large Text Switch
            _buildThemeToggle(
              icon: Icons.text_fields,
              title: 'Large Text',
              subtitle: 'Increase text size for better reading',
              value: _useLargeText,
              onChanged: (value) => _updateThemeSetting('largeText', value),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a theme toggle with icon, title, subtitle and switch
  Widget _buildThemeToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool animate = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          animate
              ? AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Icon(
                    icon,
                    key: ValueKey<bool>(value),
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                )
              : Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  /// Builds the main notification settings card
  Widget _buildMainNotificationSettings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Notification Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Main Notification Toggle
            _buildThemeToggle(
              icon: _enableNotifications
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              title: 'Enable Notifications',
              subtitle: 'Receive updates about surgeries and schedules',
              value: _enableNotifications,
              onChanged: (value) async {
                if (value) {
                  if (!widget.isTestMode && _messaging != null) {
                    final settings = await _messaging!.requestPermission();
                    if (settings.authorizationStatus ==
                        AuthorizationStatus.authorized) {
                      _updateNotificationSetting('notifications', value);
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Please enable notifications in your device settings'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    }
                  } else {
                    _updateNotificationSetting('notifications', value);
                  }
                } else {
                  _updateNotificationSetting('notifications', value);
                }
              },
              animate: true,
            ),

            if (_enableNotifications) ...[
              const Divider(),
              // Sound Effects Toggle
              _buildThemeToggle(
                icon: Icons.volume_up,
                title: 'Sound Effects',
                subtitle: 'Play sounds for important notifications',
                value: _enableSoundEffects,
                onChanged: (value) =>
                    _updateNotificationSetting('soundEffects', value),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds the detailed notification settings with expandable sections
  Widget _buildDetailedNotificationSettings() {
    return AnimatedOpacity(
      opacity: _enableNotifications ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 300),
      child: Column(
        children: [
          // Push Notifications Section
          _buildNotificationChannelCard(
            'Push Notifications',
            Icons.notifications,
            _enablePushNotifications,
            (value) => _updateNotificationSetting('pushNotifications', value),
            [
              _buildNotificationSubtypeToggle(
                title: 'Scheduled Surgeries',
                subtitle: 'Notifications when surgeries are scheduled',
                icon: Icons.event_available,
                value: _enablePushScheduledNotifications,
                onChanged: (_enableNotifications && _enablePushNotifications)
                    ? (value) =>
                        _updateNotificationSetting('pushScheduled', value)
                    : null,
                enabled: _enableNotifications && _enablePushNotifications,
              ),
              _buildNotificationSubtypeToggle(
                title: 'Approaching Surgeries',
                subtitle: 'Reminders for upcoming surgeries',
                icon: Icons.alarm,
                value: _enablePushApproachingNotifications,
                onChanged: (_enableNotifications && _enablePushNotifications)
                    ? (value) =>
                        _updateNotificationSetting('pushApproaching', value)
                    : null,
                enabled: _enableNotifications && _enablePushNotifications,
              ),
              _buildNotificationSubtypeToggle(
                title: 'Updates',
                subtitle: 'Notifications when surgeries are updated',
                icon: Icons.update,
                value: _enablePushUpdateNotifications,
                onChanged: (_enableNotifications && _enablePushNotifications)
                    ? (value) => _updateNotificationSetting('pushUpdate', value)
                    : null,
                enabled: _enableNotifications && _enablePushNotifications,
              ),
              _buildNotificationSubtypeToggle(
                title: 'Status Changes',
                subtitle: 'Notifications when surgery status changes',
                icon: Icons.loop,
                value: _enablePushStatusNotifications,
                onChanged: (_enableNotifications && _enablePushNotifications)
                    ? (value) => _updateNotificationSetting('pushStatus', value)
                    : null,
                enabled: _enableNotifications && _enablePushNotifications,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // SMS Notifications Section
          _buildNotificationChannelCard(
            'SMS Notifications',
            Icons.sms,
            _enableSmsNotifications,
            (value) => _updateNotificationSetting('smsNotifications', value),
            [
              _buildNotificationSubtypeToggle(
                title: 'Scheduled Surgeries',
                subtitle: 'SMS when surgeries are scheduled',
                icon: Icons.event_available,
                value: _enableSmsScheduledNotifications,
                onChanged: (_enableNotifications && _enableSmsNotifications)
                    ? (value) =>
                        _updateNotificationSetting('smsScheduled', value)
                    : null,
                enabled: _enableNotifications && _enableSmsNotifications,
              ),
              _buildNotificationSubtypeToggle(
                title: 'Approaching Surgeries',
                subtitle: 'SMS reminders for upcoming surgeries',
                icon: Icons.alarm,
                value: _enableSmsApproachingNotifications,
                onChanged: (_enableNotifications && _enableSmsNotifications)
                    ? (value) =>
                        _updateNotificationSetting('smsApproaching', value)
                    : null,
                enabled: _enableNotifications && _enableSmsNotifications,
              ),
              _buildNotificationSubtypeToggle(
                title: 'Updates',
                subtitle: 'SMS when surgeries are updated',
                icon: Icons.update,
                value: _enableSmsUpdateNotifications,
                onChanged: (_enableNotifications && _enableSmsNotifications)
                    ? (value) => _updateNotificationSetting('smsUpdate', value)
                    : null,
                enabled: _enableNotifications && _enableSmsNotifications,
              ),
              _buildNotificationSubtypeToggle(
                title: 'Status Changes',
                subtitle: 'SMS when surgery status changes',
                icon: Icons.loop,
                value: _enableSmsStatusNotifications,
                onChanged: (_enableNotifications && _enableSmsNotifications)
                    ? (value) => _updateNotificationSetting('smsStatus', value)
                    : null,
                enabled: _enableNotifications && _enableSmsNotifications,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Email Notifications Section
          _buildNotificationChannelCard(
            'Email Notifications',
            Icons.email,
            _enableEmailNotifications,
            (value) => _updateNotificationSetting('emailNotifications', value),
            [
              _buildNotificationSubtypeToggle(
                title: 'Scheduled Surgeries',
                subtitle: 'Emails when surgeries are scheduled',
                icon: Icons.event_available,
                value: _enableEmailScheduledNotifications,
                onChanged: (_enableNotifications && _enableEmailNotifications)
                    ? (value) =>
                        _updateNotificationSetting('emailScheduled', value)
                    : null,
                enabled: _enableNotifications && _enableEmailNotifications,
              ),
              _buildNotificationSubtypeToggle(
                title: 'Approaching Surgeries',
                subtitle: 'Email reminders for upcoming surgeries',
                icon: Icons.alarm,
                value: _enableEmailApproachingNotifications,
                onChanged: (_enableNotifications && _enableEmailNotifications)
                    ? (value) =>
                        _updateNotificationSetting('emailApproaching', value)
                    : null,
                enabled: _enableNotifications && _enableEmailNotifications,
              ),
              _buildNotificationSubtypeToggle(
                title: 'Updates',
                subtitle: 'Emails when surgeries are updated',
                icon: Icons.update,
                value: _enableEmailUpdateNotifications,
                onChanged: (_enableNotifications && _enableEmailNotifications)
                    ? (value) =>
                        _updateNotificationSetting('emailUpdate', value)
                    : null,
                enabled: _enableNotifications && _enableEmailNotifications,
              ),
              _buildNotificationSubtypeToggle(
                title: 'Status Changes',
                subtitle: 'Emails when surgery status changes',
                icon: Icons.loop,
                value: _enableEmailStatusNotifications,
                onChanged: (_enableNotifications && _enableEmailNotifications)
                    ? (value) =>
                        _updateNotificationSetting('emailStatus', value)
                    : null,
                enabled: _enableNotifications && _enableEmailNotifications,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a notification subtype toggle with icon, title, subtitle, and switch
  Widget _buildNotificationSubtypeToggle({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required bool enabled,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: enabled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).disabledColor,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: enabled
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).disabledColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: enabled
                        ? Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7)
                        : Theme.of(context).disabledColor,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  /// Builds an expandable notification channel card
  Widget _buildNotificationChannelCard(String title, IconData icon,
      bool isEnabled, Function(bool) onChanged, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          title: Row(
            children: [
              Icon(
                icon,
                color: _enableNotifications
                    ? (isEnabled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey)
                    : Theme.of(context).disabledColor,
                size: 24,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _enableNotifications
                      ? null
                      : Theme.of(context).disabledColor,
                ),
              ),
            ],
          ),
          initiallyExpanded: isEnabled && _enableNotifications,
          maintainState: true,
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          trailing: _enableNotifications
              ? Switch.adaptive(
                  value: isEnabled,
                  onChanged: onChanged,
                  activeColor: Theme.of(context).colorScheme.primary,
                )
              : null,
          children: <Widget>[
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Builds the test notifications card
  Widget _buildTestNotificationsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.send,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Test Notifications',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Send a test notification to verify your notification settings',
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.sms),
                    label: const Text('Test SMS'),
                    onPressed: _enableNotifications && _enableSmsNotifications
                        ? () => _testSMSNotification()
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      disabledForegroundColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.38),
                      disabledBackgroundColor: Theme.of(context)
                          .colorScheme
                          .surface
                          .withOpacity(0.12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.notifications),
                    label: const Text('Test Push'),
                    onPressed: _enableNotifications && _enablePushNotifications
                        ? () => _testPushNotification()
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      disabledForegroundColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.38),
                      disabledBackgroundColor: Theme.of(context)
                          .colorScheme
                          .surface
                          .withOpacity(0.12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds an About card with app information
  Widget _buildAboutSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'About ORScheduler',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'ORScheduler is a comprehensive solution for operating room scheduling and management, designed to streamline workflows and enhance communication among healthcare professionals.',
                style: TextStyle(fontSize: 15),
              ),
            ),
            const Divider(),
            _buildInfoRow(
              icon: Icons.verified,
              title: 'Version',
              value: '1.0.0',
            ),
            const Divider(),
            _buildInfoRow(
              icon: Icons.groups,
              title: 'Developed By',
              value: 'ORScheduler Team',
            ),
            const Divider(),
            _buildInfoRow(
              icon: Icons.copyright,
              title: 'Copyright',
              value: '© 2024-2025q ORScheduler',
            ),
            const Divider(),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DeveloperSettingsScreen(),
                  ),
                );
              },
              child: _buildInfoRow(
                icon: Icons.build,
                title: 'Developer Tools',
                value: 'Import data, test features, and more',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds an info row with icon, title and value
  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Shows a dialog to change password
  void _showChangePasswordDialog() {
    final TextEditingController oldPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match')),
                  );
                  return;
                }

                // Implement password change logic here
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password updated')),
                );
              },
              child: const Text('CHANGE'),
            ),
          ],
        );
      },
    );
  }

  /// Builds a settings item with icon, title, subtitle and tap action
  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
          child: Row(
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

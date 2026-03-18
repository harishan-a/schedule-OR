import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_orscheduler/features/profile/screens/profile.dart';
import 'package:firebase_orscheduler/features/schedule/screens/resource_check_screen.dart';
import 'package:firebase_orscheduler/features/surgery/screens/surgery_log.dart';
import 'package:firebase_orscheduler/features/settings/screens/settings.dart';
import 'package:firebase_orscheduler/shared/widgets/custom_navigation_bar.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  int _selectedIndex = 5; // More tab index (now updated to 5)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('More Options'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        children: [
          // Profile option
          _buildOptionCard(
            context: context,
            icon: Icons.person,
            title: 'View Profile',
            subtitle: 'View and update your profile information',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      const ProfileScreen(fromMoreScreen: true)),
            ),
          ),

          const SizedBox(height: 16),

          // Resource Check option
          _buildOptionCard(
            context: context,
            icon: Icons.search,
            title: 'Resource Check',
            subtitle: 'Check availability of rooms, staff and equipment',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ResourceCheckScreen()),
            ),
          ),

          const SizedBox(height: 16),

          // Surgery Log option
          _buildOptionCard(
            context: context,
            icon: Icons.history,
            title: 'Surgery Log',
            subtitle: 'View past and upcoming surgeries',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SurgeryLogScreen()),
            ),
          ),

          const SizedBox(height: 16),

          // Settings option
          _buildOptionCard(
            context: context,
            icon: Icons.settings,
            title: 'Settings',
            subtitle: 'Adjust app preferences and settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),

          const SizedBox(height: 24),

          // Logout button
          ElevatedButton.icon(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/auth');
              }
            },
            icon: const Icon(Icons.exit_to_app, color: Colors.red),
            label: const Text('Logout', style: TextStyle(color: Colors.red)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: theme.colorScheme.surface,
              elevation: 1,
            ),
          ),
        ],
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

  Widget _buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: theme.colorScheme.primary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

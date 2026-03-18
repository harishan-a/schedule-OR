import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_orscheduler/services/notification_manager.dart';

/// A screen that displays all user notifications with
/// options to mark as read, clear, or view details
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationManager _notificationManager = NotificationManager();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

  /// Mark all notifications as read when screen opens
  Future<void> _markAllAsRead() async {
    await _notificationManager.markAllNotificationsAsRead();
  }

  /// Handle notification tap based on type
  void _handleNotificationTap(Map<String, dynamic> notification) async {
    // Mark it as read
    await _notificationManager.markNotificationAsRead(notification['id']);

    if (!mounted) return;

    // Handle navigation based on notification type
    final data = notification['data'] as Map<String, dynamic>? ?? {};

    if (data['type'] == 'surgery' && data.containsKey('surgeryId')) {
      // Navigate to surgery details
      switch (data['action']) {
        case 'scheduled':
        case 'update':
        case 'status_change':
        case 'reminder':
          _navigateToSurgeryDetails(data['surgeryId']);
          break;
      }
    }
  }

  /// Navigate to surgery details screen
  void _navigateToSurgeryDetails(String surgeryId) {
    // TODO: Implement navigation to surgery details
    // This depends on your app's navigation structure
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing surgery: $surgeryId')),
    );
  }

  /// Clear a specific notification
  Future<void> _clearNotification(String notificationId,
      [String? source]) async {
    try {
      await _notificationManager.clearNotification(
          notificationId, source ?? 'direct');
    } catch (e) {
      debugPrint('Error clearing notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error removing notification')),
        );
      }
    }
  }

  /// Clear all notifications
  Future<void> _clearAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
            'Are you sure you want to clear all notifications? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() => _isLoading = true);
        await _notificationManager.clearAllNotifications();

        // Force rebuild the UI to show the empty state
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All notifications cleared')),
          );
        }
      } catch (e) {
        debugPrint('Error clearing all notifications: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error clearing notifications')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearAllNotifications,
            tooltip: 'Clear All',
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _notificationManager.getUserNotificationsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final notifications = snapshot.data ?? [];

              if (notifications.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  final timestamp = notification['timestamp'] as Timestamp?;
                  final DateTime dateTime =
                      timestamp?.toDate() ?? DateTime.now();
                  final bool isRead = notification['read'] ?? false;
                  final String source =
                      notification['source'] as String? ?? 'direct';
                  final int uniqueTimestamp =
                      notification['timestampCreated'] as int? ??
                          DateTime.now().millisecondsSinceEpoch;

                  // Format time based on how recent it is
                  final String timeText = _getFormattedTime(dateTime);

                  return Dismissible(
                    key: Key('${notification['id']}_$uniqueTimestamp'),
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async {
                      try {
                        await _clearNotification(notification['id'], source);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Notification removed'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                        return true;
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to remove notification'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                        return false;
                      }
                    },
                    // Add haptic feedback
                    onUpdate: (details) {
                      if (details.reached && !details.previousReached) {
                        // Optional: You could add haptic feedback here if you import 'package:flutter/services.dart'
                        // HapticFeedback.mediumImpact();
                      }
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      elevation: isRead ? 1 : 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isRead
                            ? BorderSide.none
                            : BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.3),
                                width: 1,
                              ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: _getNotificationIcon(notification),
                        title: Text(
                          notification['title'] ?? 'Notification',
                          style: TextStyle(
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              notification['body'] ?? '',
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  timeText,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () => _handleNotificationTap(notification),
                        trailing: IconButton(
                          icon: Icon(
                            isRead ? Icons.delete_outline : Icons.circle,
                            color: isRead
                                ? Colors.grey[400]
                                : Theme.of(context).colorScheme.primary,
                            size: isRead ? 24 : 12,
                          ),
                          onPressed: () {
                            if (isRead) {
                              _clearNotification(notification['id'], source);
                            } else {
                              _notificationManager.markNotificationAsRead(
                                  notification['id'], source);
                              // Force a UI update when manually marking as read
                              setState(() {});
                            }
                          },
                          tooltip: isRead ? 'Clear' : 'Mark as read',
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Clearing notifications...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Get icon based on notification type
  Widget _getNotificationIcon(Map<String, dynamic> notification) {
    // Safely extract and cast the data
    final dynamic rawData = notification['data'];
    final Map<String, dynamic> data;

    if (rawData is Map) {
      // Convert from Map<dynamic, dynamic> to Map<String, dynamic>
      data = Map<String, dynamic>.from(rawData);
    } else {
      data = {};
    }

    final String type = data['type'] as String? ?? '';

    // Icon and color
    IconData iconData;
    Color iconColor;

    if (type == 'surgery') {
      final String action = data['action'] as String? ?? '';
      switch (action) {
        case 'scheduled':
          iconData = Icons.event_available;
          iconColor = Colors.green.shade700;
          break;
        case 'reminder':
          iconData = Icons.alarm;
          iconColor = Colors.orange.shade700;
          break;
        case 'update':
          iconData = Icons.update;
          iconColor = Colors.blue.shade700;
          break;
        case 'status_change':
          iconData = Icons.loop;
          iconColor = Colors.purple.shade700;
          break;
        default:
          iconData = Icons.notifications;
          iconColor = Colors.grey.shade700;
      }
    } else {
      iconData = Icons.notifications;
      iconColor = Colors.grey.shade700;
    }

    // Return icon with circular background
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
      ),
    );
  }

  /// Format timestamp for display
  String _getFormattedTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, yyyy').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

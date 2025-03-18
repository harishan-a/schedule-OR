import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_orscheduler/services/notification_manager.dart';

/// A screen that displays all user notifications with
/// options to mark as read, clear, or view details
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

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
  Future<void> _clearNotification(String notificationId) async {
    setState(() => _isLoading = true);
    await _notificationManager.clearNotification(notificationId);
    setState(() => _isLoading = false);
  }

  /// Clear all notifications
  Future<void> _clearAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
          'Are you sure you want to clear all notifications? This cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await _notificationManager.clearAllNotifications();
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
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
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
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
                  final DateTime dateTime = timestamp?.toDate() ?? DateTime.now();
                  final bool isRead = notification['read'] ?? false;
                  
                  // Format time based on how recent it is
                  final String timeText = _getFormattedTime(dateTime);

                  return Dismissible(
                    key: Key(notification['id']),
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
                    onDismissed: (_) => _clearNotification(notification['id']),
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      elevation: isRead ? 1 : 3,
                      child: ListTile(
                        leading: _getNotificationIcon(notification),
                        title: Text(
                          notification['title'] ?? 'Notification',
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notification['body'] ?? ''),
                            Text(
                              timeText,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () => _handleNotificationTap(notification),
                        trailing: isRead
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _clearNotification(notification['id']),
                                tooltip: 'Clear',
                              )
                            : Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
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
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  /// Get icon based on notification type
  Widget _getNotificationIcon(Map<String, dynamic> notification) {
    final data = notification['data'] as Map<String, dynamic>? ?? {};
    
    if (data['type'] == 'surgery') {
      switch (data['action']) {
        case 'scheduled':
          return Icon(
            Icons.event_available,
            color: Colors.green[700],
          );
        case 'reminder':
          return Icon(
            Icons.alarm,
            color: Colors.orange[700],
          );
        case 'update':
          return Icon(
            Icons.update,
            color: Colors.blue[700],
          );
        case 'status_change':
          return Icon(
            Icons.loop,
            color: Colors.purple[700],
          );
      }
    }

    return Icon(
      Icons.notifications,
      color: Colors.grey[700],
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
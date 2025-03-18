import 'package:flutter/material.dart';
import 'package:firebase_orscheduler/services/notification_manager.dart';

/// A widget that displays a notification badge with unread count
/// Used in the app bar or navigation to indicate pending notifications
class NotificationBadge extends StatelessWidget {
  final VoidCallback onTap;
  
  const NotificationBadge({
    Key? key,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final notificationManager = NotificationManager();
    
    return StreamBuilder<int>(
      stream: notificationManager.getUnreadNotificationCount(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: onTap,
              tooltip: 'Notifications',
            ),
            if (unreadCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
} 
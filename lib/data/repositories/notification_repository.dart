import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import 'package:firebase_orscheduler/data/models/notification_model.dart';

/// Repository for notification CRUD operations.
class NotificationRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final _logger = Logger('NotificationRepository');

  NotificationRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference get _notificationsRef =>
      _firestore.collection('notifications');

  /// Stream notifications for current user, ordered by creation time.
  Stream<List<NotificationModel>> getNotificationsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _notificationsRef
        .where('recipientId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(
                doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  /// Get unread notification count for current user.
  Stream<int> getUnreadCountStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    return _notificationsRef
        .where('recipientId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Create a new notification.
  Future<String> createNotification(NotificationModel notification) async {
    final docRef = await _notificationsRef.add(notification.toFirestore());
    _logger.info('Created notification: ${docRef.id}');
    return docRef.id;
  }

  /// Mark a notification as read.
  Future<void> markAsRead(String notificationId) async {
    await _notificationsRef.doc(notificationId).update({'isRead': true});
    _logger.info('Marked notification as read: $notificationId');
  }

  /// Mark all notifications for current user as read.
  Future<void> markAllAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final batch = _firestore.batch();
    final snapshot = await _notificationsRef
        .where('recipientId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
    _logger.info('Marked ${snapshot.docs.length} notifications as read');
  }

  /// Delete a notification.
  Future<void> deleteNotification(String notificationId) async {
    await _notificationsRef.doc(notificationId).delete();
    _logger.info('Deleted notification: $notificationId');
  }

  /// Delete all notifications for current user.
  Future<void> deleteAllNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final batch = _firestore.batch();
    final snapshot =
        await _notificationsRef.where('recipientId', isEqualTo: user.uid).get();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    _logger.info('Deleted ${snapshot.docs.length} notifications');
  }
}

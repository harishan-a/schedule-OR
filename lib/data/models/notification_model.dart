import 'package:cloud_firestore/cloud_firestore.dart';

/// Typed notification model for the notification system.
class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type;
  final String? surgeryId;
  final String? senderId;
  final String recipientId;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? metadata;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.surgeryId,
    this.senderId,
    required this.recipientId,
    required this.createdAt,
    this.isRead = false,
    this.metadata,
  });

  factory NotificationModel.fromFirestore(
      String id, Map<String, dynamic> data) {
    return NotificationModel(
      id: id,
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      type: data['type'] as String? ?? 'general',
      surgeryId: data['surgeryId'] as String?,
      senderId: data['senderId'] as String?,
      recipientId: data['recipientId'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'type': type,
      if (surgeryId != null) 'surgeryId': surgeryId,
      if (senderId != null) 'senderId': senderId,
      'recipientId': recipientId,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      if (metadata != null) 'metadata': metadata,
    };
  }

  NotificationModel copyWith({
    String? title,
    String? message,
    String? type,
    String? surgeryId,
    String? senderId,
    String? recipientId,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationModel(
      id: id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      surgeryId: surgeryId ?? this.surgeryId,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'NotificationModel(id: $id, title: $title, type: $type, isRead: $isRead)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

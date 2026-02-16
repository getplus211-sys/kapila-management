import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';


class NotificationService {
  final _supabase = Supabase.instance.client;

  // ✅ FCM Token save - schema: user_id, fcm_token, device_type, is_active
  Future<void> saveFcmToken({
    required String fcmToken,
    required String deviceType,
    String? deviceName,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('ngm_notification_tokens').upsert({
        'user_id': userId,
        'fcm_token': fcmToken,
        'device_type': deviceType,
        'device_name': deviceName,
        'is_active': true,
        'last_used_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ FCM token saved');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  // ✅ Create notification - schema: user_id, chat_id, message_id, 
  //    sender_id, notification_type, title, body, is_read, is_delivered
  Future<void> createMessageNotification({
    required String recipientUserId,
    required String chatId,
    required String messageId,
    required String senderId,
    required String senderName,
    required String messageContent,
    String? imageUrl,
  }) async {
    try {
      await _supabase.from('ngm_notifications').insert({
        'user_id': recipientUserId,
        'chat_id': chatId,
        'message_id': messageId,
        'sender_id': senderId,
        'notification_type': 'message',
        'title': senderName,
        'body': messageContent.length > 100
            ? '${messageContent.substring(0, 100)}...'
            : messageContent,
        'image_url': imageUrl,
        'is_read': false,
        'is_delivered': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }

  // ✅ Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _supabase.from('ngm_notifications').update({
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
      }).eq('notification_id', notificationId);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  // ✅ Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('ngm_notifications').update({
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
      })
      .eq('user_id', userId)
      .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  // ✅ Load unread notifications count
  Future<int> getUnreadNotificationsCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await _supabase
          .from('ngm_notifications')
          .select('notification_id')
          .eq('user_id', userId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  // ✅ Delete inactive FCM tokens
  Future<void> deactivateFcmToken(String fcmToken) async {
    try {
      await _supabase.from('ngm_notification_tokens').update({
        'is_active': false,
      }).eq('fcm_token', fcmToken);
    } catch (e) {
      debugPrint('Error deactivating FCM token: $e');
    }
  }
}
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/chat_model.dart';
import 'local_storage_service.dart';

class ChatService {
  final _supabase = Supabase.instance.client;
  final _storage = LocalStorageService();
  Timer? _typingTimer;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  // ✅ Get user info
  Future<UserModel?> getUserInfo(String userId) async {
    try {
      final response = await _supabase
          .from('ngm_users')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();
      if (response == null) return null;
      return UserModel.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error fetching user: $e');
      return null;
    }
  }

  // ✅ Get chat info
  Future<ChatModel?> getChatInfo(String chatId) async {
    try {
      final response = await _supabase
          .from('ngm_chats')
          .select('*')
          .eq('chat_id', chatId)
          .maybeSingle();
      if (response == null) return null;
      return ChatModel.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error fetching chat info: $e');
      return null;
    }
  }

  // ✅ Fetch messages
  Future<List<Message>> fetchMessages(String chatId) async {
    try {
      final response = await _supabase
          .from('ngm_messages')
          .select('*')
          .eq('chat_id', chatId)
          .eq('is_deleted', false)
          .order('created_at', ascending: true);

      final messages = (response as List)
          .map((json) => Message.fromJson(json))
          .toList();

      for (final msg in messages) {
        _storage.saveMessage(msg);
      }
      return messages;
    } catch (e) {
      debugPrint('❌ Error fetching messages: $e');
      return [];
    }
  }

  // ✅ Subscribe to messages
  Stream<Message> subscribeToMessages(String chatId) {
    final controller = StreamController<Message>.broadcast();
    
    debugPrint('👂 Subscribing to messages: $chatId');
    
    final channelName = 'messages:$chatId:${DateTime.now().millisecondsSinceEpoch}';
    
    _supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ngm_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) {
            debugPrint('📨 New message received: ${payload.newRecord}');
            final message = Message.fromJson(payload.newRecord);
            controller.add(message);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ngm_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) {
            debugPrint('📝 Message updated: ${payload.newRecord}');
            final message = Message.fromJson(payload.newRecord);
            controller.add(message);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ Messages channel subscribed');
          } else if (error != null) {
            debugPrint('❌ Messages subscription error: $error');
          }
        });
        
    return controller.stream;
  }

  // ✅ Subscribe to user presence
  Stream<UserModel> subscribeToUserPresence(String userId) {
    final controller = StreamController<UserModel>.broadcast();
    
    debugPrint('👂 Subscribing to presence: $userId');
    
    final channelName = 'presence:$userId:${DateTime.now().millisecondsSinceEpoch}';
    
    _supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ngm_users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint('👤 User presence updated: ${payload.newRecord}');
            final user = UserModel.fromJson(payload.newRecord);
            controller.add(user);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ Presence channel subscribed');
          } else if (error != null) {
            debugPrint('❌ Presence subscription error: $error');
          }
        });
        
    return controller.stream;
  }

  // ✅ Subscribe to message status
  Stream<Map<String, String>> subscribeToMessageStatus(String chatId) {
    final controller = StreamController<Map<String, String>>.broadcast();
    
    debugPrint('👂 Subscribing to message status: $chatId');
    
    final channelName = 'status:$chatId:${DateTime.now().millisecondsSinceEpoch}';
    
    _supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ngm_message_status',
          callback: (payload) {
            debugPrint('✓ Status updated: ${payload.newRecord}');
            controller.add({
              'message_id': payload.newRecord['message_id'],
              'status': payload.newRecord['status'],
            });
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ Status channel subscribed');
          } else if (error != null) {
            debugPrint('❌ Status subscription error: $error');
          }
        });
        
    return controller.stream;
  }

  // ✅ TYPING INDICATOR - Start typing
  Future<void> startTyping(String chatId) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        debugPrint('❌ startTyping: No user ID');
        return;
      }

      debugPrint('⌨️ Starting typing: chatId=$chatId, userId=$userId');

      // Cancel previous timer
      _typingTimer?.cancel();

      // Update typing status in DB
      await _supabase.from('ngm_chat_participants').update({
        'is_typing': true,
      }).eq('chat_id', chatId).eq('user_id', userId);

      debugPrint('✅ Typing status updated to TRUE in DB');

      // ✅ Auto stop typing after 3 seconds
      _typingTimer = Timer(const Duration(seconds: 3), () {
        debugPrint('⏱️ Auto-stopping typing after 3 seconds');
        stopTyping(chatId);
      });
    } catch (e) {
      debugPrint('❌ Error starting typing: $e');
    }
  }

  // ✅ TYPING INDICATOR - Stop typing
  Future<void> stopTyping(String chatId) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        debugPrint('❌ stopTyping: No user ID');
        return;
      }

      debugPrint('⌨️ Stopping typing: chatId=$chatId, userId=$userId');

      _typingTimer?.cancel();
      _typingTimer = null;

      await _supabase.from('ngm_chat_participants').update({
        'is_typing': false,
      }).eq('chat_id', chatId).eq('user_id', userId);

      debugPrint('✅ Typing status updated to FALSE in DB');
    } catch (e) {
      debugPrint('❌ Error stopping typing: $e');
    }
  }

  // ✅ TYPING INDICATOR - Subscribe to typing
  Stream<bool> subscribeToTyping(String chatId, String otherUserId) {
    final controller = StreamController<bool>.broadcast();

    debugPrint('👂 Subscribing to typing: chatId=$chatId, otherUserId=$otherUserId');

    // ✅ Use unique channel name with timestamp
    final channelName = 'typing:$chatId:$otherUserId:${DateTime.now().millisecondsSinceEpoch}';

    _supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ngm_chat_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) {
            debugPrint('📡 Typing payload received: ${payload.newRecord}');
            
            final updatedUserId = payload.newRecord['user_id'];
            final isTyping = payload.newRecord['is_typing'] ?? false;

            debugPrint('   👤 Updated user: $updatedUserId, typing: $isTyping, expecting: $otherUserId');

            // ✅ Only show typing for other user
            if (updatedUserId == otherUserId) {
              debugPrint('   ✅ Match! Sending typing=$isTyping to stream');
              controller.add(isTyping);
            } else {
              debugPrint('   ⏭️ Skipping - not the expected user');
            }
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ Typing channel subscribed successfully');
          } else if (error != null) {
            debugPrint('❌ Typing subscription error: $error');
          }
        });

    return controller.stream;
  }

  // ✅ Send message
  Future<void> sendMessage({
    required String chatId,
    required String messageType,
    String? content,
    String? mediaUrl,
    String? replyToMessageId,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not logged in');

      debugPrint('📤 Sending message: chatId=$chatId, type=$messageType');

      // ✅ Stop typing when message sent
      await stopTyping(chatId);

      final response = await _supabase.from('ngm_messages').insert({
        'chat_id': chatId,
        'sender_id': userId,
        'message_type': messageType,
        'content': content,
        'media_url': mediaUrl,
        'reply_to_message_id': replyToMessageId,
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      debugPrint('✅ Message sent: ${response.length} rows');

      await _supabase.from('ngm_chats').update({
        'last_message_at': DateTime.now().toIso8601String(),
        'last_message_by': userId,
      }).eq('chat_id', chatId);

    } catch (e, stackTrace) {
      debugPrint('❌ Error sending message: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // ✅ Mark messages as read
  Future<void> markAsRead(String messageId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final messageData = await _supabase
          .from('ngm_messages')
          .select('chat_id, sender_id')
          .eq('message_id', messageId)
          .maybeSingle();

      if (messageData == null) return;

      final chatId = messageData['chat_id'];
      final senderId = messageData['sender_id'];

      if (senderId == userId) return;

      await _supabase.rpc('mark_messages_as_read', params: {
        'p_chat_id': chatId,
        'p_user_id': userId,
      });
      
      debugPrint('✅ Message marked as read: $messageId');
    } catch (e) {
      debugPrint('❌ Error marking as read: $e');
    }
  }

  // ✅ Mark all messages as read (when leaving chat)
  Future<void> markAllMessagesAsRead(String chatId) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      await _supabase.rpc('mark_messages_as_read', params: {
        'p_chat_id': chatId,
        'p_user_id': userId,
      });

      debugPrint('✅ All messages marked as read on exit');
    } catch (e) {
      debugPrint('❌ Error marking all as read: $e');
    }
  }

  // ✅ Update online status
  Future<void> updateOnlineStatus(bool isOnline) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      await _supabase.from('ngm_users').update({
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);
      
      debugPrint('✅ Online status updated: $isOnline');
    } catch (e) {
      debugPrint('❌ Error updating online status: $e');
    }
  }

  // ✅ Edit message
  Future<void> editMessage(String messageId, String newContent) async {
    try {
      await _supabase.from('ngm_messages').update({
        'content': newContent,
        'is_edited': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('message_id', messageId);
      
      debugPrint('✅ Message edited: $messageId');
    } catch (e) {
      debugPrint('❌ Error editing message: $e');
      rethrow;
    }
  }

  // ✅ Delete message for me (local only)
  Future<void> deleteMessageForMe(String messageId) async {
    try {
      await _storage.markMessageAsDeletedForMe(messageId);
      debugPrint('✅ Message marked as deleted for me locally: $messageId');
    } catch (e) {
      debugPrint('❌ Error deleting message locally: $e');
    }
  }

  // ✅ Delete message for everyone (Supabase + local)
  Future<void> deleteMessageForEveryone(String messageId) async {
    try {
      // Delete from Supabase
      await _supabase.from('ngm_messages').delete().eq('message_id', messageId);
      
      // Delete locally
      _storage.deleteMessage(messageId);
      
      debugPrint('✅ Message deleted for everyone: $messageId');
    } catch (e) {
      debugPrint('❌ Error deleting message for everyone: $e');
      rethrow;
    }
  }

  // ✅ Pin message
  Future<void> pinMessage(String messageId, String chatId) async {
    try {
      // Unpin all others first
      await _supabase.from('ngm_messages').update({
        'is_pinned': false,
      }).eq('chat_id', chatId);

      // Pin this message
      await _supabase.from('ngm_messages').update({
        'is_pinned': true,
      }).eq('message_id', messageId);
      
      debugPrint('✅ Message pinned: $messageId');
    } catch (e) {
      debugPrint('❌ Error pinning message: $e');
      rethrow;
    }
  }

  // ✅ Unpin message
  Future<void> unpinMessage(String messageId) async {
    try {
      await _supabase.from('ngm_messages').update({
        'is_pinned': false,
      }).eq('message_id', messageId);
      
      debugPrint('✅ Message unpinned: $messageId');
    } catch (e) {
      debugPrint('❌ Error unpinning message: $e');
      rethrow;
    }
  }
}
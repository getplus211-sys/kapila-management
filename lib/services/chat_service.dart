import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/chat_model.dart';
import 'local_storage_service.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  String? get currentUserId => _supabase.auth.currentUser?.id;

  // ✅ Send message
  Future<Message?> sendMessage({
    required String chatId,
    required String messageType,
    String? content,
    String? mediaUrl,
    String? replyToMessageId,
  }) async {
    try {
      final messageData = {
        'chat_id': chatId,
        'sender_id': currentUserId,
        'message_type': messageType,
        'content': content,
        'media_url': mediaUrl,
        'reply_to_message_id': replyToMessageId,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('ngm_messages')
          .insert(messageData)
          .select()
          .single();

      final message = Message.fromJson(response);
      await LocalStorageService().saveMessage(message);
      await _updateChatLastMessage(chatId, message.messageId);
      
      return message;
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }
  }

  // ✅ Mark as read
  Future<void> markAsRead(String messageId) async {
    try {
      await _supabase.from('ngm_message_status').upsert(
        {
          'message_id': messageId,
          'user_id': currentUserId,
          'status': 'read',
          'status_timestamp': DateTime.now().toIso8601String(),
        },
        onConflict: 'message_id,user_id',
      );
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  // ✅ Fetch messages
  Future<List<Message>> fetchMessages(String chatId, {int limit = 50}) async {
    try {
      final response = await _supabase
          .from('ngm_messages')
          .select()
          .eq('chat_id', chatId)
          .eq('is_deleted', false)
          .order('created_at', ascending: true)
          .limit(limit);

      final messages = (response as List)
          .map((json) => Message.fromJson(json))
          .toList();

      await LocalStorageService().saveMessages(messages);
      return messages;
    } catch (e) {
      print('Error fetching messages: $e');
      return [];
    }
  }

  // ✅ FIXED: Real-time message subscription
  Stream<Message> subscribeToMessages(String chatId) {
    print('🔔 Subscribing to messages for chat: $chatId');
    
    return _supabase
        .from('ngm_messages')
        .stream(primaryKey: ['message_id'])
        .eq('chat_id', chatId)
        .order('created_at')
        .map((List<Map<String, dynamic>> data) {
          if (data.isEmpty) {
            throw Exception('No data');
          }
          
          final message = Message.fromJson(data.last);
          print('🔔 New message received: ${message.messageId}');
          return message;
        })
        .handleError((error) {
          print('❌ Stream error: $error');
        });
  }

  // ✅ Update typing status
  Future<void> updateTypingStatus(String chatId, bool isTyping) async {
    try {
      await _supabase.from('ngm_typing_status').upsert(
        {
          'chat_id': chatId,
          'user_id': currentUserId,
          'is_typing': isTyping,
          'last_typing_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'chat_id,user_id',
      );
    } catch (e) {
      print('Error updating typing status: $e');
    }
  }

  // ✅ FIXED: Get user info with better error handling
  Future<UserModel?> getUserInfo(String userId) async {
    try {
      print('🔍 Fetching user: $userId');
      
      // Try ngm_users table directly
      final response = await _supabase
          .from('ngm_users')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        print('⚠️ User not found: $userId');
        return UserModel(
          userId: userId,
          fullName: 'Unknown User',
          isOnline: false,
        );
      }

      print('✅ User found: ${response['full_name']} (${response['username']})');
      print('✅ Online: ${response['is_online']}, Last seen: ${response['last_seen']}');

      final user = UserModel.fromJson(response);
      await LocalStorageService().saveUser(user);
      
      return user;
    } catch (e) {
      print('❌ Error fetching user: $e');
      
      final localUser = LocalStorageService().getUser(userId);
      if (localUser != null) {
        print('✅ Loaded from cache');
        return localUser;
      }
      
      return UserModel(
        userId: userId,
        fullName: 'Unknown User',
        isOnline: false,
      );
    }
  }

  // ✅ Update online status
  Future<void> updateOnlineStatus(bool isOnline) async {
    try {
      if (currentUserId == null) return;
      
      await _supabase.from('ngm_users').update({
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('user_id', currentUserId!);
      
      print('✅ Online status updated: $isOnline');
    } catch (e) {
      print('Error updating online status: $e');
    }
  }

  // Helper methods
  Future<void> _updateChatLastMessage(String chatId, String messageId) async {
    try {
      await _supabase.from('ngm_chats').update({
        'last_message_at': DateTime.now().toIso8601String(),
        'last_message_by': currentUserId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('chat_id', chatId);
    } catch (e) {
      print('Error updating chat: $e');
    }
  }

  Future<ChatModel?> getChatInfo(String chatId) async {
    try {
      final response = await _supabase
          .from('ngm_chats')
          .select()
          .eq('chat_id', chatId)
          .single();

      final chat = ChatModel.fromJson(response);
      await LocalStorageService().saveChat(chat);
      return chat;
    } catch (e) {
      print('Error fetching chat: $e');
      return LocalStorageService().getChat(chatId);
    }
  }

  // Edit, Delete, Pin, Schedule methods
  Future<bool> editMessage(String messageId, String newContent) async {
    try {
      await _supabase.from('ngm_messages').update({
        'content': newContent,
        'is_edited': true,
        'edited_at': DateTime.now().toIso8601String(),
      }).eq('message_id', messageId);

      final localMessage = LocalStorageService().getMessage(messageId);
      if (localMessage != null) {
        await LocalStorageService().updateMessage(
          localMessage.copyWith(
            content: newContent,
            isEdited: true,
            editedAt: DateTime.now(),
          ),
        );
      }
      
      return true;
    } catch (e) {
      print('Error editing message: $e');
      return false;
    }
  }

  Future<bool> deleteMessageForEveryone(String messageId) async {
    try {
      await _supabase.from('ngm_messages').update({
        'is_deleted': true,
        'deleted_at': DateTime.now().toIso8601String(),
        'content': null,
        'media_url': null,
      }).eq('message_id', messageId);

      await LocalStorageService().deleteMessage(messageId);
      return true;
    } catch (e) {
      print('Error deleting message: $e');
      return false;
    }
  }

  Future<bool> deleteMessageForMe(String messageId) async {
    try {
      await _supabase.from('ngm_deleted_messages').insert({
        'message_id': messageId,
        'user_id': currentUserId,
      });

      await LocalStorageService().markMessageAsDeletedForMe(messageId);
      return true;
    } catch (e) {
      print('Error deleting message for me: $e');
      return false;
    }
  }

  Future<bool> pinMessage(String messageId, String chatId) async {
    try {
      final message = LocalStorageService().getMessage(messageId);
      if (message != null) {
        await LocalStorageService().updateMessage(
          message.copyWith(isPinned: true),
        );
      }
      return true;
    } catch (e) {
      print('Error pinning message: $e');
      return false;
    }
  }

  Future<bool> unpinMessage(String messageId) async {
    try {
      final message = LocalStorageService().getMessage(messageId);
      if (message != null) {
        await LocalStorageService().updateMessage(
          message.copyWith(isPinned: false),
        );
      }
      return true;
    } catch (e) {
      print('Error unpinning message: $e');
      return false;
    }
  }

  Future<bool> scheduleMessage({
    required String chatId,
    required String content,
    required DateTime scheduledFor,
    String messageType = 'text',
    String? mediaUrl,
  }) async {
    try {
      await _supabase.from('ngm_scheduled_messages').insert({
        'user_id': currentUserId,
        'chat_id': chatId,
        'message_content': content,
        'message_type': messageType,
        'media_url': mediaUrl,
        'scheduled_for': scheduledFor.toIso8601String(),
        'is_sent': false,
      });
      return true;
    } catch (e) {
      print('Error scheduling message: $e');
      return false;
    }
  }

  Future<bool> forwardMessage({
    required String messageId,
    required List<String> chatIds,
  }) async {
    try {
      final message = LocalStorageService().getMessage(messageId);
      if (message == null) return false;

      for (final chatId in chatIds) {
        await sendMessage(
          chatId: chatId,
          messageType: message.messageType,
          content: message.content,
          mediaUrl: message.mediaUrl,
        );
      }
      
      return true;
    } catch (e) {
      print('Error forwarding message: $e');
      return false;
    }
  }
}
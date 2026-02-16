import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_model.dart';

class DatabaseService {
  final _supabase = Supabase.instance.client;

  // ✅ OPTIMIZED: Single query with join to get messages with sender info
  Future<List<Message>> loadMessagesOptimized({
    required String chatId,
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Load deleted message IDs
      final deletedResponse = await _supabase
          .from('ngm_deleted_messages')
          .select('message_id')
          .eq('user_id', userId);
      
      final deletedIds = deletedResponse
          .map((d) => d['message_id'] as String)
          .toList();

      // Single optimized query with user info
      final response = await _supabase
          .rpc('get_chat_messages', params: {
            'p_chat_id': chatId,
            'p_limit': limit,
            'p_offset': offset,
            'p_deleted_ids': deletedIds,
          });

      return (response as List)
          .map((item) => Message.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppError('Failed to load messages', originalError: e);
    }
  }

  // ✅ Batch update read status
  Future<void> markMessagesAsReadBatch({
    required String chatId,
    required String userId,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty) return;

    try {
      await _supabase.rpc('mark_messages_read', params: {
        'p_chat_id': chatId,
        'p_user_id': userId,
        'p_message_ids': messageIds,
      });
    } catch (e) {
      throw AppError('Failed to update read status', originalError: e);
    }
  }

  // ✅ Optimized user info fetch with caching
  final Map<String, Map<String, dynamic>> _userCache = {};
  
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    // Check cache first
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      final response = await _supabase
          .from('ngm_users')
          .select('full_name, username, profile_picture_url')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        _userCache[userId] = response;
      }
      
      return response;
    } catch (e) {
      return null;
    }
  }

  void clearCache() {
    _userCache.clear();
  }
}
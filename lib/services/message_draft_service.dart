import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class MessageDraftService {
  final _supabase = Supabase.instance.client;

  // ✅ Save draft - schema: user_id, chat_id, draft_content
  Future<void> saveDraft({
    required String chatId,
    required String content,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      if (content.trim().isEmpty) {
        await deleteDraft(chatId: chatId);
        return;
      }

      await _supabase.from('ngm_message_drafts').upsert({
        'user_id': userId,
        'chat_id': chatId,
        'draft_content': content,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving draft: $e');
    }
  }

  // ✅ Load draft
  Future<String?> loadDraft({required String chatId}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('ngm_message_drafts')
          .select('draft_content')
          .eq('user_id', userId)
          .eq('chat_id', chatId)
          .maybeSingle();

      return response?['draft_content'] as String?;
    } catch (e) {
      debugPrint('Error loading draft: $e');
      return null;
    }
  }

  // ✅ Delete draft after sending
  Future<void> deleteDraft({required String chatId}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('ngm_message_drafts')
          .delete()
          .eq('user_id', userId)
          .eq('chat_id', chatId);
    } catch (e) {
      debugPrint('Error deleting draft: $e');
    }
  }
}
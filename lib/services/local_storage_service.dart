import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/chat_model.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  SharedPreferences? _prefs;
  
  // Hive box names
  static const String messagesBox = 'messages';
  static const String usersBox = 'users';
  static const String chatsBox = 'chats';
  
  Future<void> init() async {
    // Initialize SharedPreferences
    _prefs = await SharedPreferences.getInstance();
    
    // Initialize Hive
    await Hive.initFlutter();
    
    // ✅ Register adapters (Uncomment આ પછી build_runner run કરો!)
    Hive.registerAdapter(MessageAdapter());
    Hive.registerAdapter(UserModelAdapter());
    Hive.registerAdapter(ChatModelAdapter());
    
    // Open boxes
    await Hive.openBox<Message>(messagesBox);
    await Hive.openBox<UserModel>(usersBox);
    await Hive.openBox<ChatModel>(chatsBox);
  }

  // ==================== HIVE OPERATIONS (For Messages) ====================
  
  // Message operations
  Future<void> saveMessage(Message message) async {
    try {
      final box = Hive.box<Message>(messagesBox);
      await box.put(message.messageId, message);
    } catch (e) {
      print('Error saving message to Hive: $e');
    }
  }

  Future<void> saveMessages(List<Message> messages) async {
    try {
      final box = Hive.box<Message>(messagesBox);
      for (var message in messages) {
        await box.put(message.messageId, message);
      }
    } catch (e) {
      print('Error saving messages to Hive: $e');
    }
  }

  List<Message> getMessagesByChat(String chatId) {
    try {
      final box = Hive.box<Message>(messagesBox);
      return box.values
          .where((msg) => msg.chatId == chatId && !msg.isDeletedForMe)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (e) {
      print('Error getting messages from Hive: $e');
      return [];
    }
  }

  Message? getMessage(String messageId) {
    try {
      final box = Hive.box<Message>(messagesBox);
      return box.get(messageId);
    } catch (e) {
      print('Error getting message from Hive: $e');
      return null;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      final box = Hive.box<Message>(messagesBox);
      await box.delete(messageId);
    } catch (e) {
      print('Error deleting message from Hive: $e');
    }
  }

  Future<void> updateMessage(Message message) async {
    try {
      final box = Hive.box<Message>(messagesBox);
      await box.put(message.messageId, message);
    } catch (e) {
      print('Error updating message in Hive: $e');
    }
  }

  Future<void> markMessageAsDeletedForMe(String messageId) async {
    try {
      final box = Hive.box<Message>(messagesBox);
      final message = box.get(messageId);
      if (message != null) {
        await box.put(
          messageId,
          message.copyWith(isDeletedForMe: true),
        );
      }
    } catch (e) {
      print('Error marking message as deleted: $e');
    }
  }

  // User operations
  Future<void> saveUser(UserModel user) async {
    try {
      final box = Hive.box<UserModel>(usersBox);
      await box.put(user.userId, user);
    } catch (e) {
      print('Error saving user to Hive: $e');
    }
  }

  UserModel? getUser(String userId) {
    try {
      final box = Hive.box<UserModel>(usersBox);
      return box.get(userId);
    } catch (e) {
      print('Error getting user from Hive: $e');
      return null;
    }
  }

  // Chat operations
  Future<void> saveChat(ChatModel chat) async {
    try {
      final box = Hive.box<ChatModel>(chatsBox);
      await box.put(chat.chatId, chat);
    } catch (e) {
      print('Error saving chat to Hive: $e');
    }
  }

  ChatModel? getChat(String chatId) {
    try {
      final box = Hive.box<ChatModel>(chatsBox);
      return box.get(chatId);
    } catch (e) {
      print('Error getting chat from Hive: $e');
      return null;
    }
  }

  Future<void> updateChat(ChatModel chat) async {
    try {
      final box = Hive.box<ChatModel>(chatsBox);
      await box.put(chat.chatId, chat);
    } catch (e) {
      print('Error updating chat in Hive: $e');
    }
  }

  List<ChatModel> getAllChats() {
    try {
      final box = Hive.box<ChatModel>(chatsBox);
      return box.values.toList()
        ..sort((a, b) => (b.lastMessageAt ?? b.updatedAt)
            .compareTo(a.lastMessageAt ?? a.updatedAt));
    } catch (e) {
      print('Error getting all chats from Hive: $e');
      return [];
    }
  }

  // ==================== SHARED PREFERENCES OPERATIONS ====================

  // Chat List Cache
  Future<void> saveChatList(List<Map<String, dynamic>> chats) async {
    try {
      await _prefs?.setString('cached_chats', jsonEncode(chats));
    } catch (e) {
      print('Error saving chat list: $e');
    }
  }

  List<Map<String, dynamic>>? getCachedChatList() {
    try {
      final data = _prefs?.getString('cached_chats');
      if (data == null) return null;
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    } catch (e) {
      print('Error getting cached chat list: $e');
      return null;
    }
  }

  // Contacts Cache
  Future<void> saveContacts(List<Map<String, dynamic>> contacts) async {
    try {
      await _prefs?.setString('cached_contacts', jsonEncode(contacts));
    } catch (e) {
      print('Error saving contacts: $e');
    }
  }

  List<Map<String, dynamic>>? getCachedContacts() {
    try {
      final data = _prefs?.getString('cached_contacts');
      if (data == null) return null;
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    } catch (e) {
      print('Error getting cached contacts: $e');
      return null;
    }
  }

  // Messages Cache (JSON format for compatibility)
  Future<void> saveChatMessages(String chatId, List<Map<String, dynamic>> messages) async {
    try {
      await _prefs?.setString('messages_$chatId', jsonEncode(messages));
    } catch (e) {
      print('Error saving chat messages: $e');
    }
  }

  List<Map<String, dynamic>>? getCachedMessages(String chatId) {
    try {
      final data = _prefs?.getString('messages_$chatId');
      if (data == null) return null;
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    } catch (e) {
      print('Error getting cached messages: $e');
      return null;
    }
  }

  Future<void> clearChatMessages(String chatId) async {
    try {
      await _prefs?.remove('messages_$chatId');
    } catch (e) {
      print('Error clearing chat messages: $e');
    }
  }

  // Typing Draft
  Future<void> saveDraft(String chatId, String text) async {
    try {
      if (text.isEmpty) {
        await _prefs?.remove('draft_$chatId');
      } else {
        await _prefs?.setString('draft_$chatId', text);
      }
    } catch (e) {
      print('Error saving draft: $e');
    }
  }

  String? getDraft(String chatId) {
    try {
      return _prefs?.getString('draft_$chatId');
    } catch (e) {
      print('Error getting draft: $e');
      return null;
    }
  }

  // Auto-download Settings
  Future<void> saveAutoDownloadSettings({
    required bool wifi,
    required bool mobile,
    required bool roaming,
  }) async {
    try {
      await _prefs?.setBool('auto_download_wifi', wifi);
      await _prefs?.setBool('auto_download_mobile', mobile);
      await _prefs?.setBool('auto_download_roaming', roaming);
    } catch (e) {
      print('Error saving auto download settings: $e');
    }
  }

  Map<String, bool> getAutoDownloadSettings() {
    try {
      return {
        'wifi': _prefs?.getBool('auto_download_wifi') ?? true,
        'mobile': _prefs?.getBool('auto_download_mobile') ?? false,
        'roaming': _prefs?.getBool('auto_download_roaming') ?? false,
      };
    } catch (e) {
      print('Error getting auto download settings: $e');
      return {'wifi': true, 'mobile': false, 'roaming': false};
    }
  }

  // Pinned Chats
  Future<void> savePinnedChats(List<String> chatIds) async {
    try {
      await _prefs?.setStringList('pinned_chats', chatIds);
    } catch (e) {
      print('Error saving pinned chats: $e');
    }
  }

  List<String> getPinnedChats() {
    try {
      return _prefs?.getStringList('pinned_chats') ?? [];
    } catch (e) {
      print('Error getting pinned chats: $e');
      return [];
    }
  }

  Future<void> pinChat(String chatId) async {
    try {
      final pinned = getPinnedChats();
      if (!pinned.contains(chatId)) {
        pinned.insert(0, chatId);
        await savePinnedChats(pinned);
      }
    } catch (e) {
      print('Error pinning chat: $e');
    }
  }

  Future<void> unpinChat(String chatId) async {
    try {
      final pinned = getPinnedChats();
      pinned.remove(chatId);
      await savePinnedChats(pinned);
    } catch (e) {
      print('Error unpinning chat: $e');
    }
  }

  bool isChatPinned(String chatId) {
    return getPinnedChats().contains(chatId);
  }

  // Archived Chats
  Future<void> saveArchivedChats(List<String> chatIds) async {
    try {
      await _prefs?.setStringList('archived_chats', chatIds);
    } catch (e) {
      print('Error saving archived chats: $e');
    }
  }

  List<String> getArchivedChats() {
    try {
      return _prefs?.getStringList('archived_chats') ?? [];
    } catch (e) {
      print('Error getting archived chats: $e');
      return [];
    }
  }

  Future<void> archiveChat(String chatId) async {
    try {
      final archived = getArchivedChats();
      if (!archived.contains(chatId)) {
        archived.add(chatId);
        await saveArchivedChats(archived);
      }
    } catch (e) {
      print('Error archiving chat: $e');
    }
  }

  Future<void> unarchiveChat(String chatId) async {
    try {
      final archived = getArchivedChats();
      archived.remove(chatId);
      await saveArchivedChats(archived);
    } catch (e) {
      print('Error unarchiving chat: $e');
    }
  }

  bool isChatArchived(String chatId) {
    return getArchivedChats().contains(chatId);
  }

  // Last Refresh
  Future<void> saveLastRefreshTime() async {
    try {
      await _prefs?.setInt('last_refresh', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error saving last refresh time: $e');
    }
  }

  DateTime? getLastRefreshTime() {
    try {
      final timestamp = _prefs?.getInt('last_refresh');
      if (timestamp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      print('Error getting last refresh time: $e');
      return null;
    }
  }

  // ==================== CLEAR OPERATIONS ====================

  // Clear SharedPreferences cache
  Future<void> clearCache() async {
    try {
      await _prefs?.remove('cached_chats');
      await _prefs?.remove('cached_contacts');
      await saveLastRefreshTime();
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  // Clear all SharedPreferences
  Future<void> clearAllPreferences() async {
    try {
      await _prefs?.clear();
    } catch (e) {
      print('Error clearing all preferences: $e');
    }
  }

  // Clear all Hive data
  Future<void> clearAllHive() async {
    try {
      await Hive.box<Message>(messagesBox).clear();
      await Hive.box<UserModel>(usersBox).clear();
      await Hive.box<ChatModel>(chatsBox).clear();
    } catch (e) {
      print('Error clearing Hive data: $e');
    }
  }

  // Clear everything
  Future<void> clearAll() async {
    try {
      await clearAllPreferences();
      await clearAllHive();
    } catch (e) {
      print('Error clearing all data: $e');
    }
  }
}